# Mapa de la capa de datos — Tres motores (Consigna 3.a)

**Proyecto:** Food Store - Unidad 8  
**Fecha:** 2026-11-12

Este mapa integra los tres motores de base de datos utilizados en la cursada: PostgreSQL (Unidades 4-6), SQLite (Unidad 8, tablet) y MongoDB (Unidad 7, historial documental).

---

## 1. PostgreSQL — Fuente de verdad (servidor)

| Ítem | Valor |
|------|-------|
| Motor | PostgreSQL 18.6 |
| Base de producción | `foodstore_tp` (INTOCABLE) |
| Tablas producción | `categorias`, `sucursales`, `empleados`, `clientes`, `productos`, `pedidos`, `detalle_pedido`, `pagos` |
| Volumen producción | 40 productos, 2000 clientes, 50000 pedidos |
| Base de pruebas | `foodstore_u8_test` (creada desde cero, datos sintéticos, sin copiar `foodstore_tp`) |
| Tablas pruebas | `categorias` (5), `sucursales` (3), `productos` (15) |
| Vista snapshot | `v_snapshot_movil` (6 columnas, 15 filas) |
| Autoridad | Precios, stock, disponibilidad y ventas los decide PostgreSQL |

**Rol:** Es la fuente de verdad. La tablet nunca escribe en `foodstore_tp`. La sincronización es unidireccional de lectura: PostgreSQL exporta snapshot → SQLite.

---

## 2. SQLite — Tablet del food truck (móvil)

| Ítem | Valor |
|------|-------|
| Motor | SQLite 3.50.4 (vía Python 3.14.8) |
| Base | `foodstore_movil.db` (archivo local, offline) |
| Tablas STRICT | `producto_cache`, `pedido_borrador`, `item_borrador`, `cola_sync`, `snapshot_servidor` |
| Configuración | `PRAGMA foreign_keys = ON`, `journal_mode = WAL`, `synchronous = NORMAL`, `busy_timeout = 5000` |
| Datos | Caché de catálogo cargada desde `snapshot_servidor` (copia de `v_snapshot_movil`) |
| Fecha de copia | Anotada en `producto_cache.fecha_copia` |
| Sincronización | `cola_sync` registra estado de cada borrador (PENDIENTE/RECHAZADO/CONFLICTO/SIMULADO_APROBADO) |

**Rol:** La tablet opera sin señal. Solo consulta el catálogo y arma borradores. `SIMULADO_APROBADO` no es una venta confirmada; el servidor tiene la última palabra.

---

## 3. MongoDB — Unidad 7 (historial documental real)

| Ítem | Valor |
|------|-------|
| Motor | MongoDB (servicio en ejecución) |
| Base | `foodstore_u7` |
| Colección | `pedidos` |
| Documentos | 5 documentos con `_id` = 1, 4, 5, 6, 18 |
| Estructura por documento | `_id`, `id_pedido`, `fecha_pedido` (ISODate), `estado`, `tipo_entrega`, `id_sucursal`, `id_empleado_repartidor`, `total` (NumberDecimal), `activo`, `datos_envio` (embebido), `detalle` (embebido), `cliente` (embebido) |
| Origen | Repo `Base_de_datos`, commit `c6e82a7`, carpeta `food_store_unidad7b2` (verificado por Kiro y por auditoría OpenCode) |

**Rol:** Vista documental de lectura del historial de pedidos. Sincronización manual/periódica desde PostgreSQL. PostgreSQL manda sobre datos transaccionales.

---

## 4. Flujo de datos entre motores

```
PostgreSQL (v_snapshot_movil)
      │  pg_dump / \copy  (CSV)
      ▼
CSV servidor_snapshot.csv  ──►  SQLite (snapshot_servidor → producto_cache)
      │                              │
      │  tablet offline              │  borradores + cola_sync
      ▼                              ▼
producto_cache (consulta)      pedido_borrador + item_borrador
                                              │
                                              │  recupera señal
                                              ▼
                                       semaforo.sql (cola_sync)
                                       RECHAZADO / CONFLICTO / SIMULADO_APROBADO
                                       (solo lectura, PostgreSQL no se modifica)
```

---

## 5. Regla de oro

**El móvil propone, el servidor dispone.** La tablet solo consulta y arma borradores. Precio, stock y ventas los decide PostgreSQL. `SIMULADO_APROBADO` ≠ venta confirmada.
