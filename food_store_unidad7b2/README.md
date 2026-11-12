# Unidad 7 — NoSQL y nuevas formas de almacenamiento (Food Store)

Implementación y **revisión completa** del TP Unidad 7: subconjunto **pedidos + detalle de pedidos** de `foodstore_tp` (PostgreSQL) modelado y consultado en MongoDB, con comparación verificable y evidencias reales.

> **Repositorio canónico:** `C:\Users\aquin\AppData\Local\Temp\kilo\Base_de_datos` — remote `https://github.com/Hondawave2545/Base_de_datos.git` (branch `main`)  
> **Carpeta exclusiva:** `food_store_unidad7b2/`  
> **Estado de entrega:** sin commit/push; sin modificación de Unidades 5 y 6; `foodstore_tp` solo lectura; MongoDB alterado únicamente en `foodstore_u7`.

## Entorno

| Componente | Detalle |
|---|---|
| PostgreSQL | 18.6, `localhost:5432`, BD `foodstore_tp` (**solo lectura**) |
| MongoDB | Server 4.4.32 (servicio Running), shell `C:\Program Files\MongoDB\Server\4.4\bin\mongo.exe` v4.4.32 |
| Base/colección U7 | `foodstore_u7.pedidos` (5 documentos, IDs 1,4,5,6,18) |

## Modelo documental

- 1 documento = 1 pedido completo. `_id = id_pedido` (conservado).
- **Embebido:** `cliente` esencial sin PII (`id_cliente`, `cliente_ref`, `fecha_registro`, `activo`) y `detalle[]` con `id_detalle`, `id_producto`, `producto_nombre`, `cantidad`, `precio_unitario` y `subtotal` históricos.
- **Importes:** `NumberDecimal` (precisión `numeric(10,2)`); `datos_envio` conservado; IDs de origen preservados.

## Reglas de integridad

1. **Consistencia monetaria histórica:** `subtotal = cantidad × precio_unitario` por línea y `total = Σ(subtotales)` (sin recalcular con precios actuales).
2. **Integridad/completitud:** `id_pedido`/`id_detalle`/`id_producto`/IDs origen conservados, líneas reales completas, estado/tipo válidos, cantidades e importes > 0.

## Archivos

| Archivo | Descripción |
|---|---|
| `migracion_u7.js` | Precheck (colección vacía, abort si hay datos) + `insertMany` 5 pedidos reales |
| `validacion_u7.js` | Conteo, IDs, 3 líneas c/u, integridad montos, duplicados |
| `consultas_mongodb.js` | Consultas a–d + justificación umbral (>20000) |
| `consultas_postgresql.sql` | Equivalentes b,c en subconjunto + validación (solo lectura) |
| `informe_u7.md` | Informe completo: modelo, migración, consultas, comparación, IA/contraste, conclusión y registro de pruebas |
| `evidencias_validacion_mongo.txt` | Salida real validación inicial |
| `evidencias_consultas_mongodb.txt` | Salida real consultas Mongo inicial |
| `evidencias_consultas_postgresql.txt` | Salida real consultas PostgreSQL inicial |
| `evidencias_revision_completa.txt` | Re-ejecución completa T01–T07 (2026-11-12 11:28:15-03:00) |
| `evidencias_revision_detallada.txt` | Intentos detallados (incluye fallos de quoting documentados) |
| `evidencias_revision_detallada_fix.txt` | Correcciones T08a2/T08d2/T08e2 (PASS) |
| `evidencias_revision_scripts.txt` | Verificación de scripts (T09) + idempotencia/abort (T10) |
| `evidencias_t08b_lineas.txt` | T08b: comparación directa campo a campo 15 líneas PG vs Mongo (PASS) |
| `evidencias_t08c_privacidad.txt` | T08c: consulta real Mongo `datos_envio` y `cliente` sin PII (PASS) |
| `evidencias_privacidad_datos_envio.txt` | Verificación procedencia `datos_envio.direccion/ciudad` (PG vs Mongo, solo lectura) — formato genérico de prueba, sin PII real identificable (PASS) |
| `informe_u7.html` | Fuente HTML del PDF de entrega |
| `informe_u7.pdf` | **PDF de entrega (2 páginas, ≤5)** |

## Ejecución (versiones disponibles)

```powershell
# MongoDB 4.4.32 (solo base foodstore_u7)
$mongo = "C:\Program Files\MongoDB\Server\4.4\bin\mongo.exe"
& $mongo --quiet foodstore_u7 migracion_u7.js      # inserta solo si vacía; si hay datos: ABORT (exit -3)
& $mongo --quiet foodstore_u7 validacion_u7.js
& $mongo --quiet foodstore_u7 consultas_mongodb.js

# PostgreSQL 18.6 (solo lectura, foodstore_tp)
# Conexión sin publicar credenciales: usar autenticación confiable del entorno,
# archivo .pgpass (%APPDATA%\postgresql\pgpass.conf), o definir PGPASSWORD en la sesión
# local sin guardarlo en scripts/versionado (ej.: $env:PGPASSWORD = Read-Host -AsSecureString
# o variable de entorno temporal no persistida). Luego:
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h localhost -p 5432 -U postgres -d foodstore_tp -f consultas_postgresql.sql
```

## Resumen de verificaciones (revisión completa)

| ID | Prueba | Estado | Resultado real |
|---|---|---|---|
| T01 | Repo canónico/remote y alcance U7 | **PASS** | Remote `Base_de_datos.git`; solo `food_store_unidad7b2/` (y `informe_u6.html` untracked ajeno) |
| T02 | Archivos requeridos + evidencias presentes | **PASS** | Todos presentes |
| T03 | PostgreSQL sin modificaciones | **PASS** | `pedidos=50000`, `detalle_pedido=150000` |
| T04 | Estado Mongo (`foodstore_u7` única afectada) | **PASS** | `count=5`, IDs `[1,4,5,6,18]` |
| T05 | Re-ejecución `validacion_u7.js` | **PASS** | `count_ok,ids_ok,lineas_ok,total_match_all,lineas_calc_all,sin_duplicados=true` |
| T06 | Re-ejecución `consultas_mongodb.js` (a–d) | **PASS** | a:5; b:{6}; c:{4,5,6}; d:{1,5,6,18} (umbral 20000) |
| T07 | Re-ejecución `consultas_postgresql.sql` (b,c) | **PASS** | b:1/{6}; c:3/{4,5,6}; datos origen coinciden |
| T08a1 | Contraste detallado PG/Mongo (intento 1) | **FAIL** | Error quoting PowerShell `$toString` en `--eval` |
| T08a2 | Contraste detallado PG/Mongo (repetición) | **PASS** | Estados/totales/fechas coherentes (ver evidencia fix) |
| T08b | Comparación directa 15 líneas (id_detalle,id_producto,cantidad,precio_unitario,subtotal) PG vs Mongo | **PASS** | 15/15 líneas coinciden exactamente (`pg_count=15,mongo_count=15,diff_count=0,all_15_match=True`; ver `evidencias_t08b_lineas.txt`) |
| T08c | Consulta real Mongo: `datos_envio` y `cliente` sin PII + verificación procedencia `datos_envio` en PG | **PASS** | 5/5 docs: `cliente_keys=[activo,cliente_ref,fecha_registro,id_cliente]`, sin campos prohibidos, `sin_pii=true`. `datos_envio` (PG=Mongo): `{"ciudad":"Mendoza","direccion":"Calle 1/4/5/6/18"}`; proviene de `foodstore_tp`, formato genérico de prueba, sin datos personales reales identificables; sin anonimización adicional ni cambios en `foodstore_tp` (ver `evidencias_t08c_privacidad.txt`, `evidencias_privacidad_datos_envio.txt`) |
| T08d1 | Agregación integridad explícita (intento 1) | **FAIL** | Error quoting PowerShell `$detalle` en `--eval` |
| T08d2 | Agregación integridad explícita (repetición) | **PASS** | 5/5 `lineas_ok:true,total_ok:true` |
| T08e1 | Listado DBs Mongo (intento 1) | **FAIL** | Error quoting/sintaxis en `--eval` |
| T08e2 | Listado DBs Mongo (repetición) | **PASS** | `[admin,config,foodstore_u7,local]` |
| T09 | Contenido de scripts cumple consigna | **PASS** | Precheck/abort, a–d+umbral, b/c SQL, checks presentes |
| T10 | Idempotencia segura migración | **PASS** | Re-ejecución: `ABORT`, exit `-3`, `COUNT_AFTER=5` |
| T11 | Reproducibilidad con versiones disponibles | **PASS** | Scripts ejecutados OK (Mongo 4.4, PG 18) |

**Totales:** PASS **15** | FAIL **3** (todos por quoting PowerShell en `--eval`, corregidos y repetidos → PASS) | PENDIENTE **0**.

## Estado final
- **PDF de entrega:** `informe_u7.pdf` — **2 páginas** (≤5), verificado con `pypdf`. Incluye modelo, migración, integridad, consultas, comparación PG/Mongo, verificación afirmaciones IA y conclusión (≤200 palabras), con resultados concretos, sin PII ni credenciales. Scripts `.js/.sql` separados.
- **Archivos requeridos en carpeta:** `migracion_u7.js`, `validacion_u7.js`, `consultas_mongodb.js`, `consultas_postgresql.sql`, `informe_u7.md`, `README.md`, `informe_u7.pdf` y evidencias (.txt) presentes.
- **Sin commit/push.** `foodstore_tp` no modificada; MongoDB alterado únicamente en `foodstore_u7`; Unidades 5 y 6 intactas.

## Notas

- No se incluyen credenciales ni datos personales reales. `datos_envio` verificado contra origen: valores genéricos de prueba (no PII real identificable); `cliente` embebido sin PII.
- `evidencias_revision_detallada.txt` conserva los intentos fallidos (T08a1/d1/e1) y sus mensajes; `evidencias_revision_detallada_fix.txt` contiene las repeticiones corregidas.
- No se realizó commit/push.
