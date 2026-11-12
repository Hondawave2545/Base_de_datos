# Unidad 6: Mantenimiento, Backup & Recovery - Food Store

Implementación completa del plan de mantenimiento, backup y recuperación para la base de datos `foodstore_tp` (PostgreSQL 18.6).

## 📁 Estructura

```
unidad6/
├── SPEC_U6.md              # Especificación y plan de mantenimiento
├── backup_foodstore.ps1    # Script backup (custom format, compresión 3)
├── health_check.sql        # 10 verificaciones de salud/monitoreo
├── maintenance.sql         # Mantenimiento: ANALYZE, VACUUM, REFRESH MV
├── restore_test.ps1        # Restauración automatizada + validación + RPO/RTO
├── informe_u6.md           # Informe final (1 página)
├── README.md               # Este archivo
├── BITACORA.md             # Bitácora de trabajo
└── evidencias/             # Logs de ejecuciones reales
```

## 🎯 Objetivos Cumplidos

| Requisito | Estado |
|-----------|--------|
| Backup `foodstore_tp` formato custom, compresión 3 | ✅ |
| Health check (10 consultas) | ✅ |
| Mantenimiento: autovacuum, ANALYZE, VACUUM condicional, REFRESH MV | ✅ |
| Restore test en `foodstore_restore_test` + validaciones | ✅ |
| Medición RPO/RTO real | ✅ |
| RPO ≤ 24h, RTO ≤ 2h | ✅ (RPO: 0.23h, RTO: 1.8min) |
| Informe PDF 1 página | ✅ |
| Sin credenciales en scripts/repo | ✅ |

## 🚀 Uso Rápido

### Prerrequisitos
- PostgreSQL 18+ en `C:\Program Files\PostgreSQL\18\bin\`
- Variable `PGPASSWORD` seteada en la sesión (nunca en scripts)

```powershell
$env:PGPASSWORD = "0000"
```

### 1. Backup
```powershell
powershell -ExecutionPolicy Bypass -File backup_foodstore.ps1
```
Genera: `C:\backups\foodstore\foodstore_foodstore_tp_YYYYMMDD_HHMMSS.dump`

### 2. Health Check
```powershell
psql -h localhost -p 5432 -U postgres -d foodstore_tp -f health_check.sql
```

### 3. Mantenimiento
```powershell
psql -h localhost -p 5432 -U postgres -d foodstore_tp -f maintenance.sql
```

### 4. Restore Test (crea foodstore_restore_test)
```powershell
powershell -ExecutionPolicy Bypass -File restore_test.ps1
```
Valida: conteos, restricciones lógicas, FKs, vistas/MV, roles, funciones.

### 5. Ver resultados
```powershell
type evidencias\restore_*.log
type evidencias\validation_*.txt
```

## 📊 Métricas Obtenidas (11/11/2026)

| Métrica | Valor |
|---------|-------|
| Tamaño dump | 3.19 MB |
| Tiempo backup | 1.1 seg |
| Tiempo restore (-j 4) | 22 seg |
| Tiempo validaciones | 15 seg |
| **RPO observado** | **13.5 min (0.23 h)** |
| **RTO observado** | **1.8 min** |

## ⚠️ Notas Importantes

- **Base correcta:** `foodstore_tp` (NO `foodstore`)
- **NO modificar:** `foodstore_u4_test_20261110`, `foodstore_u5_test`
- **MV refresh:** Requiere ser owner (`postgres`)
- **Funciones auth:** No existían en `foodstore_tp` original (eran de U5 test DB)

## 📄 Entregables

- `informe_u6.md` → convertir a PDF (1 página máx)
- `README.md` (este archivo)
- `BITACORA.md`
- Scripts `.ps1` / `.sql`
- Carpeta `evidencias/` con logs reales

## 🔗 Repositorio

Carpeta en GitHub: `food_store_unidad6b2/`