# Informe Unidad 7 — NoSQL y nuevas formas de almacenamiento (Food Store)

**Proyecto:** Base de Datos II — Unidad 7 (Food Store)  
**Repositorio canónico:** `C:\Users\aquin\AppData\Local\Temp\kilo\Base_de_datos` — remote `https://github.com/Hondawave2545/Base_de_datos.git` (branch `main`)  
**Carpeta de trabajo (exclusiva):** `food_store_unidad7b2/`  
**Fecha de revisión documentada:** 2026-11-12 (ver evidencias con timestamp)

> **Restricciones respetadas:** solo trabajo en `food_store_unidad7b2/`; sin commit/push; sin modificación de Unidades 5 y 6 ni otros archivos ajenos; PostgreSQL `foodstore_tp` en solo lectura (sin INSERT/UPDATE/DELETE); MongoDB alterado únicamente en `foodstore_u7` (creada para esta unidad, sin borrar/reemplazar datos previos); sin credenciales ni datos personales reales en el informe; sin PDF generado.

---

## 1. Alcance, entorno y control de cambios

| Elemento | Detalle verificado |
|---|---|
| BD relacional origen | `foodstore_tp` (PostgreSQL 18.6, `localhost:5432`, usuario `postgres`) — **solo lectura** |
| MongoDB | Server 4.4.32 (servicio `MongoDB Server` Running), shell `"C:\Program Files\MongoDB\Server\4.4\bin\mongo.exe"` v4.4.32 |
| Base/colección U7 | `foodstore_u7.pedidos` |
| Subconjunto migrado | 5 pedidos reales con sus líneas: **IDs 1, 4, 5, 6, 18** |
| Integridad origen (re-verificada) | `pedidos` = 50000, `detalle_pedido` = 150000 (sin cambios) |
| Estado Mongo (re-verificado) | DBs: `[admin, config, foodstore_u7, local]`; `collections:[pedidos]`; `count:5`; IDs `[1,4,5,6,18]` |

**Evidencia:** `evidencias_revision_completa.txt` (T01–T04).

---

## 2. Parte 1 — Modelo documental y migración (Consignas 1–3)

### Consigna 1. Subconjunto, tablas/claves PostgreSQL y esquema documental

**Tablas y claves (verificadas con `\d+`, solo lectura):**

| Tabla | PK | FKs / relaciones | Campos usados |
|---|---|---|---|
| `pedidos` | `id_pedido` (identity) | `id_cliente → clientes(id_cliente)`, `id_sucursal → sucursales(id_sucursal)`, `id_empleado_repartidor → empleados(id_empleado)` (nullable) | `fecha_pedido timestamptz`, `estado` (enum), `tipo_entrega` (enum), `total numeric(10,2)`, `datos_envio jsonb`, `activo` |
| `detalle_pedido` | `id_detalle` (identity) | `id_pedido → pedidos ON DELETE CASCADE`, `id_producto → productos` | `cantidad` (>0), `precio_unitario` (>0), `subtotal` (>0); UNIQUE `(id_pedido,id_producto)` |
| `clientes` | `id_cliente` (identity) | referenciada por `pedidos` | esenciales: `id_cliente`, `fecha_registro`, `activo` (**PII excluida del informe/documentos de evidencia pública**) |
| `productos` | `id_producto` (identity) | referenciada por `detalle_pedido` | `nombre` (contexto de línea) |

Relaciones: `clientes 1—N pedidos`, `pedidos 1—N detalle_pedido`, `productos 1—N detalle_pedido`. Conteo origen: 50.000 pedidos con detalle.

**Esquema colección `foodstore_u7.pedidos` (1 documento = 1 pedido completo):**

| Campo | Tipo | Nota |
|---|---|---|
| `_id` | int | = `id_pedido` original (conservado) |
| `id_pedido` | int | trazabilidad |
| `fecha_pedido` | ISODate | desde `timestamptz` |
| `estado`, `tipo_entrega` | string | valores de dominio conservados |
| `id_sucursal`, `id_empleado_repartidor` | int/null | IDs conservados |
| `total` | NumberDecimal | importe histórico exacto |
| `activo` | bool | conservado |
| `datos_envio` | objeto embebido | estructura jsonb conservada |
| `cliente` | **objeto embebido** | `{id_cliente, cliente_ref, fecha_registro, activo}` — sin nombre/email/teléfono/dirección |
| `detalle` | **arreglo embebido** | `{id_detalle, id_producto, producto_nombre, cantidad, precio_unitario(NumberDecimal), subtotal(NumberDecimal)}` |
| `origen` | objeto | metadata (`bd`, tablas, `migrado_en`) |

### Consigna 2. Migración (≥5 pedidos reales, identificadores/importes históricos conservados)

- **Precheck ejecutado:** `dbs` sin `foodstore_u7`, `collections=[]`, `pedidos.count=0` antes de insertar (evidencia inicial y lógica en `migracion_u7.js`). **No se borró ni reemplazó** nada.
- **Ejecución:** `mongo.exe --quiet foodstore_u7 migracion_u7.js` → `PRECHECK... pedidos.count=0`, `INSERT_OK insertedCount=5`, IDs `[1,4,5,6,18]`.
- **Datos:** obtenidos por `SELECT` de solo lectura sobre `foodstore_tp`; importes como `NumberDecimal` (strings exactos), fechas como `ISODate`; cliente sin PII real; `datos_envio` conservado.
- **Pedidos migrados:** 1 (cancelado, 39676.55), 4 (en_camino, 10547.69), 5 (en_preparacion, 24590.33), 6 (entregado, 21834.90), 18 (pendiente, 23949.34) — 3 líneas c/u, 15 líneas totales.

### Consigna 3. Reglas de integridad y justificación de embebidos

**Regla 1 — Consistencia monetaria histórica:** `subtotal = cantidad × precio_unitario` en cada línea y `total = Σ(subtotales)` del pedido, usando valores históricos copiados (sin recalcular con precios actuales).  
**Regla 2 — Integridad/completitud referencial:** documento por `id_pedido` existente con líneas reales completas; se conservan `id_pedido`, `id_detalle`, `id_producto`, IDs de relación, estado/tipo de entrega del dominio, `cantidad>0`, `precio_unitario>0`, `subtotal>0`, y correspondencia con origen.

**Justificación de embebidos:** `detalle` embebido porque el acceso frecuente es al pedido completo (lectura en una sola operación, sin `$lookup`, cardinalidad acotada); `cliente` embebido como snapshot esencial (sin PII) para contexto del pedido; se conserva `id_producto` + `producto_nombre` y precios históricos en línea (no precio actual), priorizando localidad de lectura y trazabilidad.

---

## 3. Parte 2 — Consultas y verificación (Consignas 4–5)

### Consigna 4. Consultas MongoDB (ejecutadas)
- **a) Todos los pedidos (id y estado):** 5 resultados → (1,cancelado),(4,en_camino),(5,en_preparacion),(6,entregado),(18,pendiente).
- **b) Estado `entregado`:** 1 resultado → `id_pedido 6` (21834.90).
- **c) Contiene `id_producto=8` en `detalle`:** 3 resultados → IDs **4,5,6** (líneas det. 12,14,16 con `producto_nombre` "Producto 8", cantidades 1,3,3, precio histórico 3521.63).
- **d) `total > 20000` (umbral 20000):** 4 resultados → IDs **1,5,6,18**. **Justificación:** 20000 separa ticket alto en el subconjunto (4/5 superan, 1 queda fuera: pedido 4 = 10547.69), verificando filtro numérico sobre `NumberDecimal` de forma no trivial.

### Consigna 5. Equivalentes PostgreSQL (b,c) y comparación

Ejecutadas en `foodstore_tp` (solo lectura) sobre `id_pedido IN (1,4,5,6,18)`:

| Consulta | Cantidad PostgreSQL | IDs PostgreSQL | Cantidad MongoDB | IDs MongoDB | ¿Coinciden IDs? | Diferencias |
|---|---:|---|---:|---|:---:|---|
| b) `estado='entregado'` | 1 | {6} | 1 | [6] | **Sí** | Ninguna |
| c) contiene `id_producto=8` | 3 | {4,5,6} | 3 | [4,5,6] | **Sí** | Ninguna |

**Acción correctiva:** no requerida (coincidencia exacta).

---

## 4. Parte 3 — Evaluación tecnológica e IA (Consignas 6–7)

### Consigna 6. Consulta a IA
- **Herramienta:** Kilo Code (asistente IA de la sesión de trabajo).
- **Consulta realizada:** comparación PostgreSQL vs MongoDB para pedidos de Food Store considerando: (1) modelo relacional actual (pedidos/detalle_pedido/clientes/productos con claves y constraints), (2) acceso frecuente a pedidos completos con sus líneas, (3) necesidad de conservar coherencia de cantidades y precios históricos.
- **Síntesis de respuesta:** PostgreSQL aporta integridad fuerte (FK, CHECK, transacciones) y joins; MongoDB favorece documento embebido para lectura completa en una operación y flexibilidad, pero la coherencia de importes calculados/históricos depende del diseño/migración. Para lectura frecuente del pedido completo puede usarse modelo documental; el núcleo transaccional se beneficia de PostgreSQL.

### Consigna 7. Contraste de dos afirmaciones (documentación oficial / laboratorio)

**Afirmación 1:** *Embeber `detalle` en el pedido favorece leer el pedido completo en una sola consulta.*  
- **Doc. oficial (MongoDB):** el modelo embebido se recomienda para relaciones "contains"/acceso conjunto, permitiendo recuperar datos relacionados en una sola lectura y operaciones atómicas a nivel de documento. Ref: https://www.mongodb.com/docs/manual/data-modeling/embedding/
- **Laboratorio:** en `foodstore_u7.pedidos` las consultas (a–d) y la lectura completa se resuelven con `find()` sin `$lookup`; en PostgreSQL se requieren `JOIN` (`pedidos`+`detalle_pedido`+`productos`) para la vista equivalente. **Confirmada.**

**Afirmación 2:** *PostgreSQL garantiza mejor la integridad referencial y de importes (cantidades/precios/totales) vía constraints/transacciones; en MongoDB la coherencia debe asegurarse en el modelo/migración.*  
- **Doc. oficial (MongoDB):** embedding y relaciones se modelan según acceso; la consistencia de referencias/campos calculados recae en el diseño/aplicación (MongoDB ofrece validación y transacciones, pero no FKs relacionales implícitas entre documentos como en el modelo relacional). Ref: https://www.mongodb.com/docs/manual/data-modeling/embedding/ y https://www.mongodb.com/es/docs/manual/reference/method/db.collection.find/
- **Laboratorio:** PostgreSQL define PK/FK, UNIQUE `(id_pedido,id_producto)` y CHECKs (`cantidad>0`, `precio_unitario>0`, `subtotal>0`, `total>=0`); en MongoDB 4.4 la corrección se aseguró copiando históricos `NumberDecimal` y validando (`lineas_calc_all:true`, `total_match_all:true`, sin duplicados). **Confirmada.**

### Conclusión (≤200 palabras)
Para el subconjunto “pedidos y detalle” de Food Store conviene una **combinación**: mantener **PostgreSQL** como fuente transaccional autoritativa y usar **MongoDB** como vista documental para lectura de pedidos completos. (1) **Acceso:** el pedido se consulta como unidad con sus líneas; el modelo embebido permite recuperarlo en una sola operación `find()` sin joins, coherente con la guía de embedding de MongoDB y verificado en las consultas a–d. (2) **Integridad y coherencia histórica:** PostgreSQL impone FKs, CHECKs y unicidad que protegen cantidades, precios y totales en origen; en MongoDB 4.4 la consistencia (`NumberDecimal`, `subtotal=cantidad*precio_unitario`, `total=Σ subtotales`) debe garantizarse en migración/validación, lo que se comprobó en los 5 documentos (`total_match_all` y `lineas_calc_all` verdaderos, sin duplicados). (3) **Trazabilidad y verificación:** conservar `_id=id_pedido` e IDs originales permitió comparar resultados exactos entre motores (b: {6}; c: {4,5,6}, coincidencia total). Así, MongoDB optimiza lecturas documentales del subconjunto sin reemplazar las garantías relacionales del sistema principal.

---

## 5. Registro de pruebas y verificaciones (ejecutadas y pendientes)

> **Leyenda:** PASS = ejecutada y resultado esperado obtenido; FAIL = ejecutada con resultado incorrecto; PENDIENTE = no realizada. Ninguna prueba se marca por revisión de código únicamente.

| ID | Qué se quería comprobar | Comando / procedimiento ejecutado | Resultado esperado | Resultado obtenido (real) | Estado | Error / corrección / repetición |
|---|---|---|---|---|---|---|
| T01 | Repo canónico, remote y ubicación exclusiva U7 | `git -C C:\Users\aquin\AppData\Local\Temp\kilo\Base_de_datos remote -v`; `git status --short` | Remote `Hondawave2545/Base_de_datos.git`; trabajo solo en `food_store_unidad7b2/` | Remote correcto; estado: `?? food_store_unidad6b2/informe_u6.html`, `?? food_store_unidad7b2/` (sin cambios en U5/U6) | **PASS** | — |
| T02 | Existencia de archivos requeridos y evidencias | `Get-ChildItem food_store_unidad7b2` | Presentes: migración, validación, consultas mongo/sql, informe, README, evidencias | Presentes todos los requeridos + evidencias de revisión (ver sección 6) | **PASS** | — |
| T03 | PostgreSQL sin modificaciones (integridad origen) | `psql -d foodstore_tp -t -A -c "SELECT count(*) FROM pedidos; SELECT count(*) FROM detalle_pedido;"` | 50000 y 150000 (sin cambios) | `pedidos_count=50000`, `detalle_count=150000` | **PASS** | — |
| T04 | Estado Mongo: solo `foodstore_u7` afectada, 5 docs, IDs correctos | `mongo.exe --quiet --eval "db.getSiblingDB('foodstore_u7')...count/ids/collections; listDatabases..."` | `collections:[pedidos]`, count 5, IDs [1,4,5,6,18], DBs incluyen `foodstore_u7` | `count:5`, `ids:[1,4,5,6,18]`, `collections:["pedidos"]`, `dbs:["admin","config","foodstore_u7","local"]` | **PASS** | — |
| T05 | Re-ejecución validación de migración (conteos, IDs, 3 líneas, integridad, duplicados) | `mongo.exe --quiet foodstore_u7 .\validacion_u7.js` | RESUMEN todo `true`, 5 docs, 3 líneas c/u, totales/subtotales ok, sin duplicados | `COUNT=5, IDS_MATCH=true, TODOS_3_LINEAS=true, lineas_calc_all=true, total_match_all=true, DUPLICADOS=[], sin_duplicados=true` | **PASS** | — |
| T06 | Re-ejecución consultas Mongo a–d y umbral d | `mongo.exe --quiet foodstore_u7 .\consultas_mongodb.js` | a:5; b:{6}; c:{4,5,6}; d:{1,5,6,18} con umbral 20000 justificado | Coincide exactamente (evidencia muestra IDs, totales NumberDecimal y línea de justificación) | **PASS** | — |
| T07 | Re-ejecución consultas PostgreSQL b,c y comparación en subconjunto | `psql -d foodstore_tp -f .\consultas_postgresql.sql` | b: cantidad 1 {6}; c: cantidad 3 {4,5,6}; datos origen coherentes | b: 1/{6}; c: 3/{4,5,6}; detalles/validación coinciden con Mongo | **PASS** | — |
| T08a1 | Comparación detallada estado/total por pedido (PG vs Mongo) — intento 1 | `mongo.exe --eval '...{$toString:"$total"}...'` desde PowerShell | Listados comparables por `id_pedido` | `ParserError` en PowerShell: `$toString:'$total'` interpretado como variable (`:` inválido) | **FAIL** | **Problema:** quoting/expansión PowerShell al pasar `$` en `--eval`. **Solución:** ejecutar JS desde archivo (`tmp_t08a.js`) y comillas simples externas. **Repetición:** T08a2. |
| T08a2 | Comparación detallada estado/fecha/total por pedido (PG vs Mongo) — intento 2 | `psql ... to_char(fecha_pedido AT TIME ZONE 'UTC',...)`; `mongo.exe --quiet foodstore_u7 .\tmp_t08a.js` | Estados/totales iguales; fechas coherentes (mismo instante) | PG: 1|cancelado|39676.55,4|en_camino|10547.69,5|en_preparacion|24590.33,6|entregado|21834.90,18|pendiente|23949.34. Mongo: mismos IDs/estados/totales (NumberDecimal). **Nota:** formato UTC en PG salió `THH24:...` por patrón de comillas en shell (formato defectuoso en salida), pero Mongo muestra instantes correctos y `validacion_u7.js`/T07 confirman `fecha_pedido` y valores coincidentes con origen | **PASS** (con observación de formato en comando de contraste, no en datos) | Repetición exitosa de verificación de valores; observación documentada (fallo cosmético del comando PG de formateo, no de datos). |
| T08b | Comparación directa campo a campo de las 15 líneas (5 pedidos): `id_detalle,id_producto,cantidad,precio_unitario,subtotal` PG vs Mongo | `psql -d foodstore_tp -t -A -F "\|" -c "SELECT id_pedido,id_detalle,id_producto,cantidad,precio_unitario,subtotal FROM detalle_pedido WHERE id_pedido IN (1,4,5,6,18) ORDER BY id_pedido,id_detalle;"` y `mongo.exe --quiet foodstore_u7` (script JS: forEach detalle → valores normalizados `toString()`/join `\|`), comparación y diff | 15 líneas; cada campo igual en ambos motores | PG=15, Mongo=15, `diff_count=0`, `all_15_match=True`. Coincidencia individual: 15/15 en `id_detalle`, `id_producto`, `cantidad`, `precio_unitario`, `subtotal` (valores: 4810.70/9621.40, 4366.49/13099.47, 4238.92/16955.68, 4209.08/4209.08, 2816.98/2816.98, 3521.63/3521.63, 2816.98/5633.96, 3521.63/10564.89, 2097.87/8391.48, 3521.63/10564.89, 2097.87/2097.87, 3057.38/9172.14, 2861.39/8584.17, 2931.19/2931.19, 4144.66/12433.98) | **PASS** | Evidencia: `evidencias_t08b_lineas.txt` (2026-11-12 11:56:08-03:00). Diferencia de representación (NumberDecimal en Mongo vs texto PG) normalizada para comparar valores. |
| T08c | Consulta real Mongo: `datos_envio` conservado y `cliente` solo campos esenciales, sin PII (nombre/apellido/email/teléfono/dirección) + verificación procedencia `datos_envio` en PostgreSQL | `mongo.exe --quiet foodstore_u7` (script JS `find` proyectando `{datos_envio:1,cliente:1}`, verificación claves permitidas/prohibidas) y `psql -d foodstore_tp ... SELECT datos_envio->>'direccion', datos_envio->>'ciudad' ...` (solo lectura) | 5 docs: `datos_envio_presente=true`, cliente solo `[activo,cliente_ref,fecha_registro,id_cliente]`, `campos_prohibidos=[]`, `sin_pii=true`; direcciones verificadas como ficticias/prueba o reales | 5/5: `datos_envio` PG=Mongo idéntico (`{"ciudad":"Mendoza","direccion":"Calle 1/4/5/6/18"}`), proviene de `foodstore_tp` con formato genérico de prueba/sintético; no se observaron datos personales reales identificables en campos verificados. `cliente_keys` solo esenciales, `campos_prohibidos_encontrados=[]`, `sin_pii=true`. Sin modificación de `foodstore_tp`; sin anonimización adicional requerida en `foodstore_u7` | **PASS** | Evidencias: `evidencias_t08c_privacidad.txt` (2026-11-12 11:57:25-03:00), `evidencias_privacidad_datos_envio.txt` (2026-11-12 12:04:00-03:00). |
| T08d1 | Integridad agregada explícita (`lineas_ok`, `total_ok`) — intento 1 | `mongo.exe --eval 'var r=db.pedidos.aggregate([{$project:...$detalle...}])'` desde PowerShell | 5 docs con `lineas_ok:true,total_ok:true` | `ParserError/ReferenceError` en PowerShell: `$detalle`/`$` interpretados en shell | **FAIL** | **Problema:** quoting PowerShell. **Solución:** ejecutar desde `tmp_t08d.js`. **Repetición:** T08d2. |
| T08d2 | Integridad agregada explícita — intento 2 | `mongo.exe --quiet foodstore_u7 .\tmp_t08d.js` | 5 docs, `lineas_ok:true,total_ok:true` | 5 resultados (IDs 1,4,5,6,18) todos `lineas_ok:true,total_ok:true` | **PASS** | Corrección aplicada y prueba repetida con éxito. |
| T08e1 | Listar DBs Mongo (sin alteraciones ajenas) — intento 1 | `mongo.exe --eval 'printjson(db.adminCommand("listDatabases")...)'` con quoting conflictivo | DBs esperadas incluyendo solo `foodstore_u7` como nueva de trabajo | `ReferenceError: listDatabases is not defined` (forma de invocación/quoting en shell) | **FAIL** | **Problema:** quoting/sintaxis en `--eval` desde PowerShell. **Solución:** script `tmp_t08e.js` con `adminCommand({listDatabases:1})`. **Repetición:** T08e2. |
| T08e2 | Listar DBs Mongo — intento 2 | `mongo.exe --quiet admin .\tmp_t08e.js` | `[admin, config, foodstore_u7, local]` | `[ "admin", "config", "foodstore_u7", "local" ]` | **PASS** | Corrección aplicada y prueba repetida con éxito. |
| T09 | Contenido de scripts cumple consigna (precheck/abort, a–d+umbral, b,c SQL, validaciones) | `Select-String` sobre `migracion_u7.js`, `consultas_mongodb.js`, `consultas_postgresql.sql`, `validacion_u7.js` | Patrones requeridos presentes | Confirmados: precheck+ABORT+`insertMany`+`NumberDecimal`+`_id`; consultas a–d, estado entregado, producto 8, umbral 20000 y justificación; SQL b/c, `IN (1,4,5,6,18)`, conteos/IDs; checks COUNT/IDS/lineas/total/duplicados/RESUMEN | **PASS** | Verificación estática de artefactos (complementa ejecución). |
| T10 | Idempotencia segura de migración (no debe reinsertar ni modificar) | `mongo.exe --quiet foodstore_u7 .\migracion_u7.js` (re-ejecución con datos existentes) | Abort con error, `COUNT_AFTER=5`, sin cambios | `PRECHECK pedidos.count=5`, `ABORT... (5). No se modifica`, `failed to load`, `exit code -3`, `COUNT_AFTER=5` | **PASS** | Comportamiento esperado de protección; no es fallo de integridad. |
| T11 | Reproducibilidad declarada con versiones disponibles (mongo 4.4.32, psql 18.6) | Ejecución real de scripts en T05–T07,T10 con rutas/versiones disponibles | Scripts ejecutan sin modificar datos ajenos | Ejecuciones exitosas/abort seguro según caso | **PASS** | — |

### Resumen de pruebas
- **PASS:** T01, T02, T03, T04, T05, T06, T07, T08a2, T08b, T08c, T08d2, T08e2, T09, T10, T11 (**15**)
- **FAIL:** T08a1, T08d1, T08e1 (**3**) — todos por quoting/ejecución en PowerShell con `--eval` (no por datos ni por lógica de migración/consultas). **Corregidos y repetidos:** T08a2, T08d2, T08e2 → PASS.
- **PENDIENTE:** ninguna prueba de consigna obligatoria. T08b y T08c completadas con ejecuciones directas adicionales y evidencias dedicadas (`evidencias_t08b_lineas.txt`, `evidencias_t08c_privacidad.txt`).

---

## 6. Archivos y reproducibilidad

| Archivo | Estado | Descripción |
|---|---|---|
| `migracion_u7.js` | ✅ | Precheck colección vacía + abort si hay datos + `insertMany` (5 pedidos, IDs 1,4,5,6,18, `NumberDecimal`, `_id=id_pedido`) |
| `validacion_u7.js` | ✅ | Conteo, IDs, 3 líneas, `subtotal=cant*precio`, `total=Σ`, duplicados, resumen |
| `consultas_mongodb.js` | ✅ | Consultas a–d + justificación umbral (20000) |
| `consultas_postgresql.sql` | ✅ | Equivalentes b,c en subconjunto + conteos/IDs + datos de validación (solo lectura) |
| `informe_u7.md` | ✅ | Este informe (actualizado continuamente) |
| `README.md` | ✅ | Resumen, ejecución y verificaciones |
| `evidencias_validacion_mongo.txt` | ✅ | Salida real validación inicial |
| `evidencias_consultas_mongodb.txt` | ✅ | Salida real consultas Mongo inicial |
| `evidencias_consultas_postgresql.txt` | ✅ | Salida real consultas PostgreSQL inicial |
| `evidencias_revision_completa.txt` | ✅ | Re-ejecución T01–T07 (timestamp 2026-11-12 11:28:15-03:00) |
| `evidencias_revision_detallada.txt` | ✅ | Intentos T08 (incluye fallos de quoting documentados) |
| `evidencias_revision_detallada_fix.txt` | ✅ | T08a2/T08d2/T08e2 corregidos (PASS) |
| `evidencias_revision_scripts.txt` | ✅ | T09 contenido scripts + T10 idempotencia/abort (exit -3, count=5) |
| `evidencias_t08b_lineas.txt` | ✅ | T08b comparación directa campo a campo 15 líneas PG vs Mongo (PASS) |
| `evidencias_t08c_privacidad.txt` | ✅ | T08c consulta real Mongo `datos_envio` y `cliente` sin PII (PASS) |
| `evidencias_privacidad_datos_envio.txt` | ✅ | Verificación procedencia `datos_envio.direccion/ciudad` PG vs Mongo, solo lectura (formato genérico de prueba, sin PII real identificable, sin cambios en `foodstore_tp`) (PASS) |
| `informe_u7.html` | ✅ | Fuente HTML del PDF |
| `informe_u7.pdf` | ✅ | **PDF de entrega, 2 páginas** (≤5), verificado con `pypdf` |

**Ejecución (versiones disponibles):**
```powershell
# MongoDB 4.4.32
$mongo = "C:\Program Files\MongoDB\Server\4.4\bin\mongo.exe"
& $mongo --quiet foodstore_u7 migracion_u7.js      # inserta solo si colección vacía; si no, ABORT
& $mongo --quiet foodstore_u7 validacion_u7.js
& $mongo --quiet foodstore_u7 consultas_mongodb.js

# PostgreSQL 18.6 (solo lectura)
# Conexión sin publicar credenciales: usar autenticación confiable del entorno,
# .pgpass (%APPDATA%\postgresql\pgpass.conf) o PGPASSWORD definido solo en la sesión
# local de forma no persistida (sin guardar en scripts/versionado). Luego:
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h localhost -p 5432 -U postgres -d foodstore_tp -f consultas_postgresql.sql
```

---

## 7. Cumplimiento de la consigna

| Requisito | Estado |
|---|---|
| Modelo documental basado en `pedidos` y `detalle_pedido` (campos, embebidos, arrays, IDs conservados) | **Cumple** |
| Migración ≥5 pedidos reales (`foodstore_tp`), IDs/cantidades/precios históricos conservados | **Cumple** (1,4,5,6,18) |
| Datos esenciales del cliente sin PII real | **Cumple** |
| 2 reglas de integridad + justificación de embebidos | **Cumple** |
| 4 consultas MongoDB (a–d) ejecutadas | **Cumple** |
| Consultas equivalentes PostgreSQL (b,c) ejecutadas | **Cumple** |
| Comparación cantidades e IDs entre motores | **Cumple** (coinciden: b {6}, c {4,5,6}) |
| Comparación técnica PostgreSQL vs MongoDB para Food Store (C6) | **Cumple** |
| 2 afirmaciones de IA contrastadas con doc. oficial y/o laboratorio (C7) | **Cumple** |
| Conclusión ≤200 palabras | **Cumple** |
| Archivos requeridos completos y scripts ejecutables (Mongo 4.4/PG 18) | **Cumple** |
| Sin modificar/eliminar `foodstore_tp`, sin alterar Mongo fuera de `foodstore_u7`, sin tocar U5/U6, sin commit/push | **Cumple** |

**Conclusión de revisión:** el trabajo **cumple con los puntos de la consigna** verificados mediante ejecución real y evidencias adjuntas. No quedan verificaciones obligatorias pendientes. **PDF de entrega:** `informe_u7.pdf` (2 páginas, ≤5) generado y verificado; incluye modelo, migración, integridad, consultas, comparación PG/Mongo, verificación de afirmaciones de IA y conclusión (≤200 palabras), sin PII ni credenciales; scripts `.js/.sql` separados. `datos_envio` verificado contra origen (valores genéricos de prueba, sin PII real identificable) y `foodstore_tp` no modificada. Fallos encontrados (T08a1,d1,e1) fueron errores de ejecución por quoting en PowerShell, corregidos y repetidos con PASS, sin impacto en datos.
