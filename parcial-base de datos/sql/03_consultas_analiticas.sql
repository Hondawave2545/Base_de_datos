
-- TRABAJO PRÁCTICO INTEGRADOR: FOOD STORE
-- Archivo: 03_consultas_analiticas.sql
-- Motor de Referencia: PostgreSQL 16+
-- Objetivo: Consultas analíticas con JOINs, Agregaciones, Subconsultas y Ventanas.


-- Consulta 1: Total gastado, cantidad de pedidos y ticket promedio por cliente
-- Combina clientes y pedidos respetando la relación 1:N
SELECT 
    c.id_cliente,
    c.nombre,
    c.apellido,
    COUNT(p.id_pedido) AS cantidad_pedidos,
    SUM(p.total) AS monto_total_gastado,
    ROUND(AVG(p.total), 2) AS ticket_promedio
FROM clientes c
JOIN pedidos p ON p.id_cliente = c.id_cliente
WHERE p.activo = TRUE
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY monto_total_gastado DESC;


-- Consulta 2: Productos más vendidos y sus ingresos (GROUP BY + HAVING)
-- Filtra sobre los grupos consolidados para obtener solo productos con más de 1 unidad vendida
SELECT 
    pr.id_producto,
    pr.nombre AS producto,
    cat.nombre AS categoria,
    SUM(dp.cantidad) AS unidades_vendidas,
    SUM(dp.subtotal) AS ingresos_generados
FROM productos pr
JOIN categorias cat ON cat.id_categoria = pr.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = pr.id_producto
GROUP BY pr.id_producto, pr.nombre, cat.nombre
HAVING SUM(dp.cantidad) > 1
ORDER BY unidades_vendidas DESC;


-- Consulta 3: Clientes cuyo gasto total supera el promedio general (Subconsulta)
-- La subconsulta calcula el promedio global dinámicamente y la consulta externa lo usa de umbral
SELECT 
    c.id_cliente,
    c.nombre,
    c.apellido,
    SUM(p.total) AS gasto_total
FROM clientes c
JOIN pedidos p ON p.id_cliente = c.id_cliente
WHERE p.activo = TRUE
GROUP BY c.id_cliente, c.nombre, c.apellido
HAVING SUM(p.total) > (
    SELECT AVG(total) 
    FROM pedidos 
    WHERE activo = TRUE
)
ORDER BY gasto_total DESC;


-- Consulta 4: Ranking de pedidos e historial por cliente (Funciones de Ventana)
-- Muestra el detalle individual sin colapsar filas gracias a OVER(PARTITION BY / ORDER BY)
SELECT 
    c.nombre,
    c.apellido,
    p.id_pedido,
    p.fecha_pedido,
    p.total,
    SUM(p.total) OVER (PARTITION BY c.id_cliente) AS gasto_total_acumulado_cliente,
    DENSE_RANK() OVER (ORDER BY p.total DESC) AS ranking_monto_pedido,
    ROW_NUMBER() OVER (PARTITION BY c.id_cliente ORDER BY p.fecha_pedido) AS nro_pedido_del_cliente
FROM clientes c
JOIN pedidos p ON p.id_cliente = c.id_cliente
WHERE p.activo = TRUE
ORDER BY c.apellido, p.fecha_pedido;
