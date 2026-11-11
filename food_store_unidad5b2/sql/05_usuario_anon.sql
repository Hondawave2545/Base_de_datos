-- =============================================================================
-- 05_usuario_anon.sql
-- Unidad 5 — Food Store — Parte D
-- Anonimización de la tabla usuario y verificación de equivalencia
--
-- Construye usuario_anon con datos sintéticos deterministas.
-- Verifica que los resultados agregados (por rol y mes de alta) sean idénticos
-- entre la tabla real y la anonimizada.
--
-- Prerrequisitos:
--   1. current_database() = 'foodstore_u5_test'
--   2. 00_crear_usuario_tabla.sql ejecutado (tabla usuario con datos de prueba)
--
-- Criterio de anonimización:
--   · email      → 'usuario_' || id_usuario || '@anon.local'  (determinista)
--   · password_hash → NO SE INCLUYE en ninguna columna
--   · rol        → se conserva (no es dato personal)
--   · fecha_alta → truncada al mes para agregación (mes_alta)
--   · activo     → se conserva (estado del sistema, no personal)
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
-- TABLA: usuario_anon
-- =============================================================================

DROP TABLE IF EXISTS public.usuario_anon;

CREATE TABLE public.usuario_anon AS
SELECT
  id_usuario,
  'usuario_' || id_usuario || '@anon.local'   AS email,
  rol,
  date_trunc('month', fecha_alta)::date        AS mes_alta,
  activo
FROM public.usuario;

COMMENT ON TABLE public.usuario_anon IS
  'Versión anonimizada de usuario. Sin datos identificables. Sin password_hash. '
  'Generada para Parte D — Unidad 5.';

-- Verificar que la tabla se creó correctamente
SELECT count(*) AS filas_anon FROM public.usuario_anon;

-- =============================================================================
-- CONSULTA A — sobre usuario_anon (versión anonimizada)
-- Cantidad de usuarios por rol y por mes de alta
-- (Esta consulta se puede compartir con la IA sin exponer datos reales)
-- =============================================================================

SELECT
  rol,
  mes_alta,
  count(*) AS cantidad
FROM public.usuario_anon
GROUP BY rol, mes_alta
ORDER BY mes_alta, rol;

-- =============================================================================
-- CONSULTA B — sobre usuario (tabla real)
-- Consulta equivalente — especificada a Kiro con el prompt:
-- "Dada esta consulta sobre usuario_anon, escribí la consulta equivalente
--  sobre la tabla real usuario."
-- (Ver BITACORA.md, interacción #8)
-- =============================================================================

SELECT
  rol,
  date_trunc('month', fecha_alta)::date AS mes_alta,
  count(*)                              AS cantidad
FROM public.usuario
GROUP BY rol, date_trunc('month', fecha_alta)::date
ORDER BY mes_alta, rol;

-- =============================================================================
-- VERIFICACIÓN DE EQUIVALENCIA
-- La diferencia simétrica debe ser 0 filas.
-- Resultado esperado: 0 filas — los agregados son idénticos.
-- =============================================================================

WITH
anon AS (
  SELECT rol, mes_alta, count(*) AS cantidad
  FROM public.usuario_anon
  GROUP BY rol, mes_alta
),
real_data AS (
  SELECT
    rol,
    date_trunc('month', fecha_alta)::date AS mes_alta,
    count(*) AS cantidad
  FROM public.usuario
  GROUP BY rol, date_trunc('month', fecha_alta)::date
)
SELECT 'anon − real' AS direccion, a.rol, a.mes_alta, a.cantidad
FROM anon a
WHERE NOT EXISTS (
  SELECT 1 FROM real_data r
  WHERE r.rol = a.rol AND r.mes_alta = a.mes_alta AND r.cantidad = a.cantidad
)
UNION ALL
SELECT 'real − anon', r.rol, r.mes_alta, r.cantidad
FROM real_data r
WHERE NOT EXISTS (
  SELECT 1 FROM anon a
  WHERE a.rol = r.rol AND a.mes_alta = r.mes_alta AND a.cantidad = r.cantidad
);

-- =============================================================================
-- RESULTADO ESPERADO DE LA VERIFICACIÓN
-- Ninguna fila: la tabla anonimizada produce los mismos agregados que la real.
-- Si aparecen filas, indica una discrepancia — revisar la lógica de anonimización.
-- =============================================================================

-- Mostrar lado a lado para evidencia
SELECT 'tabla_real' AS fuente, rol, date_trunc('month', fecha_alta)::date AS mes_alta, count(*) AS cantidad
FROM public.usuario GROUP BY rol, date_trunc('month', fecha_alta)::date
UNION ALL
SELECT 'usuario_anon', rol, mes_alta, count(*) FROM public.usuario_anon GROUP BY rol, mes_alta
ORDER BY mes_alta, rol, fuente;
