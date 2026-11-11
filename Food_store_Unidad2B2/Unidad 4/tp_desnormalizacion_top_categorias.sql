-- Unidad 4, Parte 2: top 5 diario de categorías por importe vendido.
-- El resumen se mantiene en mayorista_u4 y los triggers se ejecutan en la
-- misma transacción que cada cambio de las tablas fuente.
-- Ejecutar solo en una base aislada de pruebas; nunca en foodstore_tp.
--
-- Diferencias con la consulta de la consigna:
--   pedido.fecha             -> pedidos.fecha_pedido
--   pedido.id                -> pedidos.id_pedido
--   detalle_pedido.pedido_id -> detalle_pedido.id_pedido
--   producto                 -> productos
--   detalle_pedido.producto_id -> detalle_pedido.id_producto
--   producto.categoria_id    -> productos.id_categoria
--   categoria                -> categorias
--   categoria.id             -> categorias.id_categoria
--   subtotal                 -> detalle_pedido.subtotal
--   eliminado                -> no existe en las tablas inspeccionadas
--
-- No se filtra pedidos.activo: no se confirmó que activo = TRUE equivalga a
-- eliminado = FALSE. Tampoco existe una marca de eliminación en detalle_pedido.
-- Hasta que se valide esa semántica con el responsable del esquema, el reporte
-- considera todas las filas presentes que unen con las cuatro tablas.
--
-- Salvaguarda: no ejecutar contra la base real foodstore_tp. Usar una copia
-- aislada con permisos para instalar los triggers en public.
DO $$
BEGIN
    IF current_database() = 'foodstore_tp' THEN
        RAISE EXCEPTION 'No se permite instalar la Unidad 4 en foodstore_tp';
    END IF;
END;
$$;

-- 1) Línea base normalizada. Guardar la captura completa del plan y su tiempo.
-- La agrupación por nombre replica la semántica exacta de la consulta guía:
-- categorías distintas con el mismo nombre se combinan.
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre AS categoria,
    SUM(dp.subtotal) AS total_vendido
FROM public.detalle_pedido AS dp
JOIN public.productos AS pr
    ON pr.id_producto = dp.id_producto
JOIN public.categorias AS c
    ON c.id_categoria = pr.id_categoria
JOIN public.pedidos AS ped
    ON ped.id_pedido = dp.id_pedido
WHERE ped.fecha_pedido >= CURRENT_DATE
  AND ped.fecha_pedido < CURRENT_DATE + INTERVAL '1 day'
GROUP BY c.nombre
ORDER BY total_vendido DESC, categoria ASC
LIMIT 5;

-- 2) Estructura desnormalizada: agregado diario por categoría ID.
-- El ID evita mezclar categorías al mantener el resumen; la consulta del
-- reporte vuelve a agrupar por nombre, como pide la consigna.
CREATE SCHEMA IF NOT EXISTS mayorista_u4;

CREATE TABLE IF NOT EXISTS mayorista_u4.ventas_categoria_dia AS
SELECT
    ped.fecha_pedido::date AS fecha_venta,
    c.id_categoria,
    SUM(dp.subtotal) AS total_vendido
FROM public.detalle_pedido AS dp
JOIN public.productos AS pr
    ON pr.id_producto = dp.id_producto
JOIN public.categorias AS c
    ON c.id_categoria = pr.id_categoria
JOIN public.pedidos AS ped
    ON ped.id_pedido = dp.id_pedido
WHERE FALSE
GROUP BY ped.fecha_pedido::date, c.id_categoria
WITH NO DATA;

-- CTAS hereda los tipos reales de la instancia; se agregan las restricciones
-- requeridas por el agregado después de inferirlos.
ALTER TABLE mayorista_u4.ventas_categoria_dia
    ALTER COLUMN fecha_venta SET NOT NULL,
    ALTER COLUMN id_categoria SET NOT NULL,
    ALTER COLUMN total_vendido SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'mayorista_u4.ventas_categoria_dia'::regclass
          AND contype = 'p'
    ) THEN
        ALTER TABLE mayorista_u4.ventas_categoria_dia
            ADD PRIMARY KEY (fecha_venta, id_categoria);
    END IF;
END;
$$;

-- Reconstrucción completa, protegida por un advisory lock transaccional para
-- serializar refrescos concurrentes disparados por escrituras distintas.
CREATE OR REPLACE FUNCTION mayorista_u4.refrescar_ventas_categoria_dia()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(740401, 1);

    IF current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION
            'El mantenimiento del resumen requiere READ COMMITTED';
    END IF;

    DELETE FROM mayorista_u4.ventas_categoria_dia;

    INSERT INTO mayorista_u4.ventas_categoria_dia
        (fecha_venta, id_categoria, total_vendido)
    SELECT
        ped.fecha_pedido::date,
        c.id_categoria,
        SUM(dp.subtotal)
    FROM public.detalle_pedido AS dp
    JOIN public.productos AS pr
        ON pr.id_producto = dp.id_producto
    JOIN public.categorias AS c
        ON c.id_categoria = pr.id_categoria
    JOIN public.pedidos AS ped
        ON ped.id_pedido = dp.id_pedido
    GROUP BY ped.fecha_pedido::date, c.id_categoria;
END;
$$;

CREATE OR REPLACE FUNCTION mayorista_u4.trg_refrescar_ventas_categoria_dia()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM mayorista_u4.refrescar_ventas_categoria_dia();
    RETURN NULL;
END;
$$;

-- Todo cambio en detalle, fecha del pedido o categoría del producto puede
-- cambiar el agregado. El trigger por sentencia cubre INSERT/UPDATE/DELETE.
-- Los nombres son propios de la Unidad 4; solo se reemplazan estos triggers.
DROP TRIGGER IF EXISTS trg_ventas_categoria_dia_detalle
    ON public.detalle_pedido;
DROP TRIGGER IF EXISTS trg_ventas_categoria_dia_pedido
    ON public.pedidos;
DROP TRIGGER IF EXISTS trg_ventas_categoria_dia_producto
    ON public.productos;
DROP TRIGGER IF EXISTS trg_ventas_categoria_dia_detalle_truncate
    ON public.detalle_pedido;
DROP TRIGGER IF EXISTS trg_ventas_categoria_dia_pedido_truncate
    ON public.pedidos;
DROP TRIGGER IF EXISTS trg_ventas_categoria_dia_producto_truncate
    ON public.productos;

CREATE TRIGGER trg_ventas_categoria_dia_detalle
AFTER INSERT OR UPDATE OR DELETE ON public.detalle_pedido
FOR EACH STATEMENT
EXECUTE FUNCTION mayorista_u4.trg_refrescar_ventas_categoria_dia();

CREATE TRIGGER trg_ventas_categoria_dia_pedido
AFTER INSERT OR UPDATE OR DELETE ON public.pedidos
FOR EACH STATEMENT
EXECUTE FUNCTION mayorista_u4.trg_refrescar_ventas_categoria_dia();

CREATE TRIGGER trg_ventas_categoria_dia_producto
AFTER INSERT OR UPDATE OR DELETE ON public.productos
FOR EACH STATEMENT
EXECUTE FUNCTION mayorista_u4.trg_refrescar_ventas_categoria_dia();

-- TRUNCATE no dispara triggers INSERT/UPDATE/DELETE; se cubre por separado.
CREATE TRIGGER trg_ventas_categoria_dia_detalle_truncate
AFTER TRUNCATE ON public.detalle_pedido
FOR EACH STATEMENT
EXECUTE FUNCTION mayorista_u4.trg_refrescar_ventas_categoria_dia();

CREATE TRIGGER trg_ventas_categoria_dia_pedido_truncate
AFTER TRUNCATE ON public.pedidos
FOR EACH STATEMENT
EXECUTE FUNCTION mayorista_u4.trg_refrescar_ventas_categoria_dia();

CREATE TRIGGER trg_ventas_categoria_dia_producto_truncate
AFTER TRUNCATE ON public.productos
FOR EACH STATEMENT
EXECUTE FUNCTION mayorista_u4.trg_refrescar_ventas_categoria_dia();

-- Carga inicial. Ejecuta el mismo cálculo que usan los triggers.
SELECT mayorista_u4.refrescar_ventas_categoria_dia();

-- 3) Mismo reporte leyendo el resumen y la dimensión de categorías, no las
-- cuatro tablas operativas. La agrupación final continúa siendo por nombre.
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre AS categoria,
    SUM(v.total_vendido) AS total_vendido
FROM mayorista_u4.ventas_categoria_dia AS v
JOIN public.categorias AS c
    ON c.id_categoria = v.id_categoria
WHERE v.fecha_venta = CURRENT_DATE
GROUP BY c.nombre
ORDER BY total_vendido DESC, categoria ASC
LIMIT 5;

-- 4) Auditoría bidireccional del resumen completo; cero filas indica igualdad
-- con la agregación de las fuentes para el criterio de inclusión documentado.
WITH ventas_fuente AS (
    SELECT
        ped.fecha_pedido::date AS fecha_venta,
        c.id_categoria,
        SUM(dp.subtotal) AS total_vendido
    FROM public.detalle_pedido AS dp
    JOIN public.productos AS pr
        ON pr.id_producto = dp.id_producto
    JOIN public.categorias AS c
        ON c.id_categoria = pr.id_categoria
    JOIN public.pedidos AS ped
        ON ped.id_pedido = dp.id_pedido
    GROUP BY ped.fecha_pedido::date, c.id_categoria
),
ventas_resumen AS (
    SELECT fecha_venta, id_categoria, total_vendido
    FROM mayorista_u4.ventas_categoria_dia
)
(SELECT fecha_venta, id_categoria, total_vendido
 FROM ventas_fuente
 EXCEPT
 SELECT fecha_venta, id_categoria, total_vendido
 FROM ventas_resumen)
UNION ALL
(SELECT fecha_venta, id_categoria, total_vendido
 FROM ventas_resumen
 EXCEPT
 SELECT fecha_venta, id_categoria, total_vendido
 FROM ventas_fuente);

-- Comparación directa del top 5 solicitado: cero filas en ambas direcciones.
WITH resultado_fuente AS (
    SELECT c.nombre AS categoria, SUM(dp.subtotal) AS total_vendido
    FROM public.detalle_pedido AS dp
    JOIN public.productos AS pr ON pr.id_producto = dp.id_producto
    JOIN public.categorias AS c ON c.id_categoria = pr.id_categoria
    JOIN public.pedidos AS ped ON ped.id_pedido = dp.id_pedido
    WHERE ped.fecha_pedido >= CURRENT_DATE
      AND ped.fecha_pedido < CURRENT_DATE + INTERVAL '1 day'
    GROUP BY c.nombre
    ORDER BY total_vendido DESC, categoria ASC
    LIMIT 5
),
resultado_resumen AS (
    SELECT c.nombre AS categoria, SUM(v.total_vendido) AS total_vendido
    FROM mayorista_u4.ventas_categoria_dia AS v
    JOIN public.categorias AS c ON c.id_categoria = v.id_categoria
    WHERE v.fecha_venta = CURRENT_DATE
    GROUP BY c.nombre
    ORDER BY total_vendido DESC, categoria ASC
    LIMIT 5
)
(SELECT categoria, total_vendido FROM resultado_fuente
 EXCEPT SELECT categoria, total_vendido FROM resultado_resumen)
UNION ALL
(SELECT categoria, total_vendido FROM resultado_resumen
 EXCEPT SELECT categoria, total_vendido FROM resultado_fuente);

-- 5) Pruebas transaccionales de INSERT/UPDATE/DELETE en las tres tablas
-- fuente. Cada paso compara simétricamente la fuente y el resumen; ROLLBACK
-- garantiza que los datos sintéticos de prueba no persistan.
DO $$
BEGIN
    IF current_database() = 'foodstore_tp' THEN
        RAISE EXCEPTION 'No se permite ejecutar pruebas en foodstore_tp';
    END IF;
END;
$$;

BEGIN;

CREATE TEMP TABLE u4_test_keys ON COMMIT DROP AS
SELECT (SELECT coalesce(max(id_pedido), 0) + 1 FROM public.pedidos) AS id_pedido,
       (SELECT coalesce(max(id_producto), 0) + 1 FROM public.productos) AS id_producto,
       (SELECT coalesce(max(id_detalle), 0) + 1 FROM public.detalle_pedido) AS id_detalle,
       (SELECT min(id_categoria) FROM public.categorias) AS categoria_a,
       (SELECT max(id_categoria) FROM public.categorias) AS categoria_b;

CREATE TEMP TABLE u4_test_results (
    step text NOT NULL,
    differences bigint NOT NULL
) ON COMMIT DROP;

CREATE TEMP VIEW u4_summary_diff AS
WITH fuente AS (
    SELECT ped.fecha_pedido::date AS fecha_venta, c.id_categoria,
           SUM(dp.subtotal) AS total_vendido
    FROM public.detalle_pedido dp
    JOIN public.productos pr ON pr.id_producto = dp.id_producto
    JOIN public.categorias c ON c.id_categoria = pr.id_categoria
    JOIN public.pedidos ped ON ped.id_pedido = dp.id_pedido
    GROUP BY ped.fecha_pedido::date, c.id_categoria
), resumen AS (
    SELECT fecha_venta, id_categoria, total_vendido
    FROM mayorista_u4.ventas_categoria_dia
)
SELECT * FROM (
    (SELECT * FROM fuente EXCEPT SELECT * FROM resumen)
    UNION ALL
    (SELECT * FROM resumen EXCEPT SELECT * FROM fuente)
) AS diferencias;

INSERT INTO public.pedidos (id_pedido, fecha_pedido)
SELECT id_pedido, CURRENT_DATE::timestamptz FROM u4_test_keys;
INSERT INTO u4_test_results SELECT 'pedido INSERT', count(*) FROM u4_summary_diff;

INSERT INTO public.productos (id_producto, id_categoria, nombre, precio)
SELECT id_producto, categoria_a, 'u4_test_product', 10.00 FROM u4_test_keys;
INSERT INTO u4_test_results SELECT 'producto INSERT', count(*) FROM u4_summary_diff;

INSERT INTO public.detalle_pedido
    (id_detalle, id_pedido, id_producto, cantidad, precio_unitario, subtotal)
SELECT id_detalle, id_pedido, id_producto, 1, 10.00, 10.00 FROM u4_test_keys;
INSERT INTO u4_test_results SELECT 'detalle INSERT', count(*) FROM u4_summary_diff;

UPDATE public.detalle_pedido dp
SET precio_unitario = dp.precio_unitario + 1,
    subtotal = dp.subtotal + 1
FROM u4_test_keys k
WHERE dp.id_detalle = k.id_detalle;
INSERT INTO u4_test_results SELECT 'detalle UPDATE', count(*) FROM u4_summary_diff;

UPDATE public.pedidos ped
SET fecha_pedido = ped.fecha_pedido + INTERVAL '1 day'
FROM u4_test_keys k
WHERE ped.id_pedido = k.id_pedido;
INSERT INTO u4_test_results SELECT 'pedido UPDATE', count(*) FROM u4_summary_diff;

UPDATE public.productos pr
SET id_categoria = k.categoria_b
FROM u4_test_keys k
WHERE pr.id_producto = k.id_producto;
INSERT INTO u4_test_results SELECT 'producto UPDATE', count(*) FROM u4_summary_diff;

DELETE FROM public.detalle_pedido dp
USING u4_test_keys k
WHERE dp.id_detalle = k.id_detalle;
INSERT INTO u4_test_results SELECT 'detalle DELETE', count(*) FROM u4_summary_diff;

DELETE FROM public.productos pr
USING u4_test_keys k
WHERE pr.id_producto = k.id_producto;
INSERT INTO u4_test_results SELECT 'producto DELETE', count(*) FROM u4_summary_diff;

DELETE FROM public.pedidos ped
USING u4_test_keys k
WHERE ped.id_pedido = k.id_pedido;
INSERT INTO u4_test_results SELECT 'pedido DELETE', count(*) FROM u4_summary_diff;

SELECT * FROM u4_test_results ORDER BY step;
ROLLBACK;

-- 6) Costo de escritura con/sin el trigger de resumen. Ambas inserciones
-- usan la misma fila libre y terminan en ROLLBACK. El primer bloque desactiva
-- solo el trigger propio de la Unidad 4; las FK permanecen activas.
DO $$
BEGIN
    IF current_database() = 'foodstore_tp' THEN
        RAISE EXCEPTION 'No se permite medir escrituras en foodstore_tp';
    END IF;
END;
$$;

BEGIN;
CREATE TEMP TABLE u4_write_key ON COMMIT DROP AS
SELECT (SELECT coalesce(max(id_detalle), 0) + 1 FROM public.detalle_pedido) AS id_detalle,
       ped.id_pedido, pr.id_producto, pr.precio
FROM public.pedidos ped
CROSS JOIN public.productos pr
WHERE NOT EXISTS (
    SELECT 1 FROM public.detalle_pedido dp
    WHERE dp.id_pedido = ped.id_pedido AND dp.id_producto = pr.id_producto
)
ORDER BY ped.id_pedido, pr.id_producto
LIMIT 1;
ALTER TABLE public.detalle_pedido
    DISABLE TRIGGER trg_ventas_categoria_dia_detalle;
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO public.detalle_pedido
    (id_detalle, id_pedido, id_producto, cantidad, precio_unitario, subtotal)
SELECT id_detalle, id_pedido, id_producto, 1, precio, precio
FROM u4_write_key;
ROLLBACK;

BEGIN;
CREATE TEMP TABLE u4_write_key ON COMMIT DROP AS
SELECT (SELECT coalesce(max(id_detalle), 0) + 1 FROM public.detalle_pedido) AS id_detalle,
       ped.id_pedido, pr.id_producto, pr.precio
FROM public.pedidos ped
CROSS JOIN public.productos pr
WHERE NOT EXISTS (
    SELECT 1 FROM public.detalle_pedido dp
    WHERE dp.id_pedido = ped.id_pedido AND dp.id_producto = pr.id_producto
)
ORDER BY ped.id_pedido, pr.id_producto
LIMIT 1;
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO public.detalle_pedido
    (id_detalle, id_pedido, id_producto, cantidad, precio_unitario, subtotal)
SELECT id_detalle, id_pedido, id_producto, 1, precio, precio
FROM u4_write_key;
ROLLBACK;

-- 7) TRUNCATE también debe refrescar el resumen; la transacción se revierte
-- para restaurar el fixture y comprobar que el resumen revierte con la fuente.
CREATE TEMP TABLE u4_truncate_expected ON COMMIT PRESERVE ROWS AS
SELECT count(*) AS detalle_count
FROM public.detalle_pedido;

BEGIN;
TRUNCATE TABLE public.detalle_pedido;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.detalle_pedido)
       OR EXISTS (SELECT 1 FROM mayorista_u4.ventas_categoria_dia) THEN
        RAISE EXCEPTION
            'TRUNCATE no dejó vacíos tanto detalle_pedido como el resumen';
    END IF;

    RAISE NOTICE 'TRUNCATE vació la fuente y el resumen dentro de la transacción.';
END;
$$;
ROLLBACK;

DO $$
DECLARE
    expected_count bigint;
    actual_count bigint;
BEGIN
    SELECT detalle_count INTO expected_count
    FROM u4_truncate_expected;

    SELECT count(*) INTO actual_count
    FROM public.detalle_pedido;

    IF expected_count <> actual_count THEN
        RAISE EXCEPTION
            'ROLLBACK de TRUNCATE restauró % detalles; se esperaban %',
            actual_count, expected_count;
    END IF;

    IF EXISTS (
        WITH ventas_fuente AS (
            SELECT
                ped.fecha_pedido::date AS fecha_venta,
                c.id_categoria,
                SUM(dp.subtotal) AS total_vendido
            FROM public.detalle_pedido AS dp
            JOIN public.productos AS pr
                ON pr.id_producto = dp.id_producto
            JOIN public.categorias AS c
                ON c.id_categoria = pr.id_categoria
            JOIN public.pedidos AS ped
                ON ped.id_pedido = dp.id_pedido
            GROUP BY ped.fecha_pedido::date, c.id_categoria
        ),
        ventas_resumen AS (
            SELECT fecha_venta, id_categoria, total_vendido
            FROM mayorista_u4.ventas_categoria_dia
        )
        (SELECT * FROM ventas_fuente
         EXCEPT
         SELECT * FROM ventas_resumen)
        UNION ALL
        (SELECT * FROM ventas_resumen
         EXCEPT
         SELECT * FROM ventas_fuente)
    ) THEN
        RAISE EXCEPTION
            'El resumen no coincide con la fuente después del ROLLBACK de TRUNCATE';
    END IF;

    RAISE NOTICE
        'ROLLBACK de TRUNCATE restauró % detalles y el resumen coincide.',
        actual_count;
END;
$$;

DROP TABLE u4_truncate_expected;

-- Nota operativa: el recálculo integral garantiza una lógica sencilla de
-- verificar, pero suma trabajo de escritura proporcional al volumen de datos
-- en cada sentencia sobre las tres tablas. Medir su costo antes de adoptarlo.
-- Los triggers y el lock presuponen escrituras ordinarias en READ COMMITTED;
-- validar también el aislamiento y las reglas de borrado/FK de la instancia.
--
-- Limpieza manual en la copia de pruebas, si se descarta la estrategia:
-- DROP TRIGGER trg_ventas_categoria_dia_detalle ON public.detalle_pedido;
-- DROP TRIGGER trg_ventas_categoria_dia_pedido ON public.pedidos;
-- DROP TRIGGER trg_ventas_categoria_dia_producto ON public.productos;
-- DROP TRIGGER trg_ventas_categoria_dia_detalle_truncate ON public.detalle_pedido;
-- DROP TRIGGER trg_ventas_categoria_dia_pedido_truncate ON public.pedidos;
-- DROP TRIGGER trg_ventas_categoria_dia_producto_truncate ON public.productos;
-- DROP FUNCTION mayorista_u4.trg_refrescar_ventas_categoria_dia();
-- DROP FUNCTION mayorista_u4.refrescar_ventas_categoria_dia();
-- DROP TABLE mayorista_u4.ventas_categoria_dia;
