-- =============================================================================
-- 02_auditoria_config.sql
-- Unidad 5 — Food Store — Parte B
-- Documentación de la configuración de auditoría de PostgreSQL
--
-- IMPORTANTE: Este archivo NO modifica la configuración del servidor.
-- Es un registro de referencia de los parámetros a configurar y los comandos
-- para verificar el estado actual.
--
-- La modificación real de postgresql.conf requiere autorización del estudiante
-- y se documenta en docs/informe_auditoria.md.
-- =============================================================================

-- =============================================================================
-- PASO 1 — Verificar el estado actual de los parámetros de auditoría
-- (SOLO LECTURA — se puede ejecutar en cualquier base)
-- =============================================================================

-- Verificar base activa (precaución de hábito)
SELECT current_database(), current_setting('server_version') AS version;

-- Ver parámetros de log actuales
SELECT name, setting, unit, context, short_desc
FROM pg_settings
WHERE name IN (
  'log_connections',
  'log_disconnections',
  'log_statement',
  'log_min_duration_statement',
  'log_line_prefix',
  'log_destination',
  'logging_collector',
  'log_directory',
  'log_filename',
  'log_file_mode',
  'log_rotation_age',
  'log_rotation_size'
)
ORDER BY name;

-- Ver si logging_collector está activo (necesario para capturar en archivo)
SELECT current_setting('logging_collector') AS logging_collector_activo;

-- Ver dónde van los logs actualmente
SELECT current_setting('log_destination') AS destino_log,
       current_setting('log_directory')   AS directorio_log,
       current_setting('log_filename')    AS nombre_archivo_log;

-- =============================================================================
-- PARÁMETROS A CONFIGURAR (en postgresql.conf)
-- [ PENDIENTE — no ejecutar hasta autorización ]
-- =============================================================================

-- Los siguientes valores son los recomendados para la Parte B.
-- Se aplican editando postgresql.conf o con ALTER SYSTEM (requiere superusuario
-- y recarga del servidor).
--
-- Parámetro              | Valor propuesto   | Qué registra
-- ---------------------- | ----------------- | ----------------------------------
-- log_connections        | on                | Cada conexión nueva al servidor
-- log_disconnections     | on                | Cada cierre de sesión
-- log_statement          | mod               | INSERT, UPDATE, DELETE, DDL (no SELECT simples)
-- log_min_duration_stmt  | -1                | No filtrar por duración (capturar todo lo que llega por log_statement)
-- log_line_prefix        | '%t [%p] %u@%d '  | Timestamp, PID, usuario@base
-- logging_collector      | on                | Redirigir logs a archivo (en lugar de stderr)
--
-- Valor 'mod' para log_statement registra operaciones de escritura sin registrar
-- cada SELECT, lo que reduce ruido y se orienta a auditoría de modificaciones.
-- Para registrar también los SELECT (intentos de acceso) se usaría 'all', pero
-- en entornos de producción generaría un volumen muy alto de log.

-- =============================================================================
-- OPCIÓN ALTERNATIVA: ALTER SYSTEM (requiere superusuario + pg_reload_conf())
-- [ PENDIENTE — no ejecutar hasta autorización ]
-- =============================================================================

-- ALTER SYSTEM SET log_connections     = 'on';
-- ALTER SYSTEM SET log_disconnections  = 'on';
-- ALTER SYSTEM SET log_statement       = 'mod';
-- ALTER SYSTEM SET log_line_prefix     = '%t [%p] %u@%d ';
-- SELECT pg_reload_conf();   -- aplica sin reiniciar el servidor

-- Verificar que los cambios tomaron efecto:
-- SELECT name, setting FROM pg_settings
-- WHERE name IN ('log_connections','log_disconnections','log_statement','log_line_prefix');
