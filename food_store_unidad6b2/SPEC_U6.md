# SPEC_U6.md — Especificación y Plan de Mantenimiento Unidad 6

> **Base de Datos II — Trabajo Práctico Unidad 6: Mantenimiento, respaldo y recuperación**
> **Base objetivo:** `foodstore_tp` (producción) → respaldo → restauración en `foodstore_restore_test`
> **Fecha:** 2026-11-12

---

## 1. Objetivo
Garantizar la recuperabilidad de Food Store mediante:
- Respaldo físico en formato custom (comprimido, paralelo, verificable)
- Monitoreo de salud (`health_check.sql`)
- Mantenimiento programado (`maintenance.sql`)
- Prueba de restauración completa con validación de integridad
- Cálculo y documentación de RPO/RTO reales

---

## 2. Esquema de Food Store (verificado en `foodstore_tp`)
| Tabla | Filas aprox. | Tamaño | Claves / Índices relevantes |
|---|---|---|---|
| `categorias` | 5 | 48 kB | PK `id_categoria` |
| `sucursales` | 3 | 24 kB | PK `id_sucursal` |
| `empleados` | 12 | 40 kB | PK `id_empleado`, FK `id_sucursal`, CHECK `rol_empleado_enum` |
| `clientes` | 2 000 | 568 kB | PK `id_cliente`, CHECK `activo` |
| `productos` | 40 | 64 kB | PK `id_producto`, FK `id_categoria`, CHECK `stock >= 0` |
| `pedidos` | 50 000 | 17 MB | PK `id_pedido`, FK `id_cliente`, `id_sucursal`, `id_empleado_repartidor`, CHECK `estado_pedido_enum` |
| `detalle_pedido` | 150 000 | 16 MB | PK `id_detalle`, FK `id_pedido`, `id_producto`, UNIQUE `(id_pedido, id_producto)`, CHECK `cantidad > 0` |
| `pagos` | 50 000 | 5.9 MB | PK `id_pago`, FK `id_pedido`, CHECK `estado_pago_enum` |

**Vistas heredadas (Unidad 3):** `v_productos_vigentes`, `v_pedidos_cliente`, `v_detalle_pedido`, `v_clientes_publico`, `mv_facturacion_categoria_mes`

**Roles (Unidad 5):** `rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`, `rol_auditoria`, `app_web`, `admin_datos`

---

## 3. Plan de Mantenimiento

| Actividad | Frecuencia | Ventana | Responsable | Script / Comando |
|---|---|---|---|---|
| **Respaldo full (custom, comprimido, paralelo)** | Diaria | 02:00–03:00 | DBA / Automatizado | `backup_foodstore.ps1` |
| **Verificación de integridad del respaldo (`pg_restore -l`)** | Post-respaldo | Inmediato | DBA | `pg_restore -l backup.dump` |
| **Health check (bloat, dead tuples, autovacuum, long tx)** | Diaria | 06:00 | DBA / Monitoreo | `health_check.sql` |
| **ANALYZE completo** | Semanal | Domingo 03:00 | Autovacuum / Manual | `maintenance.sql` |
| **VACUUM (FULL solo si bloat > 30%)** | Mensual / bajo demanda | Ventana de baja carga | DBA | `maintenance.sql` |
| **Refresco de vista materializada** | Tras carga masiva / Diaria | 04:00 | Automatizado | `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;` |
| **Test de restauración en entorno aislado** | Semanal | Sábado 10:00 | DBA | `restore_test.ps1` + validaciones |
| **Revisión de logs y alertas** | Diaria | Continuo | DBA | Logs de `backup_foodstore.ps1`, PostgreSQL |

---

## 4. Políticas de Retención
| Tipo | Retención | Ubicación |
|---|---|---|
| Respaldo full custom (`.dump`) | 30 días (diario) + 12 meses (mensual) | `C:\backups\foodstore\` |
| Logs de respaldo | 90 días | `C:\backups\foodstore\logs\` |
| Logs de restauración/test | 30 días | `C:\backups\foodstore\logs\` |

---

## 5. RPO / RTO Objetivo vs. Observado

| Métrica | Objetivo (SLA) | Cómo se mide |
|---|---|---|
| **RPO** (pérdida máxima de datos tolerada) | ≤ 24 h | `now() - pg_last_xact_replay_timestamp()` en réplica, o antigüedad del último respaldo exitoso |
| **RTO** (tiempo máximo de recuperación) | ≤ 2 h | Tiempo real: `inicio_restauración → fin_validaciones` en test semanal |

> **Nota:** Los valores reales se documentarán en `informe_u6.pdf` tras la ejecución.

---

## 6. Validaciones Post-Restauración (Checklist)
1. Conteo de filas en 8 tablas principales = valores de producción
2. `SELECT count(*) FROM detalle_pedido WHERE cantidad <= 0` → 0
3. `SELECT count(*) FROM productos WHERE stock < 0` → 0
4. FK íntegras: `pedidos.id_cliente → clientes`, `detalle_pedido.id_pedido → pedidos`, etc.
5. Vistas y vista materializada existen y son consultables
6. Roles y permisos (Unidad 5) recreados correctamente
7. Funciones `fn_autenticar`, `fn_resetear_password` operativas

---

## 7. Archivos a Entregar en `food_store_unidad6b2/`
```
food_store_unidad6b2/
├── SPEC_U6.md                    ← este archivo
├── backup_foodstore.ps1          ← respaldo custom + log + errores
├── health_check.sql              ← 4+ controles de monitoreo
├── maintenance.sql               ← autovacuum, ANALYZE, acción justificada
├── restore_test.ps1              ← automatización restauración + validación
├── informe_u6.pdf                ← informe final (1 página máx.)
├── README.md                     ← explicación, ejecución, resultados
├── BITACORA.md                   ← registro proceso, errores, IA
└── evidencias/
    ├── backup.log
    ├── health_check_result.txt
    ├── maintenance_result.txt
    ├── restore.log
    ├── validation_results.txt
    └── capturas/
```

---

## 8. Seguridad y Restricciones
- ❌ **NUNCA** ejecutar `pg_restore` sobre `foodstore_tp`
- ❌ **NUNCA** modificar datos de `foodstore_tp`
- ✅ Respaldo: `pg_dump -Fc -Z 3 -j 4 foodstore_tp`
- ✅ Restauración: solo en `foodstore_restore_test` (base nueva, aislada)
- ✅ Contraseña: variable de entorno `PGPASSWORD` en sesión, **nunca en scripts ni Git**
- ✅ Verificar `current_database()` antes de cada operación