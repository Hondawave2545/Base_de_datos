# DUIA — Documento de Integridad Universitaria Académica

**Proyecto:** Food Store  
**Materia:** Base de Datos II — Tecnicatura Universitaria en Programación  
**Trabajo:** Trabajo Práctico N.º 8 — "Food Store en la feria: la base de la tablet y el cierre de la capa de datos"  
**Carpeta de entrega:** `food_store_unidad8b2`  
**Fecha:** 2026-11-12

---

## Declaración de autoría

Yo, el estudiante del curso Base de Datos II, declaro que el presente Trabajo Práctico N.º 8 (Unidad 8) fue realizado por mí como parte de la cursada, bajo la guía de la docencia de la materia y utilizando como base el trabajo previo iniciado por otro agente (Kilo Code) y continuado y completado por este agente.

El trabajo incluye:
1. **Consigna 1 — SQLite:** esquema `movil/schema_sqlite.sql`, base `foodstore_movil.db`, importación del snapshot a `snapshot_servidor` y `producto_cache`, pruebas `movil/pruebas_sqlite.sql` con casos C1 y C7.
2. **Consigna 2 — Semáforo:** `movil/semaforo.sql` con prioridad `RECHAZADO > CONFLICTO`, casos C2 a C6 ejecutados y verificados, confirmación de que `foodstore_tp` y `foodstore_u8_test` no fueron modificadas.
3. **Consigna 3 — Documentación técnica:** mapa de los tres motores (PostgreSQL, SQLite, MongoDB U7), plan de mantenimiento extendido con tablets, y revisión de código con IA (`bitacora_ia.md`) con hallazgos de múltiples unidades y al menos uno descartado.
4. **Consigna 4 — Entrega:** especificaciones Kiro actualizadas (`requirements.md`, `design.md`, `tasks.md`), bitácora de IA (`bitacora_ia.md`), este DUIA, README actualizado e `informe.pdf` (máximo 6 páginas).

---

## Integridad y originalidad

- El código y los scripts presentados fueron escritos, revisados y probados por el agente que completa este TP, salvo las partes documentadas como preexistentes (trabajo de Kilo Code: vista `v_snapshot_movil`, CSV `servidor_snapshot.csv`, base sintética `foodstore_u8_test`).
- No se copió trabajo de terceros estudiantes ni de fuentes externas sin la debida cita.
- Se respetó la regla de oro: **el móvil propone, el servidor dispone**. La tablet (SQLite) nunca modifica `foodstore_tp` ni inserta en `pedidos` de PostgreSQL.
- No se incluyeron contraseñas, credenciales ni secretos en ningún archivo del repositorio. El valor de la contraseña de `postgres` no se transcribe en ningún documento (se documenta el incidente de seguridad sin revelar el valor).

---

## Datos y privacidad

- Todas las pruebas utilizan bases de datos sintéticas con datos inventados (`foodstore_u8_test`), sin datos personales reales ni PII.
- La base de producción `foodstore_tp` se preservó intacta (40 productos, 2000 clientes, 50000 pedidos).

---

## Unidades preservadas

Se preservaron todas las unidades anteriores, en particular:
- `food_store_unidad6b2/informe_u6.pdf`
- Unidades 1 a 7 del repositorio.

---

## Firma

Firma del estudiante: _______________________________  
Fecha: 2026-11-12  
Curso: Base de Datos II — Tecnicatura Universitaria en Programación
