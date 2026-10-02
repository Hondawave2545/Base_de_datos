
-- TRABAJO PRÁCTICO INTEGRADOR: FOOD STORE
-- Archivo: 04_transacciones.sql
-- Motor de Referencia: PostgreSQL 16+
-- Objetivo: Demostración de control transaccional (ACID) e integridad de datos.


-- 0. DATOS SEMILLA PARA LA PRUEBA (Crea los registros mínimos si no existen)
INSERT INTO clientes (nombre, apellido, email, telefono)
VALUES ('Cliente', 'Prueba', 'cliente.prueba@foodstore.com', '1122334455')
ON CONFLICT (email) DO NOTHING;

INSERT INTO sucursales (nombre, direccion)
VALUES ('Sucursal Central', 'Av. Corrientes 1234')
ON CONFLICT DO NOTHING;

INSERT INTO categorias (nombre)
VALUES ('Hamburguesas')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO productos (id_categoria, nombre, precio, stock)
VALUES (1, 'Hamburguesa Doble', 4500.00, 50)
ON CONFLICT DO NOTHING;

-- Creamos el pedido id_pedido = 1 para que existan las claves foráneas
INSERT INTO pedidos (id_pedido, id_cliente, id_sucursal, tipo_entrega, total)
OVERRIDING SYSTEM VALUE
VALUES (1, 1, 1, 'retiro_local', 4500.00)
ON CONFLICT (id_pedido) DO NOTHING;

-- Sincronizar el contador/secuencia de id_pedido para evitar error de duplicate key
SELECT setval(pg_get_serial_sequence('pedidos', 'id_pedido'), COALESCE(MAX(id_pedido), 1)) FROM pedidos;


-- -----------------------------------------------------------------------------
-- ESCENARIO 1: Transacción Exitosa (Confirmación de Pago y Estado de Pedido)
-- Garantiza que el pago y el cambio de estado sean una operación atómica
-- -----------------------------------------------------------------------------
BEGIN;

-- 1. Registrar el pago aprobado
INSERT INTO pagos (id_pedido, metodo_pago, monto, estado)
VALUES (1, 'mercado_pago', 4500.00, 'aprobado');

-- 2. Actualizar el estado del pedido
UPDATE pedidos
SET estado = 'en_preparacion'
WHERE id_pedido = 1 AND activo = TRUE;

-- Confirmación permanente en la base de datos
COMMIT;


-- -----------------------------------------------------------------------------
-- ESCENARIO 2: Transacción Revertida (Rollback por Error)
-- Si el pago es rechazado, se abortan todos los cambios manteniendo la consistencia
-- -----------------------------------------------------------------------------
BEGIN;

-- 1. Intentar registrar un pago rechazado
INSERT INTO pagos (id_pedido, metodo_pago, monto, estado)
VALUES (1, 'tarjeta_credito', 4500.00, 'rechazado');

-- 2. Abortar la transacción completa
ROLLBACK;


-- -----------------------------------------------------------------------------
-- ESCENARIO 3: Control Transaccional en Procedimiento Almacenado
-- Ejecución atómica que crea un pedido nuevo, inserta detalle y descuenta stock
-- -----------------------------------------------------------------------------
CALL sp_crear_pedido(
    p_id_cliente => 1,
    p_id_sucursal => 1,
    p_tipo_entrega => 'delivery',
    p_id_producto => 1,
    p_cantidad => 2
);
