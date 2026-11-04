-- indices.sql — Parte A (solo índices ACEPTADOS)
-- Índices ya existentes (Semana 3): idx_pedidos_cliente, idx_pedidos_sucursal,
-- idx_detalle_pedido_producto, uq_pedido_producto (id_pedido, id_producto), entre otros.

-- 1) C1: pedidos de un período por estado. fecha_pedido primero (rango, alta selectividad),
--    estado después. Parcial: la consulta siempre filtra activo = TRUE.
CREATE INDEX idx_pedidos_fecha_estado
    ON pedidos (fecha_pedido, estado) WHERE activo = TRUE;

-- 2) C2: pedidos de un repartidor por estado. La FK id_empleado_repartidor no tenía índice.
CREATE INDEX idx_pedidos_repartidor_estado
    ON pedidos (id_empleado_repartidor, estado) WHERE id_empleado_repartidor IS NOT NULL;

-- 3) C3: pagos de un pedido. La FK pagos.id_pedido no tenía índice.
CREATE INDEX idx_pagos_pedido
    ON pagos (id_pedido);

-- DESCARTADOS (ver informe_mediciones.md y duia.md):
--   CREATE INDEX ON detalle_pedido (id_pedido);   -- redundante: uq_pedido_producto (id_pedido, id_producto) ya lo cubre
--   CREATE INDEX ON detalle_pedido (id_producto); -- redundante: ya existe idx_detalle_pedido_producto
--   CREATE INDEX ON pedidos (estado);             -- baja cardinalidad (5 valores), sin condición parcial
