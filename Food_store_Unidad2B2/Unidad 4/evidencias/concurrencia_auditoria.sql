\pset pager off
SELECT current_database() AS base;
SELECT id_detalle, id_pedido, id_producto, subtotal
FROM public.detalle_pedido WHERE id_detalle IN (150001,150002) ORDER BY id_detalle;

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
SELECT count(*) AS diferencias_post_concurrencia FROM (
    (SELECT * FROM fuente EXCEPT SELECT * FROM resumen)
    UNION ALL
    (SELECT * FROM resumen EXCEPT SELECT * FROM fuente)
) d;
