-- Ejecutar cada EXPLAIN dos veces y anotar la segunda (caché caliente).

-- C1: pedidos entregados de un mes (hace 3 meses)
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, fecha_pedido, total FROM pedidos
WHERE fecha_pedido >= date_trunc('month', now()) - interval '3 months'
  AND fecha_pedido <  date_trunc('month', now()) - interval '2 months'
  AND estado = 'entregado' AND activo = TRUE;

-- C2: pedidos "en camino" de un repartidor
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, fecha_pedido, total FROM pedidos
WHERE id_empleado_repartidor = (SELECT id_empleado_repartidor FROM pedidos
                                WHERE id_empleado_repartidor IS NOT NULL LIMIT 1)
  AND estado = 'en_camino';

-- C3: pagos de un pedido
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM pagos WHERE id_pedido = 25000;

-- C4 (evidencia para el índice descartado): detalle de un pedido.
-- Ya usa uq_pedido_producto (id_pedido, id_producto): un índice nuevo en id_pedido sería redundante.
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM detalle_pedido WHERE id_pedido = 25000;
