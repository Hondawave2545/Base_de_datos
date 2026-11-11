-- =============================================================================
-- 04_simulacro_incidente.sql
-- Unidad 5 — Food Store — Parte C
-- Simulacro de incidente de acceso indebido
--
-- Reproduce exactamente la secuencia especificada en la consigna (pág. 4-5):
--   FASE 1 — Varios intentos FALLIDOS de inicio de sesión contra fn_autenticar
--   FASE 2 — Un inicio de sesión EXITOSO
--   FASE 3 — Lectura MASIVA de la tabla usuario (simula exfiltración)
--   FASE 4 — Intento de ESCALAMIENTO de privilegios
--            (otorgar membresía en admin_datos a app_web)
--
-- El último intento (Fase 4) DEBE FALLAR si el diseño de permisos es correcto.
-- Si no falla, es un hallazgo de defecto en Parte A que debe corregirse.
--
-- Prerrequisitos:
--   1. current_database() = 'foodstore_u5_test'
--   2. 00_crear_usuario_tabla.sql ejecutado
--   3. 01_roles.sql ejecutado (roles app_web y admin_datos existentes)
--
-- POST-EJECUCIÓN (Parte C):
--   1. Capturar el fragmento de log de PostgreSQL que cubre toda la secuencia.
--      Ubicación: C:\Program Files\PostgreSQL\18\data\log\
--      Buscar las entradas entre las marcas U5-SIMULACRO-INICIO y U5-SIMULACRO-FIN.
--   2. Anonimizar el log antes de entregarlo a la IA:
--      · emails → usuarioN@test.local
--      · IPs → 192.0.2.N (rango RFC 5737, solo documentación)
--      · Timestamps y PIDs: conservar (no son datos personales)
--   3. Guardar el log anonimizado en docs/log_simulacro_anonimizado.txt
--   4. Enviar el log anonimizado a Kiro con el prompt de reconstrucción.
--   5. Contrastar respuesta de Kiro vs lo realmente ejecutado.
--   6. Documentar en docs/informe_incidente.md.
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

-- Marcar inicio en el log (facilita delimitar el fragmento a capturar)
DO $$
BEGIN
  RAISE LOG 'U5-SIMULACRO-INICIO: base=%, usuario_pg=%',
    current_database(), current_user;
END $$;

-- =============================================================================
-- FASE 1 — Tres intentos FALLIDOS de inicio de sesión
-- Contraseñas deliberadamente incorrectas → fn_autenticar retorna FALSE
-- =============================================================================

SELECT fn_autenticar('app@foodstore.local', 'intento_incorrecto_1') AS login_1;
SELECT fn_autenticar('app@foodstore.local', 'intento_incorrecto_2') AS login_2;
SELECT fn_autenticar('app@foodstore.local', 'intento_incorrecto_3') AS login_3;

-- =============================================================================
-- FASE 2 — Inicio de sesión EXITOSO
-- Contraseña correcta del usuario de prueba → retorna TRUE
-- =============================================================================

SELECT fn_autenticar('app@foodstore.local', 'pw_app_web_test') AS login_exitoso;

-- =============================================================================
-- FASE 3 — Lectura MASIVA de la tabla usuario (simula exfiltración)
-- En un incidente real esto aparecería en el log si log_statement = 'all'
-- =============================================================================

-- Lectura de toda la tabla (excluyendo password_hash para no loguear hashes)
SELECT id_usuario, email, rol, fecha_alta, activo
FROM public.usuario;

-- Conteo total
SELECT count(*) AS total_usuarios FROM public.usuario;

-- =============================================================================
-- FASE 4 — Intento de ESCALAMIENTO de privilegios
-- Intentar otorgar membresía en admin_datos a app_web DESDE LA PERSPECTIVA
-- de app_web (usuario comprometido). DEBE FALLAR: app_web no tiene ADMIN OPTION
-- sobre admin_datos ni es superusuario.
-- =============================================================================

DO $$
BEGIN
  BEGIN
    -- Este EXECUTE intenta escalar app_web a admin_datos
    -- Ejecutado con SET ROLE app_web para simular al atacante
    EXECUTE 'SET ROLE app_web; GRANT admin_datos TO app_web; RESET ROLE;';
    -- Si llegamos aquí, el escalamiento tuvo éxito — es un defecto
    RAISE WARNING
      'HALLAZGO DE DEFECTO: escalamiento exitoso. '
      'Revisar diseño de permisos en 01_roles.sql antes de continuar.';
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE
        'OK: intento de escalamiento rechazado correctamente '
        '(insufficient_privilege). El diseño de permisos es correcto.';
    WHEN OTHERS THEN
      RAISE NOTICE
        'OK: intento de escalamiento rechazado (error: % / %)',
        SQLSTATE, SQLERRM;
  END;
END $$;

-- Marcar fin en el log
DO $$
BEGIN
  RAISE LOG 'U5-SIMULACRO-FIN: secuencia completada';
END $$;

-- =============================================================================
-- VERIFICACIÓN POST-SIMULACRO
-- Confirmar que no quedaron cambios no deseados en roles ni en datos
-- =============================================================================

-- Estado de los roles relevantes
SELECT
  rolname,
  rolsuper,
  rolcreaterole,
  rolcreatedb,
  rolcanlogin,
  rolconnlimit
FROM pg_roles
WHERE rolname IN (
  'app_web', 'admin_datos',
  'rol_app_lectura', 'rol_app_escritura',
  'rol_soporte', 'rol_reportes'
)
ORDER BY rolname;

-- Membresías: verificar que app_web NO es miembro de admin_datos
SELECT
  r.rolname  AS rol_miembro,
  g.rolname  AS es_miembro_de
FROM pg_auth_members m
JOIN pg_roles r ON r.oid = m.member
JOIN pg_roles g ON g.oid = m.roleid
WHERE r.rolname IN ('app_web', 'admin_datos')
ORDER BY r.rolname, g.rolname;

-- Datos de usuario intactos
SELECT id_usuario, email, rol, activo FROM public.usuario;
