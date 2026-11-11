-- =============================================================================
-- 03_auditoria_test.sql
-- Unidad 5 — Food Store — Parte B
-- Secuencia de prueba de auditoría
--
-- Genera en el log de PostgreSQL las siguientes entradas (según configuración):
--   · Una conexión           (log_connections = on)
--   · Una lectura SELECT     (log_statement = 'all')
--   · Una inserción INSERT   (log_statement = 'mod' o 'all') + ROLLBACK
--   · Una actualización UPDATE (ídem) + ROLLBACK
--   · Un intento de login FALLIDO vía fn_autenticar
--   · Un inicio de sesión EXITOSO vía fn_autenticar
--   · Una desconexión        (log_disconnections = on)
--
-- Prerrequisitos:
--   1. current_database() = 'foodstore_u5_test'
--   2. 00_crear_usuario_tabla.sql ejecutado (tabla usuario + funciones)
--   3. 01_roles.sql ejecutado (roles creados)
--   4. Parámetros de auditoría verificados con 02_auditoria_config.sql
--
-- NOTA SOBRE AUDITORÍA:
--   Los parámetros log_connections, log_disconnections y log_statement son
--   de contexto 'superuser' o 'sighup': se aplican a nivel de instancia con
--   ALTER SYSTEM o editando postgresql.conf. No se pueden cambiar por base.
--   Si la cátedra requiere modificarlos, debe hacerse con autorización
--   explícita y documentarse en informe_auditoria.md.
--   Este script asume que ya están configurados; solo genera las operaciones.
--
-- RESULTADO ESPERADO:
--   El log de PostgreSQL (C:\Program Files\PostgreSQL\18\data\log\)
--   debe contener entradas correspondientes a cada operación.
--   Capturar el fragmento y guardarlo en docs/log_auditoria_prueba.txt.
-- =============================================================================

-- Guarda de seguridad
DO $$
BEGIN
  IF current_database() <> 'foodstore_u5_test' THEN
    RAISE EXCEPTION
      E'BASE INCORRECTA: está conectado a "%".\n'
      'Conectarse a foodstore_u5_test antes de ejecutar este script.',
      current_database();
  END IF;
END $$;

-- Marcar inicio de la secuencia en el log
DO $$
BEGIN
  RAISE LOG 'U5-AUDITORIA-TEST: inicio de secuencia de prueba — base: %', current_database();
END $$;

-- =============================================================================
-- OPERACIÓN 1 — Lectura
-- Aparece en el log si log_statement = 'all'
-- =============================================================================

SELECT
  id_pedido,
  estado,
  total
FROM pedidos
WHERE estado = 'entregado'
LIMIT 5;

-- =============================================================================
-- OPERACIÓN 2 — Inserción con ROLLBACK
-- Aparece en el log con log_statement = 'mod' o 'all'
-- =============================================================================

BEGIN;
  INSERT INTO public.usuario (email, password_hash, rol)
  VALUES ('prueba_auditoria@foodstore.local', 'hash_prueba_temporal', 'soporte');
ROLLBACK;

-- =============================================================================
-- OPERACIÓN 3 — Actualización con ROLLBACK
-- =============================================================================

BEGIN;
  UPDATE pedidos
  SET    estado = 'en_camino'
  WHERE  id_pedido = (SELECT id_pedido FROM pedidos LIMIT 1);
ROLLBACK;

-- =============================================================================
-- OPERACIÓN 4 — Intento de inicio de sesión FALLIDO
-- fn_autenticar retorna FALSE; la llamada queda en el log
-- =============================================================================

SELECT fn_autenticar('app@foodstore.local', 'contraseña_incorrecta_deliberada')
  AS resultado_login_fallido;

-- =============================================================================
-- OPERACIÓN 5 — Inicio de sesión EXITOSO
-- =============================================================================

SELECT fn_autenticar('app@foodstore.local', 'pw_app_web_test')
  AS resultado_login_exitoso;

-- Marcar fin de la secuencia en el log
DO $$
BEGIN
  RAISE LOG 'U5-AUDITORIA-TEST: fin de secuencia de prueba';
END $$;

-- =============================================================================
-- VERIFICACIÓN POST-EJECUCIÓN
-- Confirmar que el fixture de pedidos y usuario quedaron intactos
-- =============================================================================

SELECT
  (SELECT count(*) FROM pedidos)       AS pedidos,
  (SELECT count(*) FROM usuario)       AS usuarios,
  (SELECT count(*) FROM detalle_pedido) AS detalles;
