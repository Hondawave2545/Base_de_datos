-- Datos base para foodstore_tp (NUNCA en postgres). Ejecutar UNA sola vez, como script completo (Alt+X).
-- Supone que los id_* se autogeneran (serial/identity). Si una restricción falla, copiá el error.

INSERT INTO categorias (nombre, descripcion, activo) VALUES
 ('Pizzas',        'Pizzas al horno de piedra', TRUE),
 ('Hamburguesas',  'Hamburguesas artesanales',  TRUE),
 ('Bebidas',       'Gaseosas, jugos y agua',    TRUE),
 ('Postres',       'Postres y helados',         TRUE),
 ('Ensaladas',     'Ensaladas frescas',         TRUE);

INSERT INTO sucursales (nombre, direccion, telefono, activo) VALUES
 ('Sucursal Centro',  'San Martín 100, Mendoza',  '261-4000001', TRUE),
 ('Sucursal Godoy Cruz', 'Perón 500, Godoy Cruz', '261-4000002', TRUE),
 ('Sucursal Guaymallén', 'Mitre 900, Guaymallén', '261-4000003', TRUE);

-- 12 empleados: 3 gerentes/cajeros y el resto repartidores
INSERT INTO empleados (id_sucursal, nombre, apellido, dni, rol, fecha_contratacion, activo)
SELECT (SELECT id_sucursal FROM sucursales ORDER BY id_sucursal OFFSET (g % 3) LIMIT 1),
       'Empleado' || g, 'Apellido' || g,
       (30000000 + g)::text,
       (CASE WHEN g % 6 = 1 THEN 'gerente' WHEN g % 6 = 2 THEN 'cajero' ELSE 'repartidor' END)::rol_empleado_enum,
       DATE '2023-01-01' + (g * 20),
       TRUE
FROM generate_series(1, 12) g;

-- 2.000 clientes
INSERT INTO clientes (nombre, apellido, email, telefono, direccion_entrega, fecha_registro, activo)
SELECT 'Cliente' || g, 'Apellido' || g,
       'cliente' || g || '@mail.com',
       '261-5' || lpad(g::text, 6, '0'),
       'Calle ' || g || ', Mendoza',
       now() - ((g % 700) || ' days')::interval,
       (g % 25 <> 0)
FROM generate_series(1, 2000) g;

-- 40 productos repartidos en las 5 categorías
INSERT INTO productos (id_categoria, nombre, descripcion, precio, stock, activo)
SELECT (SELECT id_categoria FROM categorias ORDER BY id_categoria OFFSET (g % 5) LIMIT 1),
       'Producto ' || g, 'Descripción del producto ' || g,
       (500 + random() * 4500)::numeric(10,2),
       10 + (random() * 190)::int,
       (g % 15 <> 0)
FROM generate_series(1, 40) g;

ANALYZE;
SELECT (SELECT count(*) FROM clientes) clientes, (SELECT count(*) FROM productos) productos,
       (SELECT count(*) FROM sucursales) sucursales,
       (SELECT count(*) FROM empleados WHERE rol='repartidor') repartidores;
