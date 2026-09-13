-- PARTE 1: Restricciones de Integridad
-- Proyecto: Food Store
-- Reglas de negocio NO garantizadas previamente por el motor (ver schema.sql del TP1)

-- 1. Regla en producto: el precio debe ser ESTRICTAMENTE mayor a 0
--    (el schema original solo exigía >= 0, permitiendo productos gratis por error)
ALTER TABLE producto 
DROP CONSTRAINT chk_producto_precio, -- se reemplaza la regla >=0 por la nueva >0
ADD CONSTRAINT chk_producto_precio_estrictamente_positivo CHECK (precio_lista > 0);

-- 2. Regla en categoria: nombre no vacío ni compuesto solo por espacios
ALTER TABLE categoria 
ADD CONSTRAINT chk_categoria_nombre_no_vacio CHECK (length(trim(nombre)) > 0);

-- 3. Regla en pedido: la fecha del pedido no puede ser futura
ALTER TABLE pedido 
ADD CONSTRAINT chk_pedido_fecha_no_futura CHECK (fecha_hora <= CURRENT_TIMESTAMP);