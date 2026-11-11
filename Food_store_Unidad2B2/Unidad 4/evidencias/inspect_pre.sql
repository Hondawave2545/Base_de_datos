\pset pager off
\pset footer off
SELECT current_database() AS base, current_user AS usuario, version() AS version, current_setting('TimeZone') AS zona;

\echo '--- columnas public.pedidos ---'
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='pedidos'
ORDER BY ordinal_position;

\echo '--- columnas public.detalle_pedido ---'
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='detalle_pedido'
ORDER BY ordinal_position;

\echo '--- columnas public.productos ---'
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='productos'
ORDER BY ordinal_position;

\echo '--- columnas public.categorias ---'
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='categorias'
ORDER BY ordinal_position;

\echo '--- columnas con nombre eliminado/activo/vigente en public ---'
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema='public'
  AND (column_name ILIKE '%eliminad%' OR column_name ILIKE '%activo%' OR column_name ILIKE '%vigente%')
ORDER BY table_name, column_name;

\echo '--- distribucion pedidos.activo ---'
SELECT activo, count(*) FROM public.pedidos GROUP BY activo ORDER BY activo;

\echo '--- rango de fechas y pedidos de hoy ---'
SELECT min(fecha_pedido) AS min_fecha, max(fecha_pedido) AS max_fecha,
       count(*) FILTER (WHERE fecha_pedido >= CURRENT_DATE AND fecha_pedido < CURRENT_DATE + INTERVAL '1 day') AS pedidos_hoy,
       CURRENT_DATE AS fecha_sesion
FROM public.pedidos;

\echo '--- conteos de fixture ---'
SELECT (SELECT count(*) FROM public.pedidos) AS pedidos,
       (SELECT count(*) FROM public.detalle_pedido) AS detalles,
       (SELECT count(*) FROM public.productos) AS productos,
       (SELECT count(*) FROM public.categorias) AS categorias;

\echo '--- triggers U4 en public ---'
SELECT c.relname AS tabla, t.tgname AS trigger, pg_get_triggerdef(t.oid) AS definicion
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND NOT t.tgisinternal AND t.tgname LIKE 'trg_ventas_categoria_dia%'
ORDER BY c.relname, t.tgname;

\echo '--- funciones en mayorista_u4 ---'
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mayorista_u4' ORDER BY p.proname;

\echo '--- constraints en mayorista_u4 ---'
SELECT conrelid::regclass AS tabla, conname, contype, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE connamespace='mayorista_u4'::regnamespace
ORDER BY conrelid::regclass::text, conname;

\echo '--- diferencias resumen vs fuente (debe ser 0) ---'
WITH fuente AS (
    SELECT ped.fecha_pedido::date AS fecha_venta, c.id_categoria, SUM(dp.subtotal) AS total_vendido
    FROM public.detalle_pedido dp
    JOIN public.productos pr ON pr.id_producto=dp.id_producto
    JOIN public.categorias c ON c.id_categoria=pr.id_categoria
    JOIN public.pedidos ped ON ped.id_pedido=dp.id_pedido
    GROUP BY ped.fecha_pedido::date, c.id_categoria
), resumen AS (
    SELECT fecha_venta, id_categoria, total_vendido FROM mayorista_u4.ventas_categoria_dia
)
SELECT count(*) AS diferencias FROM (
    (SELECT * FROM fuente EXCEPT SELECT * FROM resumen)
    UNION ALL
    (SELECT * FROM resumen EXCEPT SELECT * FROM fuente)
) d;

\echo '--- top 5 de hoy (fuente) ---'
SELECT c.nombre AS categoria, SUM(dp.subtotal) AS total_vendido
FROM public.detalle_pedido dp
JOIN public.productos pr ON pr.id_producto=dp.id_producto
JOIN public.categorias c ON c.id_categoria=pr.id_categoria
JOIN public.pedidos ped ON ped.id_pedido=dp.id_pedido
WHERE ped.fecha_pedido >= CURRENT_DATE AND ped.fecha_pedido < CURRENT_DATE + INTERVAL '1 day'
GROUP BY c.nombre ORDER BY total_vendido DESC, categoria ASC LIMIT 5;

\echo '--- filas del resumen ---'
SELECT * FROM mayorista_u4.ventas_categoria_dia ORDER BY fecha_venta, id_categoria;
