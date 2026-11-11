-- Unidad 4, Parte 1: descomposición FNBC de control_lote_almacen.
-- Todo queda aislado en mayorista_u4; no crea ni modifica objetos de public.
-- Ejecutar una sola vez en una base de pruebas. Los IDs maestros coinciden
-- con los registros de ejemplo exigidos por la guía.

DO $$
BEGIN
    IF current_database() = 'foodstore_tp' THEN
        RAISE EXCEPTION 'No se permite instalar la Unidad 4 en foodstore_tp';
    END IF;
END;
$$;

CREATE SCHEMA mayorista_u4;

-- Tablas maestras mínimas de la extensión mayorista.
CREATE TABLE mayorista_u4.lote (
    id BIGINT PRIMARY KEY
);

CREATE TABLE mayorista_u4.deposito (
    id BIGINT PRIMARY KEY
);

CREATE TABLE mayorista_u4.usuario (
    id BIGINT PRIMARY KEY
);

-- Instancias maestras necesarias para validar las referencias de ejemplo.
INSERT INTO mayorista_u4.lote (id) VALUES
    (501),
    (502),
    (503);

INSERT INTO mayorista_u4.deposito (id) VALUES
    (30),
    (31);

INSERT INTO mayorista_u4.usuario (id) VALUES
    (801),
    (802);

-- Relación original, con nombres, tipos, PK y FK de la consigna.
CREATE TABLE mayorista_u4.control_lote_almacen (
    lote_id                 BIGINT NOT NULL REFERENCES mayorista_u4.lote(id),
    deposito_id             BIGINT NOT NULL REFERENCES mayorista_u4.deposito(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES mayorista_u4.usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

-- Instancia de ejemplo fijada por la guía.
INSERT INTO mayorista_u4.control_lote_almacen
    (lote_id, deposito_id, responsable_control_id)
VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

-- Descomposición según las dependencias funcionales:
-- responsable_control_id -> deposito_id
-- lote_id, responsable_control_id -> deposito_id, responsable_control_id, lote_id
CREATE TABLE mayorista_u4.responsable_control_deposito (
    responsable_control_id BIGINT PRIMARY KEY
        REFERENCES mayorista_u4.usuario(id),
    deposito_id BIGINT NOT NULL
        REFERENCES mayorista_u4.deposito(id)
);

CREATE TABLE mayorista_u4.lote_responsable (
    lote_id BIGINT NOT NULL
        REFERENCES mayorista_u4.lote(id),
    responsable_control_id BIGINT NOT NULL
        REFERENCES mayorista_u4.responsable_control_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- La FK anterior garantiza que cada asignación lote-responsable tiene un
-- depósito asociado y, transitivamente, un usuario y depósito maestros válidos.

-- Migración desde la relación original. La PK de responsable_control_deposito
-- hace fallar la migración si un responsable aparece asignado a depósitos distintos.
INSERT INTO mayorista_u4.responsable_control_deposito
    (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM mayorista_u4.control_lote_almacen;

INSERT INTO mayorista_u4.lote_responsable
    (lote_id, responsable_control_id)
SELECT lote_id, responsable_control_id
FROM mayorista_u4.control_lote_almacen;

-- La FD LoteID, DepositoID -> ResponsableControlID no queda preservada por
-- separado en las dos relaciones. Se valida sobre la unión reconstruida.
CREATE FUNCTION mayorista_u4.fn_validar_fd_lote_deposito_responsable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(740401, 2);

    IF current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION
            'La validación de la dependencia funcional requiere READ COMMITTED';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM mayorista_u4.lote_responsable AS lr
        JOIN mayorista_u4.responsable_control_deposito AS rd
          USING (responsable_control_id)
        GROUP BY lr.lote_id, rd.deposito_id
        HAVING count(DISTINCT lr.responsable_control_id) > 1
    ) THEN
        RAISE EXCEPTION
            'Se viola LoteID, DepositoID -> ResponsableControlID en mayorista_u4'
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NULL;
END;
$$;

-- Se difiere hasta el fin de la transacción para permitir migraciones o
-- reasignaciones que actualicen ambas relaciones dentro de la misma transacción.
CREATE CONSTRAINT TRIGGER ctrg_lote_responsable_fd
AFTER INSERT OR UPDATE OR DELETE ON mayorista_u4.lote_responsable
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION mayorista_u4.fn_validar_fd_lote_deposito_responsable();

CREATE CONSTRAINT TRIGGER ctrg_responsable_control_deposito_fd
AFTER INSERT OR UPDATE OR DELETE ON mayorista_u4.responsable_control_deposito
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION mayorista_u4.fn_validar_fd_lote_deposito_responsable();

-- NATURAL JOIN reconstruye las tres columnas porque responsable_control_id
-- es el único atributo compartido por ambas relaciones descompuestas.
CREATE VIEW mayorista_u4.v_control_lote_almacen_compat AS
SELECT lote_id, deposito_id, responsable_control_id
FROM mayorista_u4.lote_responsable
NATURAL JOIN mayorista_u4.responsable_control_deposito;

-- Verificación de equivalencia en ambos sentidos: debe devolver cero filas.
(SELECT lote_id, deposito_id, responsable_control_id
 FROM mayorista_u4.control_lote_almacen
 EXCEPT
 SELECT lote_id, deposito_id, responsable_control_id
 FROM mayorista_u4.v_control_lote_almacen_compat)
UNION ALL
(SELECT lote_id, deposito_id, responsable_control_id
 FROM mayorista_u4.v_control_lote_almacen_compat
 EXCEPT
 SELECT lote_id, deposito_id, responsable_control_id
 FROM mayorista_u4.control_lote_almacen);

-- Conteos de apoyo: original y reconstrucción deben contener 3 filas.
SELECT
    (SELECT count(*) FROM mayorista_u4.control_lote_almacen) AS filas_originales,
    (SELECT count(*) FROM mayorista_u4.v_control_lote_almacen_compat) AS filas_reconstruidas;

-- Resultado esperado del conteo: filas_originales = 3, filas_reconstruidas = 3.

-- Prueba negativa de la FK desde lote_responsable al maestro responsable-depósito.
DO $$
DECLARE
    fk_rechazada BOOLEAN := FALSE;
BEGIN
    BEGIN
        INSERT INTO mayorista_u4.lote_responsable
            (lote_id, responsable_control_id)
        VALUES (501, 999999);
    EXCEPTION
        WHEN foreign_key_violation THEN
            fk_rechazada := TRUE;
    END;

    IF NOT fk_rechazada THEN
        RAISE EXCEPTION
            'La prueba esperaba que la FK rechazara un responsable inexistente';
    END IF;

    RAISE NOTICE 'Prueba negativa: la FK rechazó el responsable inexistente.';
END;
$$;

-- Prueba negativa de la FD no preservada:
-- modifica temporalmente el depósito de 802 y lo asigna al lote 501, que ya
-- tiene un responsable distinto en el depósito 30. La subtransacción revierte
-- ambos cambios cuando el trigger rechaza la violación.
DO $$
DECLARE
    violacion_rechazada BOOLEAN := FALSE;
BEGIN
    BEGIN
        UPDATE mayorista_u4.responsable_control_deposito
        SET deposito_id = 30
        WHERE responsable_control_id = 802;

        INSERT INTO mayorista_u4.lote_responsable
            (lote_id, responsable_control_id)
        VALUES (501, 802);

        SET CONSTRAINTS ALL IMMEDIATE;
    EXCEPTION
        WHEN check_violation THEN
            violacion_rechazada := TRUE;
    END;

    IF NOT violacion_rechazada THEN
        RAISE EXCEPTION
            'La prueba esperaba que la FD LoteID, DepositoID -> ResponsableControlID fuera rechazada';
    END IF;

    RAISE NOTICE 'Prueba negativa: la asignación contradictoria fue rechazada.';
END;
$$;
