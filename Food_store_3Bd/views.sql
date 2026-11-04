-- views.sql — Partes B y C

-- B1) Productos vigentes con su categoría
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT p.id_producto, p.nombre, p.descripcion, p.precio, p.stock,
       c.id_categoria, c.nombre AS categoria
FROM productos p
JOIN categorias c ON c.id_categoria = p.id_categoria
WHERE p.activo = TRUE AND c.activo = TRUE;

-- B2) Pedidos con datos del cliente (sin telefono ni direccion_entrega)
CREATE OR REPLACE VIEW v_pedidos_cliente AS
SELECT pe.id_pedido, pe.fecha_pedido, pe.estado, pe.tipo_entrega, pe.total,
       cl.id_cliente, cl.nombre AS cliente_nombre, cl.apellido AS cliente_apellido, cl.email
FROM pedidos pe
JOIN clientes cl ON cl.id_cliente = pe.id_cliente
WHERE pe.activo = TRUE;

-- B3) Detalle de pedido con nombre del producto
CREATE OR REPLACE VIEW v_detalle_pedido AS
SELECT d.id_detalle, d.id_pedido, d.id_producto, pr.nombre AS producto,
       d.cantidad, d.precio_unitario, d.subtotal
FROM detalle_pedido d
JOIN productos pr ON pr.id_producto = d.id_producto;

-- B4) Seguridad: la tabla clientes no tiene contraseña; se ocultan telefono y direccion_entrega.
CREATE OR REPLACE VIEW v_clientes_publico AS
SELECT id_cliente, nombre, apellido, email, fecha_registro      -- sin telefono ni direccion_entrega
FROM clientes WHERE activo = TRUE;

-- Ejemplo: CREATE ROLE reportes; GRANT SELECT ON v_clientes_publico TO reportes_tp;

-- C) Vista materializada: facturación por categoría y mes
CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT c.id_categoria, c.nombre AS categoria,
       date_trunc('month', pe.fecha_pedido)::date AS mes,
       SUM(d.subtotal) AS facturacion
FROM pedidos pe
JOIN detalle_pedido d ON d.id_pedido = pe.id_pedido
JOIN productos pr     ON pr.id_producto = d.id_producto
JOIN categorias c     ON c.id_categoria = pr.id_categoria
WHERE pe.estado = 'entregado' AND pe.activo = TRUE
GROUP BY c.id_categoria, c.nombre, date_trunc('month', pe.fecha_pedido)
WITH DATA;

-- Índice único: requisito de REFRESH ... CONCURRENTLY
CREATE UNIQUE INDEX ux_mv_facturacion_categoria_mes
    ON mv_facturacion_categoria_mes (id_categoria, mes);

-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
