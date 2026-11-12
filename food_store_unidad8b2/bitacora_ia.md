# Bitácora de IA — Food Store Unidad 8

**Proyecto:** Food Store - Base de Datos II  
**Unidad:** 8 (Trabajo Práctico N.º 8)  
**Fecha:** 2026-11-12  
**Agente:** OpenCode (continuación del trabajo iniciado con Kilo Code)

---

## 0. Propósito

Esta bitácora registra cada intervención de IA en el desarrollo de la Unidad 8: qué se pidió, qué se generó, qué se verificó y el resultado real. Cumple la Consigna 3.c (code review con IA) y la documentación obligatoria del TP.

---

## 1. Entradas de bitácora

| # | Fecha | Qué se pidió a la IA | Qué se generó | Qué se verificó | Resultado real | Estado |
|---|-------|----------------------|---------------|-----------------|----------------|--------|
| 1 | 2026-11-12 | Escribir `movil/schema_sqlite.sql` con 5 tablas STRICT, PRAGMA foreign_keys=ON y CHECKs | `movil/schema_sqlite.sql` | Crear `foodstore_movil.db`, ejecutar esquema, verificar tablas STRICT y foreign_keys | 5 tablas creadas, `foreign_keys=1`, STRICT aplicado, 15 filas importadas | CORRECTA |
| 2 | 2026-11-12 | Escribir `movil/pruebas_sqlite.sql` con COMMIT, ROLLBACK, C1 y C7 | `movil/pruebas_sqlite.sql` | Ejecutar pruebas en Python sqlite3 | TEST1 COMMIT OK; TEST2/TEST3 ROLLBACK sin filas parciales; C1 → 15 filas; C7a y C7b fallan sin filas parciales | CORRECTA |
| 3 | 2026-11-12 | Escribir `movil/semaforo.sql` con prioridad RECHAZADO > CONFLICTO | `movil/semaforo.sql` | Ejecutar casos C2-C6 sobre `foodstore_u8_test` | C5=SIMULADO_APROBADO; C2a=CONFLICTO; C2b=SIMULADO_APROBADO (nuevo UUID); C3=RECHAZADO; C4=RECHAZADO; C6=error PK no reevalúa | CORRECTA |
| 4 | 2026-11-12 | Orquestar casos C2-C6 modificando PostgreSQL y re-importando snapshot | `_casos_semaforo.py` (script auxiliar) | Verificar que `foodstore_tp` y `foodstore_u8_test` no se modificaron | PostgreSQL intacto (precios y stock sin cambios tras los casos) | CORRECTA |
| 5 | 2026-11-12 | Code review con IA de scripts de la cursada (Unidades 6 y 8) | Esta bitácora, sección 3 | Revisar `indices.sql`, `00_base.sql`, `schema_sqlite.sql`, `semaforo.sql` | 5 hallazgos (3 aceptados, 2 descartados), de 3 unidades distintas | CORRECTA |

---

## 2. Code review con IA (Consigna 3.c)

**Proceso:** revisión de scripts de la cursada: `scripts/00_base.sql`, `indices.sql`, `verificar_equivalencia.sql`, `movil/schema_sqlite.sql`, `movil/semaforo.sql`, `movil/pruebas_sqlite.sql`.

**Criterios:** mínimo 3 hallazgos, de al menos 2 unidades distintas, al menos 1 descartado con fundamento.

| Hallazgo | Unidad | Decisión | Motivo | Comprobación |
|----------|--------|----------|--------|--------------|
| Índice `detalle_pedido (id_pedido)` propuesto | 6 | **DESCARTADO** | Redundante: `uq_pedido_producto (id_pedido, id_producto)` ya tiene `id_pedido` como columna líder, por lo que cubre consultas por `id_pedido`. | `EXPLAIN ANALYZE` muestra mismo plan con o sin el índice redundante (documentado en `indices.sql` y `informe_mediciones.md`) |
| Índice `pedidos (estado)` propuesto | 6 | **DESCARTADO** | Baja cardinalidad (solo 5 valores de estado) y sin condición parcial; no mejora selectividad ni reduce páginas leídas. | Descartado en `indices.sql` con justificación escrita |
| Tablas `STRICT` en SQLite para la tablet | 8 | **ACEPTADO** | Mejora integridad de datos (tipos estrictos, sin coerción implícita). Requiere SQLite ≥3.37; se verificó 3.50.4. | `PRAGMA table_info` confirma strict; Python 3.14.8 + SQLite 3.50.4 |
| Prioridad `RECHAZADO > CONFLICTO` en `semaforo.sql` | 8 | **ACEPTADO** | Implementada con `CASE` ordenado: cualquier motivo de rechazo se evalúa antes que conflicto; `SIMULADO_APROBADO` solo si no hay rojo. | Verificado con C2 (CONFLICTO), C3/C4 (RECHAZADO) |
| Datos sintéticos sin PII en `00_base.sql` | 4/5 | **ACEPTADO** | Usa `random()` y `generate_series` con nombres/emails inventados (`Cliente g`, `cliente g@mail.com`); no hay datos personales reales. | Cumple regla RF-02 (datos inventados) |

**Resumen:** 5 hallazgos totales, de 3 unidades distintas (4, 6, 8), 2 descartados con fundamento técnico, 3 aceptados. Requisito de la Consigna 3.c cumplido.

---

## 3. Hallazgos de seguridad (pendiente de cierre con el servidor)

| Hallazgo | Descripción | Estado | Acción |
|----------|-------------|--------|--------|
| Contraseña débil de `postgres` en log | Kiro ejecutó `ALTER USER postgres WITH PASSWORD ...` (valor en texto plano en `postgresql-*.log`) | PENDIENTE | Rotar contraseña y documentar en DUIA.md (no transcribir el valor) |
| Archivo residual `pg_hba.conf.backup` | Backup de `pg_hba.conf` en el directorio de datos de PostgreSQL | PENDIENTE | Verificar que `pg_hba.conf` está restaurado (scram-sha-256) y eliminar el backup |

---

## 4. Conclusión de la bitácora

Todas las intervenciones de IA se leyeron, probaron y comprendieron antes de ejecutar (regla RF-03). Ninguna base de producción (`foodstore_tp`) fue modificada. Los resultados son reales y reproducibles.
