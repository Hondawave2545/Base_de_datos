# Informe de mediciones — Unidad 3, Food Store

Base de pruebas: `foodstore_tp` (copia de `postgres`), PostgreSQL. Volumen: 50.000 pedidos, 150.000 detalles, 50.000 pagos, 2.000 clientes, 40 productos. Todas las pruebas se hicieron sobre la copia; las de escritura dentro de una transacción con ROLLBACK. En las lecturas se anotó la segunda ejecución (caché caliente).

Índices que ya existían (Semana 3): `idx_pedidos_cliente`, `idx_pedidos_sucursal`, `idx_detalle_pedido_producto`, `uq_pedido_producto (id_pedido, id_producto)`, `idx_productos_categoria`, entre otros.

---

## Parte A — Índices

### C1: pedidos entregados de un mes
```sql
SELECT id_pedido, fecha_pedido, total FROM pedidos
WHERE fecha_pedido >= date_trunc('month', now()) - interval '3 months'
  AND fecha_pedido <  date_trunc('month', now()) - interval '2 months'
  AND estado = 'entregado' AND activo = TRUE;
```
**Antes:**
```
Seq Scan on pedidos  (cost=0.00..2990.00 rows=1274 width=20) (actual time=0.679..15.001 rows=1255.00 loops=1)
  Rows Removed by Filter: 48745
  Buffers: shared hit=1365
Execution Time: 15.095 ms
```
**Índice:** `idx_pedidos_fecha_estado ON pedidos (fecha_pedido, estado) WHERE activo = TRUE`

**Después:**
```
Bitmap Heap Scan on pedidos  (cost=63.36..1500.66 rows=1274 width=20) (actual time=0.609..1.624 rows=1255.00 loops=1)
  Heap Blocks: exact=578
  Buffers: shared hit=588
  ->  Bitmap Index Scan on idx_pedidos_fecha_estado  (actual time=0.410..0.411 rows=1255.00 loops=1)
Execution Time: 1.809 ms
```
**Lectura:** antes, PostgreSQL recorría las 50.000 filas (Seq Scan) y descartaba 48.745 para quedarse con 1.255. Con el índice, el Bitmap Index Scan encuentra las 1.255 filas que cumplen fecha y estado y solo se leen las páginas de la tabla que las contienen. El tiempo bajó de 15,095 ms a 1,809 ms (unas 8,3 veces menos) y las páginas leídas de 1.365 a 588. La mejora es casi de un orden de magnitud, no llega a 10x porque la consulta devuelve unas 1.255 filas (2,5 % de la tabla). Se usa Bitmap y no Index Scan simple porque las filas coincidentes están repartidas por toda la tabla. El índice es parcial (`activo = TRUE`) porque la consulta siempre excluye registros inactivos, y `fecha_pedido` va primero por ser la columna de rango y más selectiva.

### C2: pedidos en camino de un repartidor
```sql
SELECT id_pedido, fecha_pedido, total FROM pedidos
WHERE id_empleado_repartidor = (SELECT id_empleado_repartidor FROM pedidos
                                WHERE id_empleado_repartidor IS NOT NULL LIMIT 1)
  AND estado = 'en_camino';
```
**Antes:**
```
Seq Scan on pedidos  (cost=0.06..2115.06 rows=428 width=20) (actual time=1.067..11.703 rows=379.00 loops=1)
  Rows Removed by Filter: 49621
  Buffers: shared hit=2049
Execution Time: 11.806 ms
```
**Índice:** `idx_pedidos_repartidor_estado ON pedidos (id_empleado_repartidor, estado) WHERE id_empleado_repartidor IS NOT NULL`

**Después:**
```
Bitmap Heap Scan on pedidos  (cost=8.71..915.54 rows=426 width=20) (actual time=0.345..0.579 rows=379.00 loops=1)
  Heap Blocks: exact=286
  Buffers: shared hit=972
  ->  Bitmap Index Scan on idx_pedidos_repartidor_estado  (actual time=0.301..0.301 rows=379.00 loops=1)
Execution Time: 0.621 ms
```
**Lectura:** `id_empleado_repartidor` es una clave foránea que no tenía índice. Antes se recorrían las 50.000 filas para quedarse con 379. Con el índice compuesto, el Bitmap Index Scan llega directo a esas 379 filas y se leen solo 286 páginas. El tiempo bajó de 11,806 ms a 0,621 ms (unas 19 veces menos), superando el orden de magnitud. El Seq Scan que aún aparece dentro de `InitPlan 1` es la subconsulta que elige al repartidor (con LIMIT 1), no la consulta medida.

### C3: pagos de un pedido
```sql
SELECT * FROM pagos WHERE id_pedido = 25000;
```
**Antes:**
```
Seq Scan on pagos  (cost=0.00..1042.00 rows=1 width=32) (actual time=4.860..6.166 rows=1.00 loops=1)
  Rows Removed by Filter: 49999
  Buffers: shared hit=417
Execution Time: 6.199 ms
```
**Índice:** `idx_pagos_pedido ON pagos (id_pedido)`

**Después:**
```
Index Scan using idx_pagos_pedido on pagos  (cost=0.29..8.31 rows=1 width=32) (actual time=0.059..0.061 rows=1.00 loops=1)
  Index Cond: (id_pedido = 25000)
  Buffers: shared hit=3
Execution Time: 0.106 ms
```
**Lectura:** `pagos.id_pedido` es una clave foránea sin índice. Antes se recorrían las 50.000 filas (417 páginas) para devolver una. Con `idx_pagos_pedido` el plan pasó a Index Scan: va directo a la fila y lee 3 páginas. De 6,199 ms a 0,106 ms (unas 58 veces menos).

### Costo en escritura (500 INSERT en transacción con ROLLBACK)
| Tabla | Antes | Después | Diferencia |
|---|---|---|---|
| pedidos | 10,247 ms (4.023 páginas) | 11,655 ms (≈5.023 páginas) | +14 % en tiempo, +25 % en páginas |
| pagos | 8,578 ms (2.013 páginas) | 14,754 ms (≈3.014 páginas) | tiempo no concluyente, +50 % en páginas |
| detalle_pedido (control, sin índices nuevos) | 27,866 ms (4.520 páginas) | 40,647 ms (≈4.514 páginas) | tiempo no concluyente, 0 % en páginas |

**Notas:**
- `pedidos`: el "después" es la mediana de 3 ejecuciones estables (12,031 / 8,615 / 11,655 ms). Se descartaron una ejecución de 55,895 ms (Planning Time de 14 ms contra 0,3 ms habitual) y la primera tras crear los índices (36,513 ms, caché fría). En esta prueba solo se mantiene `idx_pedidos_fecha_estado`, porque las filas insertadas tienen `id_empleado_repartidor` nulo y no entran en el índice parcial `idx_pedidos_repartidor_estado`.
- `pagos`: mediana de 3 ejecuciones (18,109 / 14,754 / 7,800 ms). La dispersión es del mismo orden que la diferencia con el "antes" (una sola medición).
- `detalle_pedido`: mediana de 3 ejecuciones (67,154 / 40,647 / 11,582 ms). El tiempo varía de 11 a 67 ms en una tabla donde no se creó ningún índice, lo que muestra el ruido propio de la medición.

**Conclusión:** los tiempos de INSERT varían demasiado entre ejecuciones para atribuir una diferencia precisa a los índices. El indicador estable es la cantidad de páginas leídas por cada 500 INSERT: +25 % en `pedidos`, +50 % en `pagos` y sin cambios en `detalle_pedido`, donde no se agregó ningún índice. Los índices aceleran las lecturas entre 8 y 58 veces a cambio de un costo moderado y medible en cada escritura. Esto también justifica descartar los índices redundantes: cada uno sumaría ese costo sin mejorar ninguna lectura.

### Índices descartados por sobreindexación
**1. `detalle_pedido (id_pedido)`: redundante.** Ya existe `uq_pedido_producto` sobre `(id_pedido, id_producto)`; un índice compuesto sirve para buscar por su primera columna. Evidencia (consulta C4, sin crear ningún índice nuevo):
```
Index Scan using uq_pedido_producto on detalle_pedido  (cost=0.42..11.97 rows=3 width=30) (actual time=0.035..0.037 rows=3.00 loops=1)
  Index Cond: (id_pedido = 25000)
  Buffers: shared hit=4
Execution Time: 0.117 ms
```
Un índice nuevo no mejoraría este plan y encarecería cada INSERT sobre `detalle_pedido`.

**2. `detalle_pedido (id_producto)`: redundante.** Ya existe `idx_detalle_pedido_producto` sobre esa columna (figura en `pg_indexes`).

**3. `pedidos (estado)`: baja cardinalidad.** `estado` tiene solo 5 valores y no hay condición parcial que lo vuelva selectivo. Un valor como `entregado` abarca alrededor del 60 % de las filas, por lo que el planner preferiría Seq Scan. Solo sumaría costo de mantenimiento en cada INSERT y UPDATE de `pedidos`.

---

## Parte B — Vistas

### Equivalencia contra consulta manual
Para cada vista se ejecutó `(vista EXCEPT consulta_manual) UNION ALL (consulta_manual EXCEPT vista)`; 0 filas significa resultados idénticos.

| Vista | Consulta manual | Resultado |
|---|---|---|
| v_productos_vigentes | `SELECT p.id_producto, p.nombre, p.descripcion, p.precio, p.stock, c.id_categoria, c.nombre FROM productos p JOIN categorias c ON c.id_categoria = p.id_categoria WHERE p.activo AND c.activo` | 0 filas en ambos sentidos; 38 filas (40 productos − 2 inactivos) |
| v_pedidos_cliente | `SELECT pe.id_pedido, pe.fecha_pedido, pe.estado, pe.tipo_entrega, pe.total, cl.id_cliente, cl.nombre, cl.apellido, cl.email FROM pedidos pe JOIN clientes cl ON cl.id_cliente = pe.id_cliente WHERE pe.activo` | 0 filas en ambos sentidos; 47.537 filas (50.000 − 2.463 inactivos) |
| v_detalle_pedido | `SELECT d.id_detalle, d.id_pedido, d.id_producto, pr.nombre, d.cantidad, d.precio_unitario, d.subtotal FROM detalle_pedido d JOIN productos pr ON pr.id_producto = d.id_producto` | 0 filas en ambos sentidos; 150.000 filas |
| v_clientes_publico | `SELECT id_cliente, nombre, apellido, email, fecha_registro FROM clientes WHERE activo` | 0 filas en ambos sentidos; 1.920 filas (2.000 − 80 inactivos) |

### Prueba de seguridad de `v_clientes_publico`
La tabla `clientes` no tiene columna de contraseña, así que la vista de seguridad oculta los datos personales `telefono` y `direccion_entrega` y expone solo clientes activos. Se creó un rol sin login con permiso únicamente sobre la vista:
```sql
CREATE ROLE reportes_tp NOLOGIN;
GRANT SELECT ON v_clientes_publico TO reportes_tp;
SET ROLE reportes_tp;
SELECT * FROM v_clientes_publico LIMIT 3;   -- funciona, sin telefono ni direccion_entrega
SELECT * FROM clientes LIMIT 3;             -- SQL Error [42501]: permission denied for table clientes
RESET ROLE;
```
El rol puede consultar la vista pero no la tabla base.

---

## Parte C — Vista materializada `mv_facturacion_categoria_mes`
Reporte: facturación por categoría y mes de pedidos entregados y activos. Creada con `WITH DATA` y el índice único `ux_mv_facturacion_categoria_mes (id_categoria, mes)`, requisito de `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

**Consulta original (sin materializar):**
```
HashAggregate  (cost=14108.34..17198.06 rows=86729 width=57) (actual time=183.299..183.458 rows=120.00 loops=1)
  Buffers: shared hit=2496
  (lee 150.000 filas de detalle_pedido y 28.298 de pedidos, 3 Hash Join)
Execution Time: 184.143 ms
```
**Contra la vista materializada (`SELECT * FROM mv_facturacion_categoria_mes`):**
```
Seq Scan on mv_facturacion_categoria_mes  (cost=0.00..2.20 rows=120 width=25) (actual time=0.021..0.033 rows=120.00 loops=1)
  Buffers: shared hit=1
Execution Time: 0.058 ms
```
**Resultado:** de 184,143 ms a 0,058 ms (unas 3.175 veces menos) y de 2.496 páginas leídas a 1. La vista guarda el resultado ya calculado (120 filas: 5 categorías × 24 meses). Se usa Seq Scan porque con 120 filas es lo más barato; el índice único existe para permitir el refresco concurrente.

`REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;` se ejecutó correctamente en 0,284 s.

### Frecuencia de refresco y consecuencias
**Frecuencia sugerida: una vez por día, de madrugada** (por ejemplo a las 03:00), con `REFRESH MATERIALIZED VIEW CONCURRENTLY`, programado con pg_cron o una tarea del sistema.

**Justificación:** es un reporte de facturación por categoría y mes, de consulta gerencial, que no necesita datos al segundo. Recalcularlo cuesta unos 0,3 s, así que hacerlo una vez al día es barato. Con `CONCURRENTLY` el refresco no bloquea las lecturas.

**Qué implica para los usuarios:** entre un refresco y otro el dato queda desactualizado. Los pedidos entregados durante el día no aparecen hasta el refresco siguiente y el mes en curso se ve incompleto (hasta 24 horas de atraso). Los meses cerrados no cambian. Conviene aclararlo en el reporte ("datos actualizados al día anterior") y no usarlo para decisiones que requieran cifras en tiempo real. Si hiciera falta más frescura, se puede refrescar más seguido (por ejemplo, cada hora) a costa de más carga sobre la base.