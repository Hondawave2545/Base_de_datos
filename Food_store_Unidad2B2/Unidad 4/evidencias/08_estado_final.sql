\pset pager off
\pset footer off
SELECT current_database() AS base, current_user AS usuario, now() AS momento;
SELECT (SELECT count(*) FROM public.pedidos) AS pedidos,
       (SELECT count(*) FROM public.detalle_pedido) AS detalles,
       (SELECT count(*) FROM public.productos) AS productos,
       (SELECT count(*) FROM public.categorias) AS categorias,
       (SELECT count(*) FROM mayorista_u4.ventas_categoria_dia) AS filas_resumen,
       (SELECT count(*) FROM pg_trigger WHERE tgname LIKE 'trg_ventas_categoria_dia%') AS triggers_u4;
SELECT count(*) AS filas_de_prueba_restantes
FROM public.detalle_pedido WHERE id_detalle IN (150001,150002);

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
SELECT count(*) AS diferencias_fuente_resumen FROM (
    (SELECT * FROM fuente EXCEPT SELECT * FROM resumen)
    UNION ALL
    (SELECT * FROM resumen EXCEPT SELECT * FROM fuente)
) d;

SELECT c.nombre AS categoria, SUM(dp.subtotal) AS total_vendido
FROM public.detalle_pedido dp
JOIN public.productos pr ON pr.id_producto=dp.id_producto
JOIN public.categorias c ON c.id_categoria=pr.id_categoria
JOIN public.pedidos ped ON ped.id_pedido=dp.id_pedido
WHERE ped.fecha_pedido >= DATE '2026-11-10'
  AND ped.fecha_pedido < DATE '2026-11-10' + INTERVAL '1 day'
GROUP BY c.nombre ORDER BY total_vendido DESC, categoria ASC LIMIT 5;

SELECT conrelid::regclass AS tabla, conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE connamespace='mayorista_u4'::regnamespace AND contype IN ('p','f','t')
ORDER BY conrelid::regclass::text, conname;
