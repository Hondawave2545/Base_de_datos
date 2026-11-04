# spec: vistas
- v_productos_vigentes: producto + categoría; activo=TRUE en ambas tablas.
- v_pedidos_cliente: pedido + nombre/apellido/email del cliente; ocultar telefono y direccion_entrega; pedidos activos.
- v_detalle_pedido: detalle + nombre del producto.
- v_clientes_publico / v_empleados_publico: sin telefono, direccion_entrega ni dni (para GRANT SELECT).
Aceptación: EXCEPT en ambos sentidos contra la consulta manual = 0 filas.
