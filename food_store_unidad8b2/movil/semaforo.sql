-- ============================================================================
-- Food Store - Unidad 8 - Semaforo de sincronizacion (Consigna 2.b)
-- Base: foodstore_movil.db
-- Regla de oro: el movil propone, el servidor dispone.
-- Prioridad: RECHAZADO > CONFLICTO > SIMULADO_APROBADO
-- Solo procesa solicitudes con estado = 'PENDIENTE'.
-- No modifica PostgreSQL. No modifica producto_cache ni snapshot_servidor.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- Tabla temporal de evaluacion (una fila por solicitud PENDIENTE)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS _sync_eval;
CREATE TEMP TABLE _sync_eval (
    solicitud_uuid TEXT NOT NULL,
    estado         TEXT NOT NULL CHECK (estado IN ('RECHAZADO','CONFLICTO','SIMULADO_APROBADO')),
    motivo         TEXT NOT NULL
);

-- ----------------------------------------------------------------------------
-- Evaluacion: comparar cada item del borrador contra snapshot_servidor
-- ----------------------------------------------------------------------------
INSERT INTO _sync_eval (solicitud_uuid, estado, motivo)
SELECT
    c.solicitud_uuid,
    -- Prioridad: cualquier motivo de rechazo gana sobre conflicto
    CASE
        WHEN COUNT(CASE WHEN s.id IS NULL THEN 1 END) > 0 THEN 'RECHAZADO'
        WHEN COUNT(CASE WHEN s.eliminado = 1 THEN 1 END) > 0 THEN 'RECHAZADO'
        WHEN COUNT(CASE WHEN s.disponible = 0 THEN 1 END) > 0 THEN 'RECHAZADO'
        WHEN COUNT(CASE WHEN s.stock < i.cantidad THEN 1 END) > 0 THEN 'RECHAZADO'
        WHEN COUNT(CASE WHEN s.precio_centavos <> i.precio_centavos_visto THEN 1 END) > 0 THEN 'CONFLICTO'
        ELSE 'SIMULADO_APROBADO'
    END,
    -- Motivos concatenados para trazabilidad
    TRIM(
        CASE WHEN COUNT(CASE WHEN s.id IS NULL THEN 1 END) > 0
             THEN 'producto_inexistente;' ELSE '' END ||
        CASE WHEN COUNT(CASE WHEN s.eliminado = 1 THEN 1 END) > 0
             THEN 'producto_baja_logica;' ELSE '' END ||
        CASE WHEN COUNT(CASE WHEN s.disponible = 0 THEN 1 END) > 0
             THEN 'producto_no_disponible;' ELSE '' END ||
        CASE WHEN COUNT(CASE WHEN s.stock < i.cantidad THEN 1 END) > 0
             THEN 'stock_insuficiente;' ELSE '' END ||
        CASE WHEN COUNT(CASE WHEN s.precio_centavos <> i.precio_centavos_visto THEN 1 END) > 0
             THEN 'conflicto_precio;' ELSE '' END ||
        CASE WHEN COUNT(CASE WHEN s.id IS NULL THEN 1 END) = 0
                  AND COUNT(CASE WHEN s.eliminado = 1 THEN 1 END) = 0
                  AND COUNT(CASE WHEN s.disponible = 0 THEN 1 END) = 0
                  AND COUNT(CASE WHEN s.stock < i.cantidad THEN 1 END) = 0
                  AND COUNT(CASE WHEN s.precio_centavos <> i.precio_centavos_visto THEN 1 END) = 0
             THEN 'todo_coincide;' ELSE '' END
    , ';')
FROM cola_sync c
JOIN item_borrador i ON i.id_local = c.id_local
LEFT JOIN snapshot_servidor s ON s.id = i.producto_id
WHERE c.estado = 'PENDIENTE'
GROUP BY c.solicitud_uuid;

-- ----------------------------------------------------------------------------
-- Actualizar cola_sync con el resultado (estado y motivo)
-- Solo las solicitudes que estaban PENDIENTE se tocan; las ya procesadas
-- (RECHAZADO/CONFLICTO/SIMULADO_APROBADO) no se reevaluan -> idempotencia.
-- ----------------------------------------------------------------------------
UPDATE cola_sync
SET estado = (SELECT e.estado  FROM _sync_eval e WHERE e.solicitud_uuid = cola_sync.solicitud_uuid),
    motivo = (SELECT e.motivo  FROM _sync_eval e WHERE e.solicitud_uuid = cola_sync.solicitud_uuid)
WHERE solicitud_uuid IN (SELECT solicitud_uuid FROM _sync_eval);

-- ----------------------------------------------------------------------------
-- Informe de resultados del semaforo
-- ----------------------------------------------------------------------------
SELECT 'SEMAFORO_resumen' AS reporte,
       count(*) AS total_procesadas,
       sum(CASE WHEN estado = 'RECHAZADO' THEN 1 ELSE 0 END) AS rechazadas,
       sum(CASE WHEN estado = 'CONFLICTO' THEN 1 ELSE 0 END) AS conflictos,
       sum(CASE WHEN estado = 'SIMULADO_APROBADO' THEN 1 ELSE 0 END) AS aprobados
FROM cola_sync
WHERE solicitud_uuid IN (SELECT solicitud_uuid FROM _sync_eval);

SELECT 'SEMAFORO_detalle' AS reporte,
       solicitud_uuid, id_local, estado, motivo
FROM cola_sync
WHERE solicitud_uuid IN (SELECT solicitud_uuid FROM _sync_eval)
ORDER BY solicitud_uuid;

-- ============================================================================
-- Fin del semaforo
-- ============================================================================
