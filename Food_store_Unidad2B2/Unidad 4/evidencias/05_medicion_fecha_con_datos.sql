\pset pager off
\pset footer off
SELECT current_database() AS base;

\echo '=== Consulta normalizada para 2026-11-10 (fecha con datos) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre AS categoria,
    SUM(dp.subtotal) AS total_vendido
FROM public.detalle_pedido AS dp
JOIN public.productos AS pr ON pr.id_producto = dp.id_producto
JOIN public.categorias AS c ON c.id_categoria = pr.id_categoria
JOIN public.pedidos AS ped ON ped.id_pedido = dp.id_pedido
WHERE ped.fecha_pedido >= DATE '2026-11-10'
  AND ped.fecha_pedido < DATE '2026-11-10' + INTERVAL '1 day'
GROUP BY c.nombre
ORDER BY total_vendido DESC, categoria ASC
LIMIT 5;

\echo '=== Consulta sobre el resumen para 2026-11-10 ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre AS categoria,
    SUM(v.total_vendido) AS total_vendido
FROM mayorista_u4.ventas_categoria_dia AS v
JOIN public.categorias AS c ON c.id_categoria = v.id_categoria
WHERE v.fecha_venta = DATE '2026-11-10'
GROUP BY c.nombre
ORDER BY total_vendido DESC, categoria ASC
LIMIT 5;

\echo '=== Top 5 real para 2026-11-10 (fuente) ==='
SELECT c.nombre AS categoria, SUM(dp.subtotal) AS total_vendido
FROM public.detalle_pedido AS dp
JOIN public.productos AS pr ON pr.id_producto = dp.id_producto
JOIN public.categorias AS c ON c.id_categoria = pr.id_categoria
JOIN public.pedidos AS ped ON ped.id_pedido = dp.id_pedido
WHERE ped.fecha_pedido >= DATE '2026-11-10'
  AND ped.fecha_pedido < DATE '2026-11-10' + INTERVAL '1 day'
GROUP BY c.nombre
ORDER BY total_vendido DESC, categoria ASC
LIMIT 5;

\echo '=== Diferencias top5 fuente vs resumen para 2026-11-10 ==='
WITH resultado_fuente AS (
    SELECT c.nombre AS categoria, SUM(dp.subtotal) AS total_vendido
    FROM public.detalle_pedido dp
    JOIN public.productos pr ON pr.id_producto = dp.id_producto
    JOIN public.categorias c ON c.id_categoria = pr.id_categoria
    JOIN public.pedidos ped ON ped.id_pedido = dp.id_pedido
    WHERE ped.fecha_pedido >= DATE '2026-11-10'
      AND ped.fecha_pedido < DATE '2026-11-10' + INTERVAL '1 day'
    GROUP BY c.nombre
    ORDER BY total_vendido DESC, categoria ASC
    LIMIT 5
), resultado_resumen AS (
    SELECT c.nombre AS categoria, SUM(v.total_vendido) AS total_vendido
    FROM mayorista_u4.ventas_categoria_dia v
    JOIN public.categorias c ON c.id_categoria = v.id_categoria
    WHERE v.fecha_venta = DATE '2026-11-10'
    GROUP BY c.nombre
    ORDER BY total_vendido DESC, categoria ASC
    LIMIT 5
)
SELECT count(*) AS diferencias FROM (
    (SELECT * FROM resultado_fuente EXCEPT SELECT * FROM resultado_resumen)
    UNION ALL
    (SELECT * FROM resultado_resumen EXCEPT SELECT * FROM resultado_fuente)
) d;
