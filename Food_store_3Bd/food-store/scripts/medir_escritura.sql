-- Costo en escritura. Correr ANTES y DESPUÉS de indices.sql. Cada bloque se ejecuta como script (Alt+X).
-- Siempre termina en ROLLBACK: no deja datos.

-- E1: 500 INSERT en pedidos (tabla donde SÍ agregamos índices)
BEGIN;
EXPLAIN ANALYZE
INSERT INTO pedidos (id_cliente, id_sucursal, id_empleado_repartidor, fecha_pedido,
                     estado, tipo_entrega, total, datos_envio, activo)
SELECT (SELECT min(id_cliente) FROM clientes), (SELECT min(id_sucursal) FROM sucursales),
       NULL, now(), 'pendiente', 'retiro_local', 100, '{}'::jsonb, TRUE
FROM generate_series(1, 500);
ROLLBACK;

-- E2: 500 INSERT en pagos (índice nuevo en id_pedido)
BEGIN;
EXPLAIN ANALYZE
INSERT INTO pagos (id_pedido, metodo_pago, monto, fecha_pago, estado)
SELECT (SELECT min(id_pedido) FROM pedidos), 'efectivo', 100, now(), 'pendiente'
FROM generate_series(1, 500);
ROLLBACK;

-- E3 (control): 500 INSERT en detalle_pedido. No agregamos índices ahí, no debería cambiar.
BEGIN;
EXPLAIN ANALYZE
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario, subtotal)
SELECT p.id_pedido, pr.id_producto, 1, pr.precio, pr.precio
FROM (SELECT id_pedido FROM pedidos ORDER BY id_pedido LIMIT 500) p
JOIN (SELECT id_producto, precio, row_number() OVER (ORDER BY id_producto) rn,
             count(*) OVER () n FROM productos) pr
  ON pr.rn = 1 + ((p.id_pedido + 4) % pr.n);
ROLLBACK;
