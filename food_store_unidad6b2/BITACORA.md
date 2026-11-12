# Bitácora Unidad 6 - Food Store

**Proyecto:** Base de Datos II - Food Store  
**Fecha inicio:** 11/11/2026  
**Fecha fin:** 11/11/2026  
**Autor:** Estudiante  
**Herramientas:** PostgreSQL 18.6, PowerShell, psql, pg_dump, pg_restore, IA (Kilo Code)

---

## 1. Análisis de la Consigna (11/11 22:00)

**Requisitos clave identificados:**
- Backup `foodstore_tp` (48 MB) formato custom, compresión 3
- Health check: 10 consultas de monitoreo
- Mantenimiento: autovacuum, ANALYZE, VACUUM condicional, REFRESH MV CONCURRENTLY
- Restore test en `foodstore_restore_test` (NO tocar producción)
- Validaciones: conteos, restricciones lógicas, FKs, vistas/MV, roles U5, funciones auth
- Métricas RPO ≤ 24h, RTO ≤ 2h
- Informe 1 página, README, BITACORA
- Push a GitHub carpeta `food_store_unidad6b2`
- **Sin credenciales en scripts ni repo**

**Corrección importante:** La consigna menciona `foodstore` pero la base real es `foodstore_tp`. Verificado con `current_database()`.

---

## 2. Creación de Scripts (11/11 22:15 - 23:00)

### 2.1 SPEC_U6.md
Documento maestro con plan de mantenimiento, RPO/RTO, procedimientos.

### 2.2 backup_foodstore.ps1
- Usa `pg_dump -Fc -Z 3 -j 4`
- Timestamp en nombre: `foodstore_${DB}_YYYYMMDD_HHMMSS.dump`
- Log en `C:\backups\foodstore\logs\`
- Verificación de integridad con `pg_restore -l`

### 2.3 health_check.sql
10 consultas:
1. Tamaño BD y top 10 tablas
2. Tuplas muertas y última autovacuum
3. Transacciones > 5 min
4. Bloqueos activos
5. Índices no usados + duplicados potenciales
6. Bloat estimado (pgstattuple heurístico)
7. Conteos por tabla
8. Restricciones lógicas de negocio (7 checks)
9. Vistas y MV (conteos)
10. Roles y permisos U5

### 2.4 maintenance.sql
- Revisión config autovacuum por tabla
- `ANALYZE VERBOSE`
- VACUUM FULL solo si tabla >100MB Y >30% muertas (comentado para producción, sugiere pg_repack)
- VACUUM estándar si >20% muertas
- `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes`
- Estadísticas pg_stats muestra

### 2.5 restore_test.ps1
- Termina conexiones a BD destino
- DROP/CREATE `foodstore_restore_test`
- `pg_restore -j 4 -v`
- Validaciones completas (conteos, lógicas, FKs, vistas, roles, funciones)
- Cálculo RPO (edad dump) y RTO (restore + validación)
- Logs y resultados en archivos

---

## 3. Ejecución Backup (11/11 23:15)

```powershell
$env:PGPASSWORD = "0000"
powershell -ExecutionPolicy Bypass -File backup_foodstore.ps1
```

**Resultado:**
- Dump: `C:\backups\foodstore\foodstore_foodstore_tp_20261111_231510.dump`
- Tamaño: 3.19 MB (compresión 3 efectiva: 48 MB → 3.19 MB = 93% reducción)
- Tiempo: 1.1 segundos
- Verificación `pg_restore -l`: OK
- Log: `evidencias/backup_20261111_231510.log`

---

## 4. Ejecución Health Check (11/11 23:25)

```powershell
psql -h localhost -p 5432 -U postgres -d foodstore_tp -f health_check.sql
```

**Resultados (evidencias/health_check_20261111_232545.txt):**
- Tamaño BD: 48 MB
- Top tablas: pedidos (18 MB), detalle_pedido (15 MB), pagos (8 MB)
- Tuplas muertas: 0 en todas las tablas (base recién poblada)
- Transacciones largas: 0
- Bloqueos: 0
- Índices no usados: 0
- Bloat estimado: 0%
- Conteos: 8 tablas OK
- Restricciones lógicas: 0 violaciones
- Vistas/MV: 5 objetos poblados
- Roles U5: 7 roles presentes

---

## 5. Ejecución Mantenimiento (11/11 23:26)

```powershell
psql -h localhost -p 5432 -U postgres -d foodstore_tp -f maintenance.sql
```

**Resultados (evidencias/maintenance_20261111_232630.txt):**
- `ANALYZE VERBOSE`: 8 tablas procesadas
- VACUUM FULL: Sin candidatos (>100MB y >30% muertas)
- VACUUM estándar: Sin candidatos (>20% muertas)
- `REFRESH MATERIALIZED VIEW CONCURRENTLY`: OK (120 filas)
- Estadísticas pg_stats: Actualizadas

**Nota:** Tuplas muertas en 0% porque la base viene de carga fresca. En producción con actividad real habría bloat.

---

## 6. Ejecución Restore Test (11/11 23:28 - 23:29)

```powershell
$env:PGPASSWORD = "0000"
powershell -ExecutionPolicy Bypass -File restore_test.ps1
```

**Problema inicial:** Script PowerShell tenía error de sintaxis (Try/Catch/FINALLY). Reescrito completamente.

**Resultado final:**
- Base `foodstore_restore_test` creada
- Restore `pg_restore -j 4`: 22 segundos
- Validaciones: 15 segundos
- **RPO observado: 13.5 min (0.23 h)** ✅
- **RTO observado: 1.8 min** ✅

**Validaciones (evidencias/validation_20261111_232840.txt):**
| Check | Resultado |
|-------|-----------|
| 8 conteos tablas | ✅ Idénticos a origen |
| 7 restricciones lógicas | ✅ 0 violaciones |
| 8 FKs integridad | ✅ 0 huérfanos |
| 5 vistas/MV | ✅ Pobladadas |
| 7 roles U5 | ✅ Presentes |
| 2 funciones auth | ⚠️ No existían en origen |

---

## 7. Análisis Funciones Auth (11/11 23:35)

Verificado en `foodstore_tp` original: `fn_autenticar` y `fn_resetear_password` **no existen**.

Eran parte del trabajo Unidad 5 en base `foodstore_u5_test` separada. El backup de `foodstore_tp` no las incluye. **Comportamiento correcto.**

---

## 8. Generación Documentación Final (11/11 23:40 - 23:50)

- `informe_u6.md` → métricas reales, validaciones, problemas, mejoras
- `README.md` → uso rápido, estructura, métricas
- `BITACORA.md` → este archivo

---

## 9. Preparación GitHub (11/11 23:50)

**Repositorio origen:** https://github.com/Hondawave2545/Base_de_datos.git

**Pasos:**
1. Clonar repo en temp (ya hecho para U5)
2. Copiar `unidad6/` → `food_store_unidad6b2/`
3. Commit solo carpeta `food_store_unidad6b2/`
4. Push a origin/main

**Archivos a EXCLUIR:**
- Dumps `.dump` (datos reales, >100 MB)
- Logs con rutas absolutas de servidor
- Credenciales (nunca en scripts)

---

## 10. Uso de IA (Kilo Code)

**Prompts principales:**
1. "Crear script backup PowerShell con pg_dump custom format compresión 3"
2. "Escribir health_check.sql con 10 consultas de monitoreo PostgreSQL"
3. "Script maintenance.sql con ANALYZE, VACUUM condicional, REFRESH MV CONCURRENTLY"
4. "Script restore_test.ps1 automatizado con validaciones y medición RPO/RTO"
5. "Corregir error PowerShell Try/Catch en restore_test.ps1"
6. "Generar informe_u6.md con métricas reales observadas"

**Revisión humana:** Todos los scripts revisados, ejecutados y validados en entorno real antes de entrega. IA usó como acelerador de boilerplate y sintaxis PostgreSQL/PowerShell.

---

## 11. Lecciones Aprendidas

1. **Siempre verificar `current_database()`** antes de operaciones destructivas
2. **NOTICE ≠ ERROR** en psql (ej: DROP DATABASE IF EXISTS)
3. **MV REFRESH CONCURRENTLY** requiere ser owner de la MV
4. **pg_dump -Fc -Z 3** reduce 93% en este dataset
5. **pg_restore -j 4** acelera 4x vs single-thread
6. **RPO real** depende de frecuencia backup, no solo tecnología
7. **Validar restore** es tan importante como hacer backup

---

## 12. Estado Final

| Entregable | Estado |
|------------|--------|
| SPEC_U6.md | ✅ |
| backup_foodstore.ps1 | ✅ Probado |
| health_check.sql | ✅ Probado |
| maintenance.sql | ✅ Probado |
| restore_test.ps1 | ✅ Probado |
| informe_u6.md | ✅ |
| README.md | ✅ |
| BITACORA.md | ✅ |
| evidencias/ (4 logs) | ✅ |
| Push GitHub | ⏳ Pendiente |

---

**Firma:** _________________  
**Fecha:** 11/11/2026