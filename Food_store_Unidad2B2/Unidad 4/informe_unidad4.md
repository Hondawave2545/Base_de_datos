# Informe — Unidad 4: FNBC y desnormalización controlada

> **Informe de pruebas en una base aislada.** Los resultados corresponden a la instancia sintética `foodstore_u4_test_20261110` (PostgreSQL 18.6) y no a la base real `foodstore_tp`. En esta ejecución no se accedió a `foodstore_tp`.
>
> **Evidencias:** se guardaron transcripciones completas de `psql` con marcas de tiempo y PID en `unidad4/evidencias/`. No se generaron capturas de pantalla; las transcripciones permiten reconstruir cada salida y cada plan. Si la cátedra exige imágenes, deben capturarse desde DBeaver usando las mismas consultas.

## Datos de la entrega

- Materia / comisión: Base de Datos II — Comisión 3
- Integrante: Aquino
- Cantidad de integrantes: 1
- Fecha: 2026-11-11
- Base de pruebas y versión de PostgreSQL: `foodstore_u4_test_20261110`, PostgreSQL 18.6 (x86_64-windows), zona `America/Buenos_Aires`
- Datos de la instancia medida: 50.000 pedidos, 150.000 detalles, 40 productos y 5 categorías; fixture sintético con pedidos del 2026-11-10
- Ejecución verificada: 2026-11-11, con `psql` 18 ejecutando los archivos guardados directamente desde disco

## Evidencias y trazabilidad

Los dos scripts se ejecutaron con `psql -f` desde sus rutas guardadas, no desde buffers manuales:

```powershell
psql -h localhost -p 5432 -U postgres -d foodstore_u4_test_20261110 -v ON_ERROR_STOP=1 `
  -f "unidad4\tp_fnbc_control_lote.sql"

psql -h localhost -p 5432 -U postgres -d foodstore_u4_test_20261110 -v ON_ERROR_STOP=1 `
  -f "unidad4\tp_desnormalizacion_top_categorias.sql"
```

Hashes SHA-256 de los archivos ejecutados:

| Archivo | SHA-256 |
|---|---|
| `unidad4/tp_fnbc_control_lote.sql` | `0B91D28E711C97787EC0DFD10FD9C18031F4DEFB76AF7D9BBD94A282FD02203A` |
| `unidad4/tp_desnormalizacion_top_categorias.sql` | `5499EB27729E268F69B61DA45753257ED860715A39721F1C6C1CC8C3B77E212C` |

Archivos de evidencia guardados:

| Archivo | Contenido |
|---|---|
| `unidad4/evidencias/00_consigna_texto.txt` | Texto extraído de `unidad4.pdf` |
| `unidad4/evidencias/01_inspeccion_previa.txt` | Estructura, triggers, constraints, conteos y auditoría previa |
| `unidad4/evidencias/02_drop_schema.txt` | Reinstalación limpia: `current_database()`, `DROP SCHEMA ... CASCADE`, 150.000 detalles preservados |
| `unidad4/evidencias/03_parte1_desde_archivo.txt` | Ejecución completa de la Parte 1 desde archivo, exit 0 |
| `unidad4/evidencias/04_parte2_desde_archivo.txt` | Ejecución completa de la Parte 2 desde archivo, exit 0, planes y auditorías |
| `unidad4/evidencias/05_medicion_fecha_con_datos.txt` | Medición antes/después con fecha `2026-11-10` (día con ventas) |
| `unidad4/evidencias/06_concurrencia_*` | Dos sesiones concurrentes, monitor de `pg_stat_activity`, auditoría posterior |
| `unidad4/evidencias/07_limpieza_concurrencia.txt` | Borrado de las dos filas de prueba y verificación del fixture |
| `unidad4/evidencias/08_estado_final.txt` | Verificación final: base correcta, conteos, 0 filas de prueba, 0 diferencias, top 5 y constraints |
| `unidad4/evidencias/INDICE.md` | Índice que ordena y describe todas las evidencias de la carpeta |

La ejecución anterior desde buffers de DBeaver no se puede comparar byte a byte con los archivos. Esa limitación queda cubierta por esta ejecución desde disco: los resultados documentados abajo corresponden al contenido actual de los archivos guardados.

## Alcance e integración con Food Store

La Parte 1 se aísla en el esquema PostgreSQL `mayorista_u4`; no reutiliza ni altera `empleados`, `sucursales`, `clientes` o las tablas de pedidos. `lote`, `deposito` y `usuario` son maestros mínimos de la extensión, con `id BIGINT PRIMARY KEY` y las referencias indicadas en la consigna.

La Parte 2 usa la estructura observada de las tablas de pedidos:

| Consigna | Esquema observado en la base de test |
|---|---|
| `pedido` | `public.pedidos` |
| `pedido.id` / `pedido.fecha` | `pedidos.id_pedido` / `pedidos.fecha_pedido` |
| `detalle_pedido.pedido_id` | `detalle_pedido.id_pedido` |
| `producto` / `producto.id` | `public.productos` / `productos.id_producto` |
| `detalle_pedido.producto_id` | `detalle_pedido.id_producto` |
| `producto.categoria_id` | `productos.id_categoria` |
| `categoria` / `categoria.id` | `public.categorias` / `categorias.id_categoria` |
| `dp.subtotal` | `detalle_pedido.subtotal` |
| `dp.eliminado`, `ped.eliminado` | No existen en la estructura observada |

Hallazgos de estructura relevantes:

- `public.detalle_pedido` tiene `UNIQUE (id_pedido, id_producto)` (`detalle_pedido_id_pedido_id_producto_key`). Esto impide insertar dos detalles del mismo producto en un pedido y condiciona las pruebas de escritura.
- `public.pedidos`, `public.productos` y `public.categorias` tienen columna `activo BOOLEAN NOT NULL DEFAULT true`.
- No existe ninguna columna `eliminado` (ni `deleted`) en `public`.
- En el fixture, las 50.000 filas de `pedidos`, las 40 de `productos` y las 5 de `categorias` tienen `activo = true`.

No se filtra `pedidos.activo`: no se confirmó que `activo = TRUE` equivalga a `eliminado = FALSE`. Además, `detalle_pedido` no tiene ninguna marca de eliminación, por lo que el predicado `dp.eliminado = FALSE` no se puede traducir literalmente. Hasta confirmar la regla de vigencia con el docente, la consulta considera todas las filas presentes que unen con las cuatro tablas. **La equivalencia semántica con la consulta literal de la consigna queda pendiente de esa confirmación.** El detalle se desarrolla en la sección «Sobre el filtro `eliminado = FALSE`».

## Parte 1 — Análisis y aplicación de FNBC

### Regla de negocio y dependencias funcionales

Se usan `L = LoteID`, `D = DepositoID` y `R = ResponsableControlID`:

- Para cada lote y depósito, el responsable queda determinado: `LD → R`.
- Cada responsable pertenece a un único depósito: `R → D`.

### Clausuras, claves candidatas y atributos primos

- `(LD)+ = {L,D,R}`; `LD` es clave candidata.
- `(LR)+ = {L,R,D}` porque `R → D`; `LR` es clave candidata.
- `L+ = {L}`, `D+ = {D}` y `R+ = {R,D}`; ninguna de estas clausuras contiene los tres atributos.

El conjunto completo de claves candidatas es `{L,D}` y `{L,R}`. Los tres atributos son primos, porque cada uno pertenece a alguna clave candidata; no hay atributos no primos.

La relación `responsable_control_deposito` está en FNBC porque `R` es su clave; `lote_responsable` está en FNBC porque no tiene dependencias funcionales no triviales adicionales a las determinadas por su clave `(L,R)`, bajo las reglas de negocio declaradas.

### Violación de FNBC y anomalías

`LD → R` tiene un determinante que es clave candidata. `R → D` viola FNBC: `R` no es superclave, ya que no determina `L`.

- **Inserción:** con la relación original no se puede registrar un nuevo responsable y su depósito sin asociarle también un lote y un depósito interviniente.
- **Actualización:** el depósito del responsable 801 se repite en los lotes 501 y 502; actualizar una sola fila deja datos contradictorios.
- **Borrado:** al borrar la última asignación de lote del responsable 801 también se pierde el único registro de que pertenece al depósito 30.

### Descomposición, restricciones y unión sin pérdida

El esquema original de ejemplo conserva la PK `(lote_id, deposito_id)` y las tres FK. La descomposición implementada es:

- `responsable_control_deposito(responsable_control_id, deposito_id)`, PK `responsable_control_id`, FK a `usuario(id)` y `deposito(id)`. Impone `R → D`.
- `lote_responsable(lote_id, responsable_control_id)`, PK compuesta `(lote_id, responsable_control_id)`, FK a `lote(id)` y FK a `responsable_control_deposito(responsable_control_id)`.

La FK desde `lote_responsable` al responsable-depósito impide asignaciones huérfanas. La dependencia `LD → R` no queda preservada directamente por las claves: un lote podría aparecer asociado a dos responsables que pertenecen al mismo depósito. El SQL agrega un constraint trigger diferible que valida la unión reconstruida y rechaza esa situación; el chequeo se serializa con un advisory lock y exige transacciones `READ COMMITTED`. La prueba negativa usa una subtransacción y debe ser rechazada sin dejar cambios.

La vista `v_control_lote_almacen_compat` usa `NATURAL JOIN`; el único atributo común es `responsable_control_id`, clave de `responsable_control_deposito`. Por el criterio de superclave sobre el atributo común, la descomposición es sin pérdida bajo las dependencias funcionales declaradas.

La instancia indicada por la consigna está incluida: `(501,30,801)`, `(502,30,801)`, `(503,31,802)`. El script compara la relación original y la vista mediante diferencias en ambos sentidos y cuenta las filas.

**Resultado real de la ejecución desde archivo (2026-11-11):**

- Diferencia bidireccional original vs vista: **0 filas**.
- Conteos original / reconstruido: **3 / 3**.
- `CREATE FUNCTION`, `CREATE TRIGGER`, `CREATE VIEW` y la migración terminaron sin error (`exit 0`).
- Prueba negativa de FK: se rechazó el `responsable_control_id = 999999` inexistente.
- Prueba negativa de FD: se rechazó la asignación contradictoria del responsable 802 al depósito 30 junto con el lote 501.
- Los avisos reales fueron: `Prueba negativa: la FK rechazó el responsable inexistente.` y `Prueba negativa: la asignación contradictoria fue rechazada.`
- Catálogo verificado: las PK, FK y los dos constraint triggers diferibles existen en `mayorista_u4`.

El script no es idempotente (`CREATE SCHEMA mayorista_u4` sin `IF NOT EXISTS`). Para repetir la prueba se eliminó antes el esquema con `DROP SCHEMA mayorista_u4 CASCADE` dentro de la base de test; los 150.000 detalles de `public` quedaron intactos. La evidencia está en `02_drop_schema.txt` y `03_parte1_desde_archivo.txt`.

## Parte 2 — Consulta diaria y desnormalización controlada

### Consulta base adaptada

El SQL conserva la agrupación de la consigna por nombre (`GROUP BY c.nombre`), incluso si dos IDs de categoría comparten el mismo nombre. Usa un rango semiabierto sobre `pedidos.fecha_pedido` desde `CURRENT_DATE` hasta `CURRENT_DATE + INTERVAL '1 day'`; sus límites representan el día de la sesión según el tipo de la columna y la zona horaria.

### Sobre el filtro `eliminado = FALSE`

La consigna escribe dos predicados: `dp.eliminado = FALSE` y `ped.eliminado = FALSE`. Para aplicarlos literalmente, el esquema debería tener una columna `eliminado` en `detalle_pedido` y en `pedidos`. Esa columna no existe en las tablas observadas.

La inspección del catálogo de la base de test (evidencia `01_inspeccion_previa.txt`) mostró:

- En `public` no existe ninguna columna llamada `eliminado` ni `deleted` en ninguna tabla.
- `public.pedidos`, `public.productos` y `public.categorias` tienen una columna `activo BOOLEAN NOT NULL DEFAULT true`.
- `public.detalle_pedido` no tiene ninguna columna de estado, baja lógica ni marca de eliminación.
- En el fixture, las 50.000 filas de `pedidos`, las 40 de `productos` y las 5 de `categorias` tienen `activo = true`.

La existencia de `activo` no alcanza para reemplazar `eliminado = FALSE`. `activo` es un indicador de estado del negocio, pero el esquema no documenta que su valor `TRUE` signifique exactamente "no eliminado". Tampoco hay filas con `activo = false` en el fixture que permitan comprobar el comportamiento del reporte en ese caso. En consecuencia, no hay evidencia suficiente para afirmar que `activo = TRUE` equivale a `eliminado = FALSE`, y no se reemplaza un predicado por otro de manera silenciosa.

Por eso, la consulta implementada trabaja con todas las filas persistidas que se unen con las cuatro tablas. No se agregó un filtro simulado ni se modificó el resultado para aparentar que el predicado de la consigna fue aplicado.

**Estado de la limitación:** pendiente de confirmación del docente. Si la cátedra exige el filtro literalmente, hay que acordar qué predicado lo representa en este esquema. Si se confirma que `pedidos.activo = TRUE` equivale a `ped.eliminado = FALSE`, se podría agregar ese filtro a la consulta; para `detalle_pedido` no existe una columna equivalente, por lo que también habría que confirmar si toda fila persistida se considera vigente. Cualquier cambio de ese tipo debe volver a ejecutar la auditoría de sincronización.

### Nota sobre la fecha del fixture

El fixture contiene pedidos únicamente del **2026-11-10**. La sesión de esta ejecución fue el **2026-11-11**, por lo que la consulta del script con `CURRENT_DATE` devolvió **0 filas** (no hay ventas de ese día). Eso es el comportamiento correcto de un reporte diario, pero no sirve como comparación de rendimiento antes/después.

Para medir con datos reales del fixture se ejecutó la misma forma de consulta con la fecha literal `2026-11-10` (sin modificar el SQL entregado). Esa medición es la que se informa en la tabla de rendimiento. El script entregado sigue usando `CURRENT_DATE`, como pide la consigna; para reproducir la medición debe usarse una fecha con ventas o cargar pedidos del día actual.

### Patrón elegido y sincronización

El SQL prepara una tabla agregada `mayorista_u4.ventas_categoria_dia`, mantenida por triggers de sentencia sobre `detalle_pedido`, `pedidos` y `productos`. Cada modificación, inserción, eliminación o truncamiento de esas fuentes vuelve a calcular el resumen dentro de la misma transacción; si la transacción falla, el resumen también revierte. Se usa una clave por fecha e ID de categoría para mantener el agregado, y la consulta final vuelve a agrupar por nombre. Así el reporte no recorre las cuatro tablas operativas.

El mecanismo es deliberadamente sencillo de auditar, pero recalcula el agregado completo después de cada sentencia de escritura relevante. Las mediciones realizadas mostraron un costo alto de escritura; el patrón sirve para demostrar el intercambio entre lecturas y escrituras, pero no se recomienda llevarlo a producción sin evaluar la carga real. Los triggers usan un advisory lock (`pg_advisory_xact_lock(740401, 1)`) y exigen `READ COMMITTED`; hay que validar ese supuesto y las reglas de FK/borrado de la base real. La reversibilidad es sin pérdida de datos fuente: la tabla de resumen puede reconstruirse desde las tablas operativas y eliminarse sin eliminar ventas.

La consigna también acepta una vista materializada; esta evita triggers, pero solo se sincroniza al ejecutar `REFRESH MATERIALIZED VIEW`, por lo que un refresco periódico introduce retraso y no garantiza tiempo real por sí mismo. Si el costo del recálculo por triggers resulta inaceptable, esa alternativa requiere acordar y medir un intervalo de refresco y su frescura antes de elegirla.

### Mediciones de rendimiento (2026-11-10, día con ventas)

| Métrica | Antes: consulta normalizada | Después: resumen |
|---|---|---|
| Tiempo de planificación | 17,082 ms | 2,569 ms |
| Tiempo de ejecución | 188,606 ms | 0,174 ms |
| Buffers compartidos | 1.904 hit | 3 hit |
| Nodo dominante | `Parallel Seq Scan` sobre `detalle_pedido` y `pedidos`, con `Hash Join` y agregación/ordenamiento paralelo; el `Sort`/`GroupAggregate` acumula ≈139 ms | `Bitmap Index Scan` + `Bitmap Heap Scan` sobre la PK del resumen, `Hash Join` con 5 categorías y `Sort`/`GroupAggregate` de 5 filas |

La consulta sobre el resumen fue aproximadamente **1.084 veces más rápida** (188,606 ms / 0,174 ms) y usó **634 veces menos buffers** (1.904 / 3) en esta muestra. Son muestras individuales, con caché caliente, y no una comparación estadística. En pasadas anteriores se observaron valores distintos (por ejemplo, 388,780 ms y 0,309 ms); no se reproducen exactamente y no se combinan con esta medición.

La ejecución del script con `CURRENT_DATE = 2026-11-11` también se conservó como evidencia: devolvió 0 filas, con 5,641 ms en la consulta normalizada y 0,214 ms en el resumen. Esos valores no se usan para afirmar una mejora porque ambos planes procesaron cero ventas.

### Costo de escritura

En la ejecución desde archivo, la inserción de una fila en `detalle_pedido` medida con `EXPLAIN (ANALYZE, BUFFERS)` dio:

- Sin el trigger de resumen: **3,837 ms**.
- Con el trigger de resumen: **284,971 ms**, de los cuales **284,531 ms** corresponden al trigger `trg_ventas_categoria_dia_detalle`.
- Ambas transacciones terminaron con `ROLLBACK`.

Es una muestra individual; el recálculo integral es aproximadamente 74 veces más costoso que la inserción sin trigger en esta medición. En pasadas anteriores se observaron 2,255 ms / 211,988 ms y 335,579 ms con trigger; no se promedian ni se presentan como una comparación estadística.

### Auditoría y pruebas de sincronización

El script compara el agregado completo de las tablas fuente con la tabla resumen en ambos sentidos; la auditoría debe devolver cero filas después de la carga inicial y después de cada prueba de escritura.

| Prueba | Resultado real (2026-11-11) |
|---|---|
| Diferencia simétrica del agregado fuente contra el resumen | 0 filas |
| Diferencia simétrica del top 5 (2026-11-10) | 0 filas |
| INSERT/UPDATE/DELETE en `pedidos`, `productos` y `detalle_pedido` | 9 auditorías; 0 diferencias en cada paso |
| Reversión de las pruebas DML | `ROLLBACK`; después se verificaron 150.000 detalles |
| `TRUNCATE detalle_pedido` | La fuente y el resumen quedaron vacíos dentro de la transacción; `ROLLBACK` restauró 150.000 detalles y el resumen volvió a coincidir |
| Top 5 observado para 2026-11-10 | Bebidas 67.256.250; Ensaladas 64.668.750; Postres 64.668.750; Hamburguesas 62.081.250; Pizzas 59.493.750 |
| Reejecución completa de los scripts desde archivo | Parte 1: exit 0, 0 diferencias, 3/3, dos rechazos esperados. Parte 2: exit 0, 9 filas de auditoría con 0 diferencias, `TRUNCATE`/`ROLLBACK` correcto |
| Conteo final del fixture | 50.000 pedidos, 150.000 detalles, 40 productos, 5 categorías, 5 filas de resumen, 6 triggers U4, 0 diferencias |

### Prueba real de escrituras concurrentes

Se ejecutaron dos sesiones independientes de `psql` contra `foodstore_u4_test_20261110`, ambas en `READ COMMITTED` y con PIDs distintos:

- Sesión A: PID **20536**.
- Sesión B: PID **13576**.

Secuencia real:

1. A ejecutó `BEGIN`, insertó el detalle `150001` (pedido 1, producto 4, subtotal 100) y el `INSERT` tardó **392,414 ms**. El trigger de resumen tomó el advisory lock `(740401, 1)` al final de la sentencia y lo retuvo hasta el `COMMIT`.
2. A ejecutó `pg_sleep(6)`, que tardó **6.004,523 ms**, manteniendo el lock.
3. B arrancó aproximadamente 1,8 s después e intentó insertar el detalle `150002` (pedido 1, producto 5, subtotal 200). Su `INSERT` tardó **5.038,218 ms**.
4. El monitor de `pg_stat_activity`, muestreado cada 600 ms, mostró a B en `state = active`, `wait_event_type = Lock`, `wait_event = advisory` entre las 11:45:15.855 y las 11:45:19.910; en paralelo, A aparecía en `Timeout / PgSleep`.
5. A hizo `COMMIT` a las 11:45:20.480. B se desbloqueó, refrescó el resumen y commiteó a las 11:45:20.884.
6. Auditoría posterior: las dos filas estaban presentes y la diferencia simétrica fuente/resumen fue **0**.
7. Limpieza: `DELETE` de las dos filas en una transacción real (`DELETE 2`), commit. El fixture volvió a 150.000 detalles, 50.000 pedidos, 40 productos, 5 categorías, 5 filas de resumen y 0 diferencias.

Esto demuestra solapamiento real y contención real: B no pudo refrescar el resumen mientras A tenía el advisory lock. También demuestra que el resumen queda consistente después de ambas commits. No demuestra comportamiento bajo alta concurrencia, bajo otros niveles de aislamiento ni con cargas de escritura masivas; esos casos quedan como prueba de carga opcional.

La primera tentativa de la prueba concurrente falló por una razón ajena a la concurrencia: `detalle_pedido` tiene `UNIQUE (id_pedido, id_producto)` y las dos filas usaban el mismo par `(1,1)`. Se corrigió usando pares distintos, `(1,4)` y `(1,5)`. El hallazgo de la restricción única quedó documentado.

### Identidad archivo vs ejecución

Los scripts de esta ejecución se cargaron con `psql -f` desde los archivos del proyecto y sus hashes SHA-256 quedaron registrados arriba. Por lo tanto, los resultados corresponden al contenido actual de los archivos. La ejecución anterior desde buffers de DBeaver no se comparó byte a byte; esa comparación ya no es necesaria para esta evidencia, aunque si se quiere auditar la pasada anterior habría que repetirla desde disco (que es lo que se hizo aquí).

## Pendiente antes de la entrega

1. **Confirmar la semántica de vigencia con el docente:** no existen columnas `eliminado`; `pedidos`, `productos` y `categorias` tienen `activo`, pero en el fixture todas las filas están en `true` y `detalle_pedido` no tiene marca de eliminación. Si la cátedra exige literalmente `dp.eliminado = FALSE` y `ped.eliminado = FALSE`, hay que acordar el predicado equivalente y volver a ejecutar la auditoría. Sin esa confirmación, la equivalencia semántica con la consulta de la consigna queda abierta.
2. Exportar el informe a PDF o Word. Los datos de integrante, comisión, cantidad de integrantes y fecha ya están completados.
3. Si la cátedra exige capturas de pantalla, generarlas desde DBeaver para: los dos planes de `EXPLAIN ANALYZE`, la tabla de 9 auditorías, las pruebas negativas de la Parte 1 y el monitor de concurrencia. Las transcripciones de `psql` ya guardadas contienen esas mismas salidas.
4. Opcional: repetir las mediciones de lectura y escritura al menos tres veces y reportar mediana, para reducir el efecto de la caché y de una muestra individual.
5. Opcional: probar niveles de aislamiento distintos de `READ COMMITTED`; los triggers los rechazan por diseño y eso debe quedar explícito si se evalúa la robustez.
6. Tener presente que la base de test usada tiene un esquema reducido respecto de la base real y que no se accedió a `foodstore_tp`. Las mediciones no deben presentarse como mediciones de la base real.
7. El reporte diario usa `CURRENT_DATE`; si se ejecuta en una fecha sin pedidos, el top 5 será vacío aunque la auditoría completa siga siendo correcta. Para la entrega, la medición de rendimiento se hizo con la fecha del fixture (`2026-11-10`) y así quedó documentada.
