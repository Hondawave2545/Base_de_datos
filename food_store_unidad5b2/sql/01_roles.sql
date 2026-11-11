-- =============================================================================
-- 01_roles.sql
-- Unidad 5 — Food Store — Parte A
-- Esquema de roles y permisos de mínimo privilegio
--
-- Especificación de requisitos : docs/kiro_roles_spec/requirements.md (Rev. 2)
-- Especificación de diseño     : docs/kiro_roles_spec/design.md        (Rev. 3)
-- Revisión de seguridad        : 2026-11-11 (Rev. 4)
--   · Contraseñas eliminadas del script — configurar con ALTER ROLE (ver abajo)
--   · Paso K movido después de CREATE ROLE admin_datos (orden de dependencia)
--   · ALTER DEFAULT PRIVILEGES J3 eliminado — soporte no recibe SELECT automático
--   · Advertencia ampliada sobre REVOKE ALL ON SCHEMA public FROM PUBLIC
--
-- PRERREQUISITOS — verificar antes de ejecutar:
--   P1. current_database() = 'foodstore_u5_test'   (guarda automática al inicio)
--   P2. 00_crear_usuario_tabla.sql ya fue ejecutado (tabla usuario + funciones)
--   P3. Las firmas reales de fn_autenticar y fn_resetear_password fueron
--       confirmadas — ambas son (text, text)
--   P4. Los nombres de sequences fueron confirmados con pg_sequences:
--       pedidos_id_pedido_seq, detalle_pedido_id_detalle_seq, pagos_id_pago_seq
--   P5. Las vistas v_* y mv_facturacion_categoria_mes existen en public.
--
-- SENTENCIAS VERIFICADAS EN ENTORNO REAL:
--   [SEQ]  Paso E7  — sequences confirmados: pedidos_id_pedido_seq, detalle_pedido_id_detalle_seq, pagos_id_pago_seq
--   [FUN]  Pasos A3, A4, I1, L9 — firmas confirmadas: fn_autenticar(text, text), fn_resetear_password(text, text)
--
-- CONTRASEÑAS — cómo configurarlas de forma segura:
--   Las contraseñas NO están en este script. Después de ejecutarlo, establecerlas
--   en una sesión separada que NO quede en el historial de Git:
--
--     ALTER ROLE app_web    PASSWORD '<contraseña_segura>';
--     ALTER ROLE admin_datos PASSWORD '<contraseña_segura>';
--
--   Usar contraseñas de al menos 20 caracteres, generadas aleatoriamente.
--   Almacenarlas en un gestor de secretos (vault, archivo .env fuera del repo,
--   variable de entorno) y nunca en texto plano dentro del repositorio.
--
-- NOTA SOBRE REVOKE ALL ON SCHEMA public:
--   El Paso A2 revoca USAGE sobre el schema a PUBLIC. Esto afecta a todos los
--   roles que no reciban GRANT USAGE explícito después. Los roles de este script
--   lo reciben en el Paso C. Si existen otros roles en la instancia (extensiones,
--   herramientas de monitoreo, roles heredados) podrían perder acceso a public.
--   Verificar con:
--     SELECT rolname FROM pg_roles WHERE rolname NOT IN
--       ('postgres','pg_monitor','pg_read_all_settings','pg_read_all_stats',
--        'pg_stat_scan_tables','pg_signal_backend','pg_read_server_files',
--        'pg_write_server_files','pg_execute_server_program','pg_checkpoint');
--   antes de ejecutar en un entorno compartido.
--
-- =============================================================================


-- =============================================================================
-- GUARDA DE SEGURIDAD
-- Aborta inmediatamente si la base activa no es foodstore_u5_test.
-- La cláusula DO/RAISE EXCEPTION garantiza que ninguna sentencia posterior
-- se ejecuta si la base es incorrecta.
-- =============================================================================
DO $$
BEGIN
  IF current_database() <> 'foodstore_u5_test' THEN
    RAISE EXCEPTION
      E'BASE INCORRECTA: está conectado a "%".\n'
      'Conectarse a foodstore_u5_test antes de ejecutar este script.',
      current_database();
  END IF;
END $$;


-- =============================================================================
-- SECCIÓN DE LIMPIEZA (comentada por defecto)
-- Descomentar SOLO para re-ejecutar en un entorno de prueba limpio.
-- No ejecutar en ninguna base que ya tenga estos roles en uso productivo.
-- Orden: primero los roles de login (que son miembros), luego los de grupo.
-- =============================================================================
-- DROP ROLE IF EXISTS app_web;
-- DROP ROLE IF EXISTS admin_datos;
-- DROP ROLE IF EXISTS rol_app_lectura;
-- DROP ROLE IF EXISTS rol_app_escritura;
-- DROP ROLE IF EXISTS rol_soporte;
-- DROP ROLE IF EXISTS rol_reportes;
-- DROP ROLE IF EXISTS rol_auditoria;


-- =============================================================================
-- PASO A — Revocar privilegios implícitos de PUBLIC
--
-- PostgreSQL otorga por defecto a PUBLIC:
--   · EXECUTE sobre cualquier función nueva
--   · USAGE sobre el schema public (en todas las versiones)
--   · CREATE sobre schema public (en versiones < 15; eliminado en PG 15+)
--
-- Se revocan explícitamente para partir de un estado limpio antes de los
-- GRANT selectivos. Ver advertencia en el encabezado sobre roles externos.
-- =============================================================================

-- A1. Revocar acceso implícito de PUBLIC a todas las tablas ya existentes en public.
--     No afecta a vistas ni funciones (esas se tratan en A3/A4 y en Paso I/L9).
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

-- A2. Revocar USAGE (y CREATE si aplica) de PUBLIC sobre el schema public.
--     Después de este punto, solo los roles con GRANT USAGE explícito pueden
--     referencia objetos en public. Los roles de este script lo reciben en Paso C.
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- A3. Revocar EXECUTE implícito de PUBLIC sobre fn_autenticar
-- Firma confirmada: fn_autenticar(text, text)
REVOKE ALL ON FUNCTION fn_autenticar(text, text) FROM PUBLIC;

-- A4. Revocar EXECUTE implícito de PUBLIC sobre fn_resetear_password
-- Firma confirmada: fn_resetear_password(text, text)
REVOKE ALL ON FUNCTION fn_resetear_password(text, text) FROM PUBLIC;


-- =============================================================================
-- PASO B — Crear roles de grupo (NOLOGIN)
--
-- Representan conjuntos de privilegios por función de negocio.
-- No pueden iniciar sesión directamente (NOLOGIN).
-- Deben existir antes de los GRANT de Pasos D–J.
-- =============================================================================

CREATE ROLE rol_app_lectura   NOLOGIN;  -- Lectura de vistas para la aplicación web
CREATE ROLE rol_app_escritura NOLOGIN;  -- Escritura operativa de pedidos y pagos
CREATE ROLE rol_soporte       NOLOGIN;  -- Consulta y actualización de estado por soporte
CREATE ROLE rol_reportes      NOLOGIN;  -- Lectura de reportes de facturación
CREATE ROLE rol_auditoria     NOLOGIN;  -- Lectura de la tabla de auditoría (Parte B)


-- =============================================================================
-- PASO C — Acceso al schema public
--
-- Los roles de grupo reciben USAGE explícito sobre public.
-- Los roles de login (app_web, admin_datos) lo obtienen por herencia de sus
-- roles de grupo; NO se les otorga USAGE directamente.
-- =============================================================================

GRANT USAGE ON SCHEMA public TO
  rol_app_lectura,
  rol_app_escritura,
  rol_soporte,
  rol_reportes,
  rol_auditoria;


-- =============================================================================
-- PASO D — Privilegios para rol_app_lectura
--
-- Solo acceso a las cuatro vistas públicas; ningún acceso a tablas base.
-- Las vistas ya filtran columnas sensibles (teléfono, dirección, credenciales).
-- =============================================================================

GRANT SELECT ON v_productos_vigentes TO rol_app_lectura;
GRANT SELECT ON v_pedidos_cliente    TO rol_app_lectura;
GRANT SELECT ON v_detalle_pedido     TO rol_app_lectura;
GRANT SELECT ON v_clientes_publico   TO rol_app_lectura;


-- =============================================================================
-- PASO E — Privilegios para rol_app_escritura
--
-- SELECT sobre maestros de referencia necesarios para validar inserciones.
-- INSERT + UPDATE sobre las tres tablas del flujo de pedidos.
-- Sin acceso a usuario, empleados ni sucursales.
-- Sin UPDATE sobre clientes (los datos del cliente no los modifica la app).
-- =============================================================================

-- E1–E3. Lectura de maestros de referencia
GRANT SELECT ON clientes   TO rol_app_escritura;
GRANT SELECT ON productos  TO rol_app_escritura;  -- incluye stock: decisión aceptada (ver requirements.md)
GRANT SELECT ON categorias TO rol_app_escritura;

-- E4–E6. Escritura sobre el flujo de pedidos
GRANT INSERT, UPDATE ON pedidos        TO rol_app_escritura;
GRANT INSERT, UPDATE ON detalle_pedido TO rol_app_escritura;
GRANT INSERT, UPDATE ON pagos          TO rol_app_escritura;

-- E7. Acceso a sequences necesarios para INSERT con columnas SERIAL/BIGSERIAL
-- Nombres confirmados con pg_sequences en foodstore_u5_test
GRANT USAGE, SELECT ON SEQUENCE
  pedidos_id_pedido_seq,
  detalle_pedido_id_detalle_seq,
  pagos_id_pago_seq
TO rol_app_escritura;


-- =============================================================================
-- PASO F — Privilegios para rol_soporte
--
-- F1a: SELECT completo sobre tablas operativas (clientes, pedidos, detalle, pagos).
--      Soporte necesita estos datos para resolver incidencias de entrega y cobro.
-- F1b: SELECT sobre columnas específicas de empleados — dni EXCLUIDO.
--      El DNI es dato de identidad civil; no tiene función operativa en soporte.
-- F2:  UPDATE limitado a la columna 'estado' de pedidos (permiso de columna).
--      Soporte actualiza el estado pero no puede tocar montos ni datos del cliente.
-- =============================================================================

-- F1a. Tablas operativas sin restricción de columna
GRANT SELECT ON clientes       TO rol_soporte;
GRANT SELECT ON pedidos        TO rol_soporte;
GRANT SELECT ON detalle_pedido TO rol_soporte;
GRANT SELECT ON pagos          TO rol_soporte;

-- F1b. Empleados: permiso de columna — dni excluido deliberadamente
GRANT SELECT (
  id_empleado,
  id_sucursal,
  nombre,
  apellido,
  rol,
  fecha_contratacion,
  activo
) ON empleados TO rol_soporte;
-- COLUMNA EXCLUIDA INTENCIONALMENTE: dni
-- Justificación: documento de identidad civil de alta sensibilidad;
-- soporte puede identificar al repartidor por nombre y sucursal sin necesitar el DNI.

-- F2. Permiso de columna — solo el campo de estado del pedido
GRANT UPDATE (estado) ON pedidos TO rol_soporte;


-- =============================================================================
-- PASO G — Privilegios para rol_reportes
--
-- Solo lectura sobre vistas y la vista materializada de facturación.
-- No accede a tablas base ni a datos de clientes identificables.
-- =============================================================================

GRANT SELECT ON mv_facturacion_categoria_mes TO rol_reportes;
GRANT SELECT ON v_productos_vigentes         TO rol_reportes;
GRANT SELECT ON v_pedidos_cliente            TO rol_reportes;


-- =============================================================================
-- PASO H — Privilegios para rol_auditoria
--
-- La tabla auditoria_log se creará en la Parte B (02_auditoria_config.sql /
-- 03_auditoria_test.sql). Este GRANT debe ejecutarse DESPUÉS de que esa tabla
-- exista. Se deja comentado como recordatorio; incorporarlo al script de Parte B.
-- =============================================================================
-- GRANT SELECT ON auditoria_log TO rol_auditoria;
-- (descomentar y ejecutar después de CREATE TABLE auditoria_log en Parte B)


-- =============================================================================
-- PASO I — EXECUTE sobre fn_autenticar para rol_app_lectura
--
-- fn_autenticar es SECURITY DEFINER: corre con los privilegios del propietario.
-- El control del EXECUTE es la única barrera entre el invocador y los datos
-- de la tabla usuario. Por eso se restringe a rol_app_lectura y no a PUBLIC.
-- app_web hereda este privilegio a través de rol_app_lectura.
-- PUBLIC fue revocado en A3.
-- Firma confirmada: fn_autenticar(text, text)
GRANT EXECUTE ON FUNCTION fn_autenticar(text, text) TO rol_app_lectura;


-- =============================================================================
-- PASO J — ALTER DEFAULT PRIVILEGES
--
-- Define qué privilegios reciben automáticamente los roles sobre tablas que
-- postgres cree EN EL FUTURO en el schema public (después de este punto).
-- No afecta a tablas ya existentes. No afecta a tablas creadas por otros roles.
--
-- Decisiones:
--   J1: SELECT para roles de lectura (rol_app_lectura, rol_reportes).
--       Riesgo bajo: solo lectura sobre tablas futuras.
--
--   J2: OMITIDO — no se otorga INSERT+UPDATE automático a rol_app_escritura.
--       La escritura sobre tablas futuras se evalúa y otorga caso a caso.
--       Razón: una tabla de auditoría, configuración o administración no debería
--       ser escribible por la aplicación sin revisión previa.
--
--   J3: OMITIDO — no se otorga SELECT automático a rol_soporte.
--       Razón: rol_soporte tiene permisos de columna sobre empleados (sin dni).
--       Un SELECT automático sobre tablas futuras podría incluir tablas con datos
--       sensibles sin esa protección. Consistente con la filosofía de Pasos F1b.
--       Los permisos de soporte sobre tablas futuras se otorgan explícitamente.
-- =============================================================================

-- J1. SELECT para roles de lectura sobre tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO rol_app_lectura, rol_reportes;

-- J2. OMITIDO DELIBERADAMENTE — ver justificación arriba.
-- J3. OMITIDO DELIBERADAMENTE — ver justificación arriba.


-- =============================================================================
-- PASO L — Crear roles de login y otorgar membresías
--
-- L1–L3: app_web — aplicación web; hereda lectura y escritura.
-- L4–L8: admin_datos — DBA/analista; hereda todos los roles de grupo.
-- L9: GRANT EXECUTE sobre fn_resetear_password — después de CREATE ROLE admin_datos.
--
-- CONTRASEÑAS:
--   Los CREATE ROLE no incluyen PASSWORD. Establecer las contraseñas en una
--   sesión separada (no commiteada) con:
--
--     ALTER ROLE app_web    PASSWORD '<contraseña_generada_aleatoriamente>';
--     ALTER ROLE admin_datos PASSWORD '<contraseña_generada_aleatoriamente>';
--
--   Ver instrucciones completas en el encabezado de este script.
-- =============================================================================

-- L1–L3. Rol de login para la aplicación web
CREATE ROLE app_web
  LOGIN
  CONNECTION LIMIT 10;
-- Sin PASSWORD aquí — establecer con ALTER ROLE en sesión separada (ver encabezado)

GRANT rol_app_lectura   TO app_web;
GRANT rol_app_escritura TO app_web;
-- app_web NO es miembro de rol_soporte, rol_reportes ni admin_datos

-- L4–L8. Rol de login para el administrador de datos
CREATE ROLE admin_datos
  LOGIN
  CONNECTION LIMIT 5;
-- Sin PASSWORD aquí — establecer con ALTER ROLE en sesión separada (ver encabezado)

GRANT rol_app_lectura   TO admin_datos;
GRANT rol_app_escritura TO admin_datos;
GRANT rol_soporte        TO admin_datos;
GRANT rol_reportes       TO admin_datos;

-- =============================================================================
-- PASO K — Permiso de columna sobre la tabla sensible 'usuario'
--
-- Ubicado DESPUÉS de CREATE ROLE admin_datos (Paso L4): PostgreSQL requiere que
-- el rol grantee exista en el momento del GRANT.
--
-- admin_datos puede leer solo columnas operativas no sensibles + activo.
-- password_hash excluida en todos los casos y para todos los roles.
-- Ningún otro rol recibe acceso a usuario (ni por tabla completa ni por columna).
--
-- Columnas otorgadas y justificación:
--   id_usuario  — identificador interno; no es dato personal en sí mismo
--   email       — necesario para identificar y administrar cuentas
--   rol         — necesario para verificar el nivel de acceso de una cuenta
--   fecha_alta  — necesario para auditar la antigüedad de una cuenta
--   activo      — necesario para distinguir cuentas deshabilitadas de inexistentes
--
-- Columna excluida:
--   password_hash — hash de credencial; sin uso operativo para admin_datos
-- =============================================================================

GRANT SELECT (
  id_usuario,
  email,
  rol,
  fecha_alta,
  activo
) ON usuario TO admin_datos;

-- L9. EXECUTE sobre fn_resetear_password — aquí, después de CREATE ROLE admin_datos
-- Firma confirmada: fn_resetear_password(text, text)
-- fn_resetear_password es SECURITY DEFINER; solo admin_datos puede invocarla.
-- PUBLIC fue revocado en A4.
GRANT EXECUTE ON FUNCTION fn_resetear_password(text, text) TO admin_datos;


-- =============================================================================
-- VERIFICACIÓN POST-EJECUCIÓN
--
-- Ejecutar estas consultas inmediatamente después del script para confirmar
-- que el estado resultante coincide con la especificación.
-- Guardar la salida en:
--   evidencias/03_roles_permisos.txt
--   evidencias/04_verificacion_grants.txt
-- =============================================================================

-- VER 1. Permisos de columna
--        Para rol_soporte sobre empleados: dni NO debe aparecer.
--        Para admin_datos sobre usuario: password_hash NO debe aparecer.
SELECT
  grantee,
  table_name,
  column_name,
  privilege_type
FROM information_schema.role_column_grants
WHERE table_schema = 'public'
  AND grantee IN ('rol_soporte', 'admin_datos')
ORDER BY grantee, table_name, column_name;

-- VER 2. Permisos sobre tablas completas por rol
--        Verificar que rol_app_lectura no tenga acceso a tablas base,
--        y que ningún rol tenga privilegios sobre usuario (excepto columna K).
SELECT
  grantee,
  table_name,
  privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN (
    'rol_app_lectura', 'rol_app_escritura',
    'rol_soporte', 'rol_reportes',
    'rol_auditoria', 'admin_datos', 'app_web'
  )
ORDER BY grantee, table_name, privilege_type;

-- VER 3. Permisos sobre funciones de autenticación
--        fn_autenticar   → debe aparecer: rol_app_lectura
--        fn_resetear_... → debe aparecer: admin_datos
--        PUBLIC NO debe aparecer en ninguna de las dos funciones.
SELECT
  routine_name,
  grantee,
  privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public'
  AND routine_name IN ('fn_autenticar', 'fn_resetear_password')
ORDER BY routine_name, grantee;

-- VER 4. Membresías y atributos de los roles de login
--        (ejecutar en psql — el metacomando \du no funciona en DBeaver)
\du app_web
\du admin_datos
