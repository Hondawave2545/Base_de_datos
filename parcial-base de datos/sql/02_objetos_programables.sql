-- 
-- TRABAJO PRÁCTICO INTEGRADOR: FOOD STORE
-- Archivo: 02_objetos_programables.sql
-- Motor de Referencia: PostgreSQL 16+
-- Objetivo: Vistas operativas, Funciones PL/pgSQL, Triggers y Procedimientos.


-- 1. VISTAS OPERATIVAS (Encapsulan el filtro por Soft Delete "activo = TRUE")

-- Vista 1: Catálogo de productos disponibles con sus categorías
CREATE OR REPLACE VIEW vw_productos_vigentes AS
SELECT 
    p.id_producto, 
    p.nombre AS producto, 
    p.precio, 
    p.stock, 
    c.nombre AS categoria
FROM productos p
JOIN categorias c ON c.id_categoria = p.id_categoria
WHERE p.activo = TRUE AND c.activo = TRUE;

-- Vista 2: Resumen ejecutivo de pedidos con datos de cliente y repartidor
CREATE OR REPLACE VIEW vw_resumen_pedidos AS
SELECT 
    p.id_pedido, 
    c.nombre || ' ' || c.apellido AS cliente, 
    p.fecha_pedido, 
    p.tipo_entrega,
    p.estado, 
    p.total, 
    COALESCE(e.nombre || ' ' || e.apellido, 'Sin repartidor asignado') AS repartidor
FROM pedidos p
JOIN clientes c ON c.id_cliente = p.id_cliente
LEFT JOIN empleados e ON e.id_empleado = p.id_empleado_repartidor
WHERE p.activo = TRUE;


-- 2. FUNCIÓN PL/pgSQL: Ticket promedio acumulado por cliente
CREATE OR REPLACE FUNCTION fn_ticket_promedio_cliente(p_id_cliente INT)
RETURNS NUMERIC AS $$
DECLARE
    v_promedio NUMERIC(10,2);
BEGIN
    SELECT COALESCE(AVG(total), 0.00) INTO v_promedio
    FROM pedidos
    WHERE id_cliente = p_id_cliente AND activo = TRUE;
    
    RETURN v_promedio;
END;
$$ LANGUAGE plpgsql STABLE;


-- 3. TRIGGER Y FUNCIÓN DISPARADORA: Recálculo automático del total del pedido
-- Mantiene la integridad del campo derivado 'total' cada vez que cambia el detalle
CREATE OR REPLACE FUNCTION fn_recalcular_total_pedido()
RETURNS TRIGGER AS $$
DECLARE
    v_id_pedido INT;
BEGIN
    -- Identifica si se borró, insertó o modificó un detalle
    IF (TG_OP = 'DELETE') THEN
        v_id_pedido := OLD.id_pedido;
    ELSE
        v_id_pedido := NEW.id_pedido;
    END IF;

    -- Actualiza el total sumando los subtotales vigentes del pedido
    UPDATE pedidos
    SET total = COALESCE((
        SELECT SUM(subtotal) 
        FROM detalle_pedido 
        WHERE id_pedido = v_id_pedido
    ), 0.00)
    WHERE id_pedido = v_id_pedido;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Asociación del disparador a la tabla detalle_pedido
DROP TRIGGER IF EXISTS trg_recalcular_total ON detalle_pedido;
CREATE TRIGGER trg_recalcular_total
AFTER INSERT OR UPDATE OR DELETE ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION fn_recalcular_total_pedido();


-- 4. PROCEDIMIENTO ALMACENADO (sp): Alta atómica e integral de un pedido
-- Valida stock, registra pedido, inserta línea de detalle y descuenta stock
CREATE OR REPLACE PROCEDURE sp_crear_pedido(
    p_id_cliente INT,
    p_id_sucursal INT,
    p_tipo_entrega tipo_entrega_enum,
    p_id_producto INT,
    p_cantidad INT,
    INOUT p_id_pedido_generado INT DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_precio NUMERIC(10,2);
    v_stock INT;
BEGIN
    -- 1. Validar existencia y stock suficiente del producto
    SELECT precio, stock INTO v_precio, v_stock
    FROM productos 
    WHERE id_producto = p_id_producto AND activo = TRUE;

    IF v_stock IS NULL OR v_stock < p_cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente (% disponible) o producto inexistente', COALESCE(v_stock, 0);
    END IF;

    -- 2. Crear cabecera del pedido
    INSERT INTO pedidos (id_cliente, id_sucursal, tipo_entrega)
    VALUES (p_id_cliente, p_id_sucursal, p_tipo_entrega)
    RETURNING id_pedido INTO p_id_pedido_generado;

    -- 3. Insertar detalle (esto dispara 'trg_recalcular_total' en la base)
    INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario, subtotal)
    VALUES (p_id_pedido_generado, p_id_producto, p_cantidad, v_precio, p_cantidad * v_precio);

    -- 4. Descontar el stock de la tabla de productos
    UPDATE productos
    SET stock = stock - p_cantidad
    WHERE id_producto = p_id_producto;
END;
$$;
