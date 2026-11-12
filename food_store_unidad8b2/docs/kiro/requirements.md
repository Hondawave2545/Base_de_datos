# Requirements Specification - Food Store Unidad 8

**Proyecto:** Food Store - Unidad 8: La base de la tablet y el cierre de la capa de datos
**Fecha:** 2026-11-12
**Versión:** 2.0 (corregida tras revisión Unidad 7 real)

---

## Formato EARS

Cada requisito usa notación EARS: **WHEN** [condición] **THE SYSTEM SHALL** [respuesta]

---

### REQ-01: Catálogo de productos en la tablet (offline)

**WHEN** el food truck opera en la feria sin señal de red  
**THE SYSTEM SHALL** permitir consultar el catálogo de productos disponibles (nombre, precio en centavos, stock visto, disponibilidad) desde la base SQLite local sin conexión al servidor.

**Caso de prueba:** C1 (Consigna 1.c) - La consulta `SELECT * FROM producto_cache WHERE disponible = 1 AND eliminado = 0` retorna filas y no requiere conexión a PostgreSQL.

---

### REQ-02: Creación de borradores de pedido con transacción atómica

**WHEN** el vendedor arma un pedido en la tablet  
**THE SYSTEM SHALL** guardar el borrador (pedido_borrador + item_borrador + cola_sync) en una sola transacción SQLite (BEGIN...COMMIT), validando claves foráneas, precios no negativos, cantidades > 0 y forma de pago permitida (EFECTIVO, TARJETA, TRANSFERENCIA). Si falla, hacer ROLLBACK y no dejar filas parciales.

**Caso de prueba:** Consigna 1.c ítem 1 - Un borrador completo se guarda con COMMIT; otro con cantidad 0 o producto inexistente falla con ROLLBACK y no deja filas nuevas (C7).

---

### REQ-03: Semáforo de sincronización (clasificación de solicitudes)

**WHEN** la tablet recupera señal y envía solicitudes PENDIENTES al servidor  
**THE SYSTEM SHALL** comparar cada solicitud contra `snapshot_servidor` (copia de `v_snapshot_movil`) y clasificarla en `cola_sync` como:
- **RECHAZADO** (rojo): algún producto no existe, no está disponible, fue dado de baja lógica o no alcanza stock
- **CONFLICTO** (amarillo): no hay rojo, pero cambió algún precio (precio_centavos_visto ≠ precio_centavos)
- **SIMULADO_APROBADO** (verde): todo coincide

**Prioridad:** RECHAZADO tiene prioridad sobre CONFLICTO (si hay rojo, no se evalúa amarillo).

Solo se evalúan solicitudes con estado PENDIENTE; repetir la simulación no reevalúa. No se modifica PostgreSQL.

**Casos de prueba:** C2 a C6 (Consigna 2.c)
- C2: Cambio de precio → CONFLICTO; tras actualizar borrador → SIMULADO_APROBADO
- C3: Cantidad > stock → RECHAZADO
- C4: Producto con baja lógica → RECHAZADO (fila queda en cache)
- C5: Sin cambios → SIMULADO_APROBADO
- C6: Reenviar mismo UUID → error PK, no reevalúa

---

### REQ-04: Idempotencia y trazabilidad de sincronización

**WHEN** se procesa una solicitud de sincronización  
**THE SYSTEM SHALL** garantizar idempotencia usando `solicitud_uuid` como clave primaria en `cola_sync` (reenvío del mismo UUID da error de PK y no duplica evaluación), y registrar motivo y estado para trazabilidad. En PostgreSQL, verificar que ni `pedidos` ni `stock` de `productos` cambiaron tras la simulación.

**Caso de prueba:** C6 (Consigna 2.c) - Reenviar misma solicitud falla por PK duplicada; consulta final en PostgreSQL muestra conteo de pedidos y stock inalterados.

---

## Reglas de Oro (No Funcionales)

| Regla | Descripción |
|-------|-------------|
| RF-01 | **El móvil propone, el servidor dispone**: SQLite nunca modifica `productos.precio`, `productos.stock` ni inserta en `pedidos` de PostgreSQL. SIMULADO_APROBADO ≠ venta confirmada. |
| RF-02 | **Datos inventados**: Toda prueba usa base PostgreSQL independiente con datos sintéticos, sin datos personales reales. |
| RF-03 | **Validación IA**: Todo código generado con IA se lee, prueba y comprende antes de ejecutar. |
| RF-04 | **Versión SQLite ≥ 3.37**: Requerido para tablas STRICT y PRAGMA foreign_keys. |
| RF-05 | **Aislamiento PostgreSQL**: Base de pruebas creada desde cero (no template), solo estructura mínima + datos sintéticos. |