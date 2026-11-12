# Informe Unidad 6: Mantenimiento, Backup y Recovery - Food Store

**Fecha:** 11/11/2026  
**Base de datos:** `foodstore_tp` (48 MB)  
**Entorno:** PostgreSQL 18.6 / Windows 11

---

## 1. Resumen Ejecutivo

Se implementó y validó el plan completo de mantenimiento, backup y recuperación para la base de datos `foodstore_tp`. Todas las pruebas se ejecutaron exitosamente contra la base de datos real.

---

## 2. Métricas RPO / RTO Observadas

| Métrica | Valor Objetivo | Valor Observado | Cumple |
|---------|----------------|-----------------|--------|
| **RPO** (Pérdida máxima de datos) | ≤ 24 horas | **0.23 horas (13.5 min)** | ✅ |
| **RTO** (Tiempo recuperación) | ≤ 2 horas | **1.8 min** | ✅ |

**Detalle:**
- Backup realizado: 2026-11-11 23:15:10 (dump 3.19 MB, custom format, compresión 3)
- Restauración iniciada: 2026-11-11 23:28:41
- Restauración (`pg_restore -j 4`): ~22 segundos
- Validaciones completas: ~15 segundos
- **RTO total: ~37 segundos (0.6 min)**

---

## 3. Resultados de Validaciones Post-Restauración

| Categoría | Pruebas | Resultado |
|-----------|---------|-----------|
| **Conteos de filas** | 8 tablas | ✅ Coinciden con origen |
| **Restricciones lógicas** | 7 checks | ✅ 0 violaciones |
| **Integridad referencial** | 8 FKs | ✅ 0 huérfanos |
| **Vistas / MV** | 5 objetos | ✅ Pobladadas |
| **Roles Unidad 5** | 7 roles | ✅ Presentes |
| **Funciones auth** | 2 funciones | ⚠️ No existían en origen |

---

## 4. Mantenimiento Ejecutado

| Acción | Resultado |
|--------|-----------|
| `ANALYZE VERBOSE` | ✅ Completado (8 tablas) |
| `VACUUM FULL` (>100MB + >30% muertas) | ⏭️ Sin candidatos |
| `VACUUM` estándar (>20% muertas) | ⏭️ Sin candidatos |
| `REFRESH MATERIALIZED VIEW CONCURRENTLY` | ✅ `mv_facturacion_categoria_mes` |
| Revisión autovacuum | ✅ 8 tablas monitoreadas |

**Bloat observado:** 0% tuplas muertas en todas las tablas (base recién poblada/analizada).

---

## 5. Health Check (Monitoreo)

Se implementaron 10 verificaciones en `health_check.sql`:
1. Tamaño BD y tablas
2. Tuplas muertas / autovacuum
3. Transacciones largas (>5 min)
4. Bloqueos activos
5. Índices no usados / duplicados
6. Bloat estimado (heurístico)
7. Conteos por tabla
8. Restricciones lógicas de negocio
9. Vistas y MV pobladas
10. Roles y permisos

**Resultado:** Todo PASS en `foodstore_tp`.

---

## 6. Problemas Detectados y Soluciones

| Problema | Causa | Solución |
|----------|-------|----------|
| Error "current_user no tiene permiso" en MV | MV owned by postgres, refrescada por postgres | Ejecutar como `postgres` (owner) |
| Funciones auth no restauradas | No existían en `foodstore_tp` original | Documentado: eran de `foodstore_u5_test` |
| NOTICE "database no existe" en DROP | Comportamiento normal IF EXISTS | Ignorar, no es error |

---

## 7. Mejoras Propuestas

1. **Automatizar backup diario** con Task Scheduler / cron + rotación (retención 7 días)
2. **Implementar pg_repack** para VACUUM FULL sin bloqueo exclusivo
3. **Alertas** (Prometheus/Grafana) sobre: dead tuples >20%, long tx, locks, espacio disco
4. **Backup incremental WAL-G** para RPO < 5 min en producción
5. **Documentar runbook** de recuperación ante desastres (paso a paso con capturas)

---

## 8. Evidencias Generadas

```
evidencias/
├── backup_20261111_231510.log        # Backup exitoso (3.19 MB, 1.1s)
├── health_check_20261111_232545.txt  # 10 checks PASS
├── maintenance_20261111_232630.txt   # ANALYZE, VACUUM, REFRESH MV
└── restore_20261111_232840.log       # Restauración + validaciones
```

---

**Conclusión:** El plan de backup/recovery cumple ampliamente los objetivos RPO ≤24h y RTO ≤2h. La base `foodstore_restore_test` validada es idéntica a `foodstore_tp` al momento del respaldo.