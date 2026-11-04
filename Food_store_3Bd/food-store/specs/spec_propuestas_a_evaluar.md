# spec: propuestas de índice a evaluar (se espera descartarlas)
Consulta: SELECT * FROM detalle_pedido WHERE id_pedido = :id;  y ranking por id_producto.
Pregunta para la IA: ¿hace falta un índice nuevo? Contexto: ya existen uq_pedido_producto (id_pedido, id_producto)
y idx_detalle_pedido_producto (id_producto).
Criterio: si el plan ya usa un índice existente, se descarta por redundancia.
