-- =============================================================================
-- 00_crear_usuario_tabla.sql
-- Unidad 5 — Food Store — Paso 0 (prerrequisito de Parte A)
-- Tabla usuario + fn_autenticar + fn_resetear_password
--
-- Propósito:
--   La consigna asume que la tabla 'usuario' y las funciones fn_autenticar /
--   fn_resetear_password ya existen de la Clase 1/2 de Unidad 5. Como no se
--   conservaron esos artefactos, se reconstruyen aquí como paso previo.
--   Reconstrucción documentada en BITACORA.md, sesión 2026-11-11.
--
-- Ejecutar SOLO en foodstore_u5_test, NUNCA en foodstore_tp.
-- Verificar antes: SELECT current_database(); → debe retornar 'foodstore_u5_test'
--
-- Firmas resultantes de este script (para usar en 01_roles.sql):
--   fn_autenticar(text, text)         → REVOKE/GRANT en pasos A3 e I1
--   fn_resetear_password(text, text)  → REVOKE/GRANT en pasos A4 y L9
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

-- =============================================================================
-- TABLA: usuario
-- Representa las cuentas de acceso a la aplicación Food Store.
-- No es la tabla de clientes (clientes ya existe en public con otros datos).
-- Contiene credenciales de los operadores de la aplicación.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.usuario (
  id_usuario    SERIAL       PRIMARY KEY,
  email         TEXT         NOT NULL UNIQUE,
  password_hash TEXT         NOT NULL,
  -- hash de la credencial; NUNCA texto plano.
  -- En producción usar pgcrypto.crypt() o bcrypt externo.
  -- En esta base de pruebas se usa una comparación directa (placeholder).
  rol           TEXT         NOT NULL
                  CHECK (rol IN ('app_web', 'admin_datos', 'soporte', 'reportes')),
  fecha_alta    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  activo        BOOLEAN      NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE public.usuario IS
  'Cuentas de acceso a la aplicación Food Store. No confundir con clientes.';
COMMENT ON COLUMN public.usuario.password_hash IS
  'Hash de la contraseña. Nunca almacenar texto plano.';
COMMENT ON COLUMN public.usuario.rol IS
  'Rol de aplicación: app_web, admin_datos, soporte, reportes.';

-- =============================================================================
-- FUNCIÓN: fn_autenticar(p_email text, p_password text) RETURNS boolean
--
-- Verifica credenciales. Retorna TRUE si el email existe, el usuario está
-- activo y el hash coincide. Retorna FALSE en CUALQUIER otro caso, sin
-- revelar cuál condición falló (evita enumeración de usuarios).
--
-- Es SECURITY DEFINER: corre con privilegios del propietario (postgres).
-- SET search_path = public evita ataques de sustitución de schema.
--
-- Firma: fn_autenticar(text, text)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_autenticar(
  p_email    text,
  p_password text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_hash   text;
  v_activo boolean;
BEGIN
  SELECT password_hash, activo
  INTO   v_hash, v_activo
  FROM   public.usuario
  WHERE  email = p_email;

  -- Si el usuario no existe, retornar FALSE sin revelar el motivo
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- Si la cuenta está desactivada, retornar FALSE sin revelar el motivo
  IF NOT v_activo THEN
    RETURN FALSE;
  END IF;

  -- Comparación de hash.
  -- NOTA: en producción reemplazar por comparación con pgcrypto:
  --   RETURN (v_hash = crypt(p_password, v_hash));
  -- Para esta base de pruebas se compara directamente (hashes de test).
  RETURN (v_hash = p_password);
END;
$$;

COMMENT ON FUNCTION public.fn_autenticar(text, text) IS
  'Verifica email y contraseña. Retorna TRUE si las credenciales son válidas '
  'y la cuenta está activa. SECURITY DEFINER.';

-- =============================================================================
-- FUNCIÓN: fn_resetear_password(p_email text, p_nueva_password text) RETURNS boolean
--
-- Permite a un administrador forzar el cambio de contraseña de una cuenta.
-- Solo debería ser invocable por roles con privilegio explícito (admin_datos).
-- Retorna TRUE si encontró y actualizó la cuenta, FALSE si no existe o inactiva.
--
-- Es SECURITY DEFINER: corre con privilegios del propietario (postgres).
--
-- Firma: fn_resetear_password(text, text)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_resetear_password(
  p_email          text,
  p_nueva_password text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.usuario
  SET    password_hash = p_nueva_password
         -- En producción: crypt(p_nueva_password, gen_salt('bf'))
  WHERE  email  = p_email
    AND  activo = TRUE;

  RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION public.fn_resetear_password(text, text) IS
  'Fuerza el cambio de contraseña de una cuenta activa. Solo admin_datos. '
  'SECURITY DEFINER.';

-- =============================================================================
-- DATOS DE PRUEBA
-- Cuatro cuentas para las Partes B, C y D.
-- Los password_hash son valores literales de prueba, no hashes reales.
-- No usar fuera de foodstore_u5_test.
-- =============================================================================

INSERT INTO public.usuario (email, password_hash, rol) VALUES
  ('app@foodstore.local',      'pw_app_web_test',    'app_web'),
  ('admin@foodstore.local',    'pw_admin_test',       'admin_datos'),
  ('soporte@foodstore.local',  'pw_soporte_test',     'soporte'),
  ('reportes@foodstore.local', 'pw_reportes_test',    'reportes')
ON CONFLICT (email) DO NOTHING;

-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================

SELECT current_database() AS base, current_user AS usuario_pg;

SELECT
  table_name,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'usuario'
ORDER BY ordinal_position;

SELECT
  proname   AS funcion,
  pg_get_function_arguments(oid) AS firma,
  prosecdef AS security_definer
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('fn_autenticar', 'fn_resetear_password');

SELECT id_usuario, email, rol, fecha_alta, activo FROM public.usuario;
