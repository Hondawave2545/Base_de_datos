-- maintenance.sql
-- Unidad 6 — Food Store — Mantenimiento programado
-- Ejecutar en base objetivo (foodstore_tp o foodstore_restore_test)
-- Incluye: revisión autovacuum, ANALYZE, acción de mantenimiento justificada

\echo '=== MANTENIMIENTO FOOD STORE ==='
\echo 'Base:' current_database()
\echo 'Timestamp:' now()
\echo ''

-- 1. ESTADO ACTUAL DE AUTOVACUUM
\echo '--- 1. CONFIGURACIÓN AUTOVACUUM (parámetros de instancia) ---'
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name LIKE 'autovacuum%'
   OR name = 'track_counts'
ORDER BY name;

\echo ''
\echo '--- 2. ESTADÍSTICAS DE AUTOVACUUM POR TABLA ---'
SELECT
    relname AS tabla,
    autovacuum_count,
    autoanalyze_count,
    last_autovacuum,
    last_autoanalyze,
    n_live_tup,
    n_dead_tup,
    round(100.0 * n_dead_tup / nullif(n_live_tup,0), 2) AS pct_muertas
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_dead_tup DESC NULLS LAST;

-- 3. EJECUTAR ANALYZE COMPLETO (actualiza estadísticas del planificador)
\echo ''
\echo '--- 3. EJECUTANDO ANALYZE COMPLETO ---'
ANALYZE VERBOSE;

-- 4. ACCIÓN DE MANTENIMIENTO JUSTIFICADA
-- Revisar bloat y decidir VACUUM (FULL) solo si necesario
\echo ''
\echo '--- 4. EVALUACIÓN DE BLOAT PARA VACUUM FULL ---'
-- Criterio: tabla > 100 MB Y > 30% tuplas muertas
-- NOTA: VACUUM FULL bloquea la tabla en exclusiva. Solo en ventana de mantenimiento.
-- En producción, preferir pg_repack o VACUUM (no FULL) concurrente.
DO $$
DECLARE
    r record;
    v_sql text;
    v_msg text;
BEGIN
    FOR r IN
        SELECT
            relname,
            pg_total_relation_size(oid) AS total_bytes,
            n_live_tup,
            n_dead_tup,
            round(100.0 * n_dead_tup / nullif(n_live_tup,0), 2) AS pct_muertas
        FROM pg_class c
        JOIN pg_stat_user_tables s ON s.relname = c.relname
        WHERE c.relkind = 'r'
          AND s.schemaname = 'public'
          AND pg_total_relation_size(c.oid) > 100*1024*1024
          AND n_live_tup > 0
          AND n_dead_tup::numeric / n_live_tup > 0.30
    LOOP
        v_msg := format('CANDIDATO VACUUM FULL: %s (tamaño: %s, %s tuplas muertas, %.2f%%)',
            r.relname,
            pg_size_pretty(r.total_bytes),
            r.n_dead_tup,
            r.pct_muertas);
        RAISE NOTICE '%', v_msg;

        -- EN PRODUCCIÓN COMENTAR ESTA LÍNEA Y USAR pg_repack O VACUUM CONCURRENTE
        -- v_sql := 'VACUUM FULL ' || quote_ident(r.relname) || ';';
        -- RAISE NOTICE 'Ejecutando: %', v_sql;
        -- EXECUTE v_sql;
    END LOOP;

    IF NOT FOUND THEN
        RAISE NOTICE 'No hay tablas que cumplan criterio VACUUM FULL (>100MB y >30% muertas).';
    END IF;
END $$;

-- 5. VACUUM ESTÁNDAR (no bloqueante) EN TABLAS CON MÁS DE 20% MUERTAS
\echo ''
\echo '--- 5. VACUUM ESTÁNDAR EN TABLAS CON >20% MUESTRAS ---'
DO $$
DECLARE
    r record;
    v_sql text;
    v_msg text;
BEGIN
    FOR r IN
        SELECT relname
        FROM pg_stat_user_tables
        WHERE schemaname = 'public'
          AND n_live_tup > 0
          AND n_dead_tup::numeric / n_live_tup > 0.20
    LOOP
        v_sql := 'VACUUM ' || quote_ident(r.relname) || ';';
        v_msg := 'Ejecutando: ' || v_sql;
        RAISE NOTICE '%', v_msg;
        EXECUTE v_sql;
    END LOOP;

    IF NOT FOUND THEN
        RAISE NOTICE 'No hay tablas con >20% tuplas muertas para VACUUM estándar.';
    END IF;
END $$;

-- 6. REFRESCO DE VISTA MATERIALIZADA (CONCURRENTLY para no bloquear lecturas)
\echo ''
\echo '--- 6. REFRESCO DE mv_facturacion_categoria_mes ---'
-- Requiere índice único (creado en Unidad 3)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
\echo 'Vista materializada refrescada.'

-- 7. VERIFICACIÓN POST-MANTENIMIENTO
\echo ''
\echo '--- 7. ESTADO POST-MANTENIMIENTO ---'
SELECT
    relname AS tabla,
    n_live_tup,
    n_dead_tup,
    round(100.0 * n_dead_tup / nullif(n_live_tup,0), 2) AS pct_muertas,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_dead_tup DESC NULLS LAST;

-- 8. ESTADÍSTICAS DEL PLANIFICADOR
\echo ''
\echo '--- 8. ESTADÍSTICAS DE COLUMNAS ACTUALIZADAS (muestra) ---'
SELECT
    schemaname,
    tablename,
    attname AS columna,
    n_distinct,
    most_common_vals AS valores_comunes,
    most_common_freqs AS frecuencias_comunes
FROM pg_stats
WHERE schemaname = 'public'
  AND tablename IN ('pedidos','detalle_pedido','productos','clientes')
ORDER BY tablename, attname
LIMIT 20;

\echo ''
\echo '=== FIN MANTENIMIENTO ==='