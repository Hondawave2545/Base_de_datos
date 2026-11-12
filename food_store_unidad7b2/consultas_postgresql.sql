-- consultas_postgresql.sql - Unidad 7 Food Store (equivalentes b y c)
-- Base: foodstore_tp (SOLO LECTURA). Ejecutar con psql.

\echo '=== Base actual ==='
SELECT current_database();

\echo ''
\echo '=== b) Pedidos filtrados por estado entregado (equivalente Mongo b) ==='
SELECT p.id_pedido, p.estado, p.fecha_pedido, p.total
FROM pedidos p
WHERE p.estado = 'entregado'
  AND p.id_pedido IN (1,4,5,6,18)
ORDER BY p.id_pedido;

\echo ''
\echo '=== b-global referencia: conteo total entregado en subconjunto ==='
SELECT COUNT(*) AS cantidad, array_agg(id_pedido ORDER BY id_pedido) AS ids
FROM pedidos
WHERE estado = 'entregado' AND id_pedido IN (1,4,5,6,18);

\echo ''
\echo '=== c) Pedidos que contienen producto id_producto=8 (equivalente Mongo c) ==='
SELECT DISTINCT p.id_pedido, p.estado, p.total
FROM pedidos p
JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
WHERE dp.id_producto = 8
  AND p.id_pedido IN (1,4,5,6,18)
ORDER BY p.id_pedido;

\echo ''
\echo '=== c detalle: lineas con producto 8 en subconjunto ==='
SELECT dp.id_pedido, dp.id_detalle, dp.id_producto, dp.cantidad, dp.precio_unitario, dp.subtotal
FROM detalle_pedido dp
WHERE dp.id_producto = 8
  AND dp.id_pedido IN (1,4,5,6,18)
ORDER BY dp.id_pedido, dp.id_detalle;

\echo ''
\echo '=== c-global referencia: conteo e IDs con producto 8 en subconjunto ==='
SELECT COUNT(DISTINCT p.id_pedido) AS cantidad, array_agg(DISTINCT p.id_pedido ORDER BY p.id_pedido) AS ids
FROM pedidos p
JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
WHERE dp.id_producto = 8
  AND p.id_pedido IN (1,4,5,6,18);

\echo ''
\echo '=== Datos origen para validacion (solo IDs seleccionados) ==='
SELECT p.id_pedido, p.fecha_pedido, p.estado, p.total
FROM pedidos p
WHERE p.id_pedido IN (1,4,5,6,18)
ORDER BY p.id_pedido;

SELECT dp.id_pedido, dp.id_detalle, dp.id_producto, pr.nombre AS producto_nombre,
       dp.cantidad, dp.precio_unitario, dp.subtotal
FROM detalle_pedido dp
JOIN productos pr ON pr.id_producto = dp.id_producto
WHERE dp.id_pedido IN (1,4,5,6,18)
ORDER BY dp.id_pedido, dp.id_detalle;
