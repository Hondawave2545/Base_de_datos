
-- PARTE 1: Restricciones de Integridad restricciones.sql
-- Proyecto: Food Store

-- 1. Regla en producto: precio mayor a 0 y stock no negativo
ALTER TABLE producto 
ADD CONSTRAINT chk_producto_precio_positivo CHECK (precio_lista > 0),
ADD CONSTRAINT chk_producto_stock_no_negativo CHECK (stock >= 0);

-- 2. Regla en detalle_pedido: cantidad estrictamente mayor a 0
ALTER TABLE detalle_pedido 
ADD CONSTRAINT chk_detalle_cantidad_positiva CHECK (cantidad > 0);

-- 3. Regla en categoria: nombre no vacío ni solo espacios
ALTER TABLE categoria 
ADD CONSTRAINT chk_categoria_nombre_no_vacio CHECK (length(trim(nombre)) > 0);