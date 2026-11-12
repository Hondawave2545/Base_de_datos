-- health_check.sql
-- Unidad 6 — Food Store — Controles de monitoreo y salud
-- Ejecutar en la base objetivo (foodstore_tp o foodstore_restore_test)
-- Retorna resultados tabulares para logging/alerting

\echo '=== HEALTH CHECK FOOD STORE ==='
\echo 'Base:' current_database()
\echo 'Timestamp:' now()
\echo ''

-- 1. TAMAÑO DE BASE Y TABLAS PRINCIPALES
\echo '--- 1. TAMAÑO DE BASE Y TABLAS ---'
SELECT
    pg_size_pretty(pg_database_size(current_database())) AS tamaño_base;

SELECT
    schemaname,
    relname AS tabla,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||relname)) AS tamaño_total,
    pg_size_pretty(pg_relation_size(schemaname||'.'||relname)) AS tamaño_tabla,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||relname) - pg_relation_size(schemaname||'.'||relname)) AS tamaño_indices
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||relname) DESC;

-- 2. TUOPLAS MUERTAS Y AUTOVACUUM
\echo ''
\echo '--- 2. TUOPLAS MUERTAS Y AUTOVACUUM ---'
SELECT
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    CASE WHEN n_live_tup > 0
         THEN round(100.0 * n_dead_tup / n_live_tup, 2)
         ELSE 0 END AS pct_muertas,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze,
    vacuum_count,
    autovacuum_count,
    analyze_count,
    autoanalyze_count
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_dead_tup DESC NULLS LAST;

-- Alerta: tablas con > 20% tuplas muertas
\echo ''
\echo '--- ALERTA: Tablas con > 20% tuplas muertas ---'
SELECT
    relname AS tabla,
    n_live_tup,
    n_dead_tup,
    round(100.0 * n_dead_tup / nullif(n_live_tup,0), 2) AS pct_muertas
FROM pg_stat_user_tables
WHERE schemaname = 'public'
  AND n_live_tup > 0
  AND (n_dead_tup::numeric / nullif(n_live_tup,0)) > 0.20
ORDER BY pct_muertas DESC;

-- 3. TRANSACCIONES LARGAS Y BLOQUEOS
\echo ''
\echo '--- 3. TRANSACCIONES ACTIVAS ( > 5 min ) ---'
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    now() - xact_start AS duracion_transaccion,
    now() - query_start AS duracion_query,
    left(query, 200) AS query_preview
FROM pg_stat_activity
WHERE state = 'active'
  AND xact_start < now() - interval '5 minutes'
  AND pid <> pg_backend_pid()
ORDER BY xact_start;

\echo ''
\echo '--- 4. BLOQUEOS ACTIVOS ---'
SELECT
    l.locktype,
    l.database,
    l.relation::regclass AS tabla,
    l.mode,
    l.granted,
    a.pid,
    a.usename,
    a.query_start,
    left(a.query, 200) AS query_preview
FROM pg_locks l
JOIN pg_stat_activity a ON a.pid = l.pid
WHERE l.database = (SELECT oid FROM pg_database WHERE datname = current_database())
  AND NOT l.granted
ORDER BY a.query_start;

-- 5. ESTADO DE ÍNDICES (tamaño, uso, duplicados potenciales)
\echo ''
\echo '--- 5. ESTADO DE ÍNDICES ---'
SELECT
    schemaname,
    relname AS tabla,
    indexrelname AS indice,
    pg_size_pretty(pg_relation_size(indexrelid)) AS tamaño,
    idx_scan AS lecturas,
    idx_tup_read AS tuplas_leidas,
    idx_tup_fetch AS tuplas_obtenidas
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Índices no usados (idx_scan = 0)
\echo ''
\echo '--- ALERTA: Índices no usados (idx_scan = 0) ---'
SELECT
    schemaname,
    relname AS tabla,
    indexrelname AS indice,
    pg_size_pretty(pg_relation_size(indexrelid)) AS tamaño
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- 6. BLOAT ESTIMADO (aproximado via pgstattuple si existe, sino heurística)
\echo ''
\echo '--- 6. BLOAT HEURÍSTICO (tablas > 100 MB o > 20% muertas) ---'
SELECT
    c.relname AS tabla,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS tamaño_total,
    s.n_live_tup,
    s.n_dead_tup,
    round(100.0 * s.n_dead_tup / nullif(s.n_live_tup,0), 2) AS pct_muertas,
    CASE
        WHEN s.n_live_tup > 0 AND s.n_dead_tup::numeric / s.n_live_tup > 0.30 THEN 'ALTO - CANDIDATO VACUUM FULL'
        WHEN s.n_live_tup > 0 AND s.n_dead_tup::numeric / s.n_live_tup > 0.20 THEN 'MEDIO - MONITOREAR'
        ELSE 'OK'
    END AS recomendacion
FROM pg_class c
JOIN pg_stat_user_tables s ON s.relname = c.relname
WHERE c.relkind = 'r'
  AND s.schemaname = 'public'
  AND (pg_total_relation_size(c.oid) > 100*1024*1024 OR (s.n_live_tup > 0 AND s.n_dead_tup::numeric / s.n_live_tup > 0.20))
ORDER BY pg_total_relation_size(c.oid) DESC;

-- 7. CONTEOS DE FILAS (validación rápida de integridad)
\echo ''
\echo '--- 7. CONTEOS DE FILAS ---'
SELECT 'categorias' AS tabla, count(*) FROM categorias
UNION ALL SELECT 'sucursales', count(*) FROM sucursales
UNION ALL SELECT 'empleados', count(*) FROM empleados
UNION ALL SELECT 'clientes', count(*) FROM clientes
UNION ALL SELECT 'productos', count(*) FROM productos
UNION ALL SELECT 'pedidos', count(*) FROM pedidos
UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido
UNION ALL SELECT 'pagos', count(*) FROM pagos
ORDER BY tabla;

-- 8. VALIDACIONES DE RESTRICCIONES LÓGICAS
\echo ''
\echo '--- 8. VALIDACIONES LÓGICAS (deben retornar 0) ---'
SELECT 'detalle_pedido cantidad <= 0' AS check, count(*) FROM detalle_pedido WHERE cantidad <= 0
UNION ALL SELECT 'productos stock < 0', count(*) FROM productos WHERE stock < 0
UNION ALL SELECT 'pedidos total < 0', count(*) FROM pedidos WHERE total < 0
UNION ALL SELECT 'pagos monto < 0', count(*) FROM pagos WHERE monto < 0
UNION ALL SELECT 'clientes email duplicados', count(*) - count(DISTINCT email) FROM clientes
UNION ALL SELECT 'empleados dni duplicados', count(*) - count(DISTINCT dni) FROM empleados
UNION ALL SELECT 'productos precio < 0', count(*) FROM productos WHERE precio < 0;

-- 9. ESTADO DE VISTAS Y VISTA MATERIALIZADA
\echo ''
\echo '--- 9. VISTAS Y MV ---'
SELECT 'v_productos_vigentes' AS objeto, count(*) FROM v_productos_vigentes
UNION ALL SELECT 'v_pedidos_cliente', count(*) FROM v_pedidos_cliente
UNION ALL SELECT 'v_detalle_pedido', count(*) FROM v_detalle_pedido
UNION ALL SELECT 'v_clientes_publico', count(*) FROM v_clientes_publico
UNION ALL SELECT 'mv_facturacion_categoria_mes', count(*) FROM mv_facturacion_categoria_mes;

-- Edad de la MV
\echo ''
\echo '--- Edad de mv_facturacion_categoria_mes ---'
SELECT
    max(mes) AS ultimo_mes,
    now()::date - max(mes) AS dias_desde_ultima_actualizacion
FROM mv_facturacion_categoria_mes;

-- 10. ROLES Y PERMISOS (Unidad 5)
\echo ''
\echo '--- 10. ROLES CREADOS ---'
SELECT rolname, rolsuper, rolcreaterole, rolcanlogin, rolconnlimit
FROM pg_roles
WHERE rolname IN (
    'rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes','rol_auditoria',
    'app_web','admin_datos'
)
ORDER BY rolname;

\echo ''
\echo '=== FIN HEALTH CHECK ==='