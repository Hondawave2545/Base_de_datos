# Declaración de Uso de IA (DUIA)

> COMPLETAR/CORREGIR por el estudiante: este registro debe reflejar lo que realmente hizo.
> Si usó Kiro y OpenCode, agregar sus interacciones (spec entregado y propuesta recibida).
> Si no los usó, indicarlo con honestidad.

## Interacción 1 — Plan de indexado
- **Herramienta / propósito:** Claude (asistente de IA en chat), para generar scripts y proponer índices.
- **Prompt / spec entregado:** el enunciado del TP, las columnas de las tablas (`information_schema.columns`), los índices existentes (`pg_indexes`) y los valores de los enums. Los specs están en `specs/`.
- **Qué propuso la IA:** cinco índices: `pedidos(fecha_pedido, estado)` parcial, `pedidos(id_empleado_repartidor, estado)` parcial, `pagos(id_pedido)`, `detalle_pedido(id_pedido)` y `detalle_pedido(id_producto)`.
- **Aceptado:** los tres primeros, validados con EXPLAIN ANALYZE antes y después (8,3x, 19x y 58x más rápido).
- **Descartado:** `detalle_pedido(id_pedido)` y `detalle_pedido(id_producto)`, por redundantes con `uq_pedido_producto` e `idx_detalle_pedido_producto`. Evidencia: el plan de C4 ya usa `uq_pedido_producto` (0,117 ms). También se descartó `pedidos(estado)` por baja cardinalidad.
- **Justificación técnica:** ver `informe_mediciones.md`, sección "Índices descartados por sobreindexación".

## Interacción 2 — Vistas
- **Herramienta / propósito:** Claude, para generar las vistas a partir de la especificación en `specs/spec_vistas.md`.
- **Qué propuso la IA:** `v_productos_vigentes`, `v_pedidos_cliente`, `v_detalle_pedido`, `v_clientes_publico` (y una `v_empleados_publico`).
- **Aceptado / modificado:** se aceptaron las cuatro primeras. Se quitó `v_empleados_publico` por no haberse verificado. Como `clientes` no tiene columna de contraseña, la vista de seguridad oculta `telefono` y `direccion_entrega`.
- **Verificación de equivalencia (obligatoria):** cada vista se comparó con una consulta manual mediante `EXCEPT` en ambos sentidos (0 filas) y se comprobó el conteo de filas. Detalle en `informe_mediciones.md`, Parte B.

## Interacción 3 — Vista materializada
- **Herramienta / propósito:** Claude, para generar la vista y las pruebas de medición.
- **Qué propuso la IA:** `mv_facturacion_categoria_mes` con índice único `(id_categoria, mes)`.
- **Aceptado:** sin cambios. Medido: 184,143 ms contra 0,058 ms; `REFRESH CONCURRENTLY` probado.
- **Frecuencia de refresco:** una vez por día, justificada en el informe.

## Medición del costo de escritura
- La IA propuso medir 500 INSERT en transacción con ROLLBACK. Al ver que los tiempos variaban mucho entre ejecuciones, se tomó la mediana de 3 ejecuciones y se usó la cantidad de páginas leídas como indicador estable, con `detalle_pedido` como control.