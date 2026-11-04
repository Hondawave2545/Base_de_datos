-- 0 filas en ambos sentidos = resultados idénticos. Repetir el patrón para cada vista.
-- v_productos_vigentes vs consulta manual
(SELECT * FROM v_productos_vigentes
 EXCEPT
 SELECT p.id_producto, p.nombre, p.descripcion, p.precio, p.stock, c.id_categoria, c.nombre
 FROM productos p JOIN categorias c ON c.id_categoria = p.id_categoria
 WHERE p.activo AND c.activo)
UNION ALL
(SELECT p.id_producto, p.nombre, p.descripcion, p.precio, p.stock, c.id_categoria, c.nombre
 FROM productos p JOIN categorias c ON c.id_categoria = p.id_categoria
 WHERE p.activo AND c.activo
 EXCEPT
 SELECT * FROM v_productos_vigentes);
