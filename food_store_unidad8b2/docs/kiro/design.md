# Technical Design - Food Store Unidad 8

**Proyecto:** Food Store - Unidad 8: La base de la tablet y el cierre de la capa de datos
**Fecha:** 2026-11-12
**Versión:** 2.0 (corregida tras revisión Unidad 7 real)

---

## 1. Visión General de la Arquitectura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        SERVIDOR (PostgreSQL 18.6)                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  foodstore_tp (PRODUCCIÓN - INTOCABLE)                          │   │
│  │  Tablas: categorias, sucursales, empleados, clientes,           │   │
│  │          productos, pedidos, detalle_pedido, pagos              │   │
│  │  Vistas: v_productos_vigentes, v_pedidos_cliente,               │   │
│  │          v_detalle_pedido, v_clientes_publico                   │   │
│  │  MV:     mv_facturacion_categoria_mes                           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                  │                                      │
│                    pg_dump / \copy (snapshot)                           │
│                                  ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  foodstore_u8_test (BASE PRUEBAS - ESTRUCTURA MÍNIMA + DATOS    │   │
│  │  SINTÉTICOS, SIN COPIAR foodstore_tp)                           │   │
│  │  Vista: v_snapshot_movil → CSV → SQLite                         │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                    Exportar CSV / Importar SQLite
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        TABLET (SQLite 3.50.4 via Python)                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  foodstore_movil.db (archivo local)                             │   │
│  │  Tablas STRICT:                                                 │   │
│  │    - producto_cache      (caché de catálogo)                    │   │
│  │    - pedido_borrador     (cabecera borrador)                    │   │
│  │    - item_borrador       (líneas del borrador)                  │   │
│  │    - cola_sync           (estado sincronización)                │   │
│  │    - snapshot_servidor   (copia estática del servidor)          │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                    MongoDB (Unidad 7 - histórico pedidos)
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        MONGODB (Unidad 7 - TRABAJO REAL)                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Base: foodstore_u7                                             │   │
│  │  Colección: pedidos (5 documentos: _id = 1, 4, 5, 6, 18)        │   │
│  │  Estructura por documento:                                      │   │
│  │    - _id (int) = id_pedido original                             │   │
│  │    - id_pedido, fecha_pedido (ISODate), estado, tipo_entrega   │   │
│  │    - id_sucursal, id_empleado_repartidor (int/null)            │   │
│  │    - total (NumberDecimal), activo (bool)                       │   │
│  │    - datos_envio (embebido: {ciudad, direccion})               │   │
│  │    - cliente (embebido: {id_cliente, cliente_ref,              │   │
│  │                        fecha_registro, activo}) SIN PII         │   │
│  │    - detalle (arreglo embebido: 3 líneas c/u con               │   │
│  │        {id_detalle, id_producto, producto_nombre, cantidad,    │   │
│  │         precio_unitario NumberDecimal, subtotal NumberDecimal}) │   │
│  │    - origen (metadata: bd, tabla, migrado_en)                   │   │
│  │  Consultas ejecutadas (Consigna 4):                             │   │
│  │    a) Todos los pedidos (id, estado)                            │   │
│  │    b) Filtrar por estado 'entregado' → 1 resultado (id 6)       │   │
│  │    c) Buscar producto 8 en detalle → 3 resultados (ids 4,5,6)   │   │
│  │    d) Total > 20000 → 4 resultados (ids 1,5,6,18)               │   │
│  │  Consultas PG equivalentes (b,c): coincidencia exacta de IDs    │   │
│  │  Conclusión U7: Combinación PG (transaccional) + Mongo          │   │
│  │  (vista documental para lectura completa de pedidos)            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

**Regla de oro:** El móvil (SQLite) propone borradores; el servidor (PostgreSQL) dispone. La tablet NUNCA modifica precio, stock ni confirma ventas.

---

## 2. Esquema SQLite (movil/schema_sqlite.sql)

### 2.1 Tabla: producto_cache
Caché de solo lectura del catálogo vigente. Se carga desde `snapshot_servidor`.

```sql
CREATE TABLE producto_cache (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto     INTEGER NOT NULL CHECK (stock_visto >= 0),
    disponible      INTEGER NOT NULL CHECK (disponible IN (0,1)),
    eliminado       INTEGER NOT NULL CHECK (eliminado IN (0,1)),
    fecha_copia     TEXT NOT NULL  -- ISO8601: 'YYYY-MM-DD HH:MM:SS'
) STRICT;
```

- `precio_centavos`: Entero, centavos (ej: 1500 = $15.00). Evita punto flotante.
- `disponible`: 1 = vigente y con stock > 0; 0 = sin stock o inactivo.
- `eliminado`: 1 = baja lógica en servidor; 0 = activo.
- `fecha_copia`: Timestamp de cuándo se tomó el snapshot.

### 2.2 Tabla: pedido_borrador
Cabecera del borrador de pedido creado en la tablet.

```sql
CREATE TABLE pedido_borrador (
    id_local     TEXT PRIMARY KEY,  -- UUID v4 generado en tablet
    usuario      TEXT NOT NULL,     -- Identificador del vendedor (ej: 'vendedor_feria')
    forma_pago   TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO','TARJETA','TRANSFERENCIA')),
    fecha        TEXT NOT NULL      -- ISO8601 local
) STRICT;
```

- `id_local`: UUID generado en la tablet (clave natural del borrador).
- No hay FK a usuarios (la tablet no tiene tabla de usuarios).

### 2.3 Tabla: item_borrador
Líneas del borrador. FK a pedido_borrador y producto_cache.

```sql
CREATE TABLE item_borrador (
    id_local              TEXT NOT NULL,
    producto_id           INTEGER NOT NULL,
    cantidad              INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id),
    FOREIGN KEY (id_local) REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    FOREIGN KEY (producto_id) REFERENCES producto_cache(id) ON DELETE RESTRICT
) STRICT;
```

- PK compuesta: un borrador no puede tener dos líneas del mismo producto.
- `precio_centavos_visto`: Precio al momento de crear el borrador (para detectar conflictos).
- FK a `producto_cache` con RESTRICT: no se puede borrar producto si tiene items.

### 2.4 Tabla: cola_sync
Cola de solicitudes de sincronización. Una fila por borrador enviado.

```sql
CREATE TABLE cola_sync (
    solicitud_uuid  TEXT PRIMARY KEY,  -- UUID v4, idempotencia
    id_local        TEXT NOT NULL,
    estado          TEXT NOT NULL CHECK (estado IN ('PENDIENTE','CONFLICTO','RECHAZADO','SIMULADO_APROBADO')),
    motivo          TEXT,              -- Detalle del rechazo/conflicto
    FOREIGN KEY (id_local) REFERENCES pedido_borrador(id_local) ON DELETE CASCADE
) STRICT;
```

- `solicitud_uuid`: Clave de idempotencia. Reenvío = error PK.
- `estado`: Solo PENDIENTE se evalúa en el semáforo.
- `motivo`: Texto libre explicando el resultado (ej: "Producto 5: stock insuficiente (pedido 3, disponible 2)").

### 2.5 Tabla: snapshot_servidor
Copia estática de la vista `v_snapshot_movil` exportada desde PostgreSQL.

```sql
CREATE TABLE snapshot_servidor (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock           INTEGER NOT NULL CHECK (stock >= 0),
    disponible      INTEGER NOT NULL CHECK (disponible IN (0,1)),
    eliminado       INTEGER NOT NULL CHECK (eliminado IN (0,1))
) STRICT;
```

- Estructura idéntica a `producto_cache` pero sin `fecha_copia`.
- Se usa SOLO para el semáforo (comparación). No se modifica.

### 2.6 PRAGMA y Configuración Inicial

```sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;        -- Mejor concurrencia lecturas/escrituras
PRAGMA synchronous = NORMAL;      -- Balance seguridad/performance
PRAGMA busy_timeout = 5000;       -- 5s timeout en locks
```

---

## 3. Vista PostgreSQL: v_snapshot_movil (Consigna 2.a)

Basada en `v_productos_vigentes` (Unidad 3), extendida con `stock` y `eliminado`.

```sql
CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT
    p.id_producto      AS id,
    p.nombre,
    (p.precio * 100)::bigint AS precio_centavos,
    p.stock,
    CASE WHEN p.activo AND p.stock > 0 THEN 1 ELSE 0 END AS disponible,
    CASE WHEN p.activo THEN 0 ELSE 1 END AS eliminado
FROM productos p
JOIN categorias c ON c.id_categoria = p.id_categoria
WHERE c.activo = TRUE;
```

**Exportación a CSV (psql):**
```bash
\copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER
```

**Importación en SQLite:**
```bash
.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor
```

**Carga de producto_cache:**
```sql
INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
SELECT id, nombre, precio_centavos, stock, disponible, eliminado, datetime('now')
FROM snapshot_servidor;
```

---

## 4. Semáforo de Sincronización (Consigna 2.b)

### 4.1 Lógica de Clasificación (SQL Set-Based)

Para cada `solicitud_uuid` en `cola_sync` con estado `PENDIENTE`:

```sql
WITH items_con_snapshot AS (
    SELECT
        c.solicitud_uuid,
        i.producto_id,
        i.cantidad,
        i.precio_centavos_visto,
        s.stock,
        s.disponible,
        s.eliminado,
        s.precio_centavos
    FROM cola_sync c
    JOIN item_borrador i ON i.id_local = c.id_local
    LEFT JOIN snapshot_servidor s ON s.id = i.producto_id
    WHERE c.estado = 'PENDIENTE'
),
clasificacion AS (
    SELECT
        solicitud_uuid,
        -- Rojo: producto no existe, no disponible, eliminado, o stock insuficiente
        CASE WHEN SUM(
            CASE WHEN stock IS NULL THEN 1
                 WHEN disponible = 0 THEN 1
                 WHEN eliminado = 1 THEN 1
                 WHEN cantidad > stock THEN 1
                 ELSE 0 END
        ) > 0 THEN 'RECHAZADO'
        -- Amarillo: no hay rojo, pero cambió precio
        WHEN SUM(
            CASE WHEN precio_centavos_visto <> precio_centavos THEN 1 ELSE 0 END
        ) > 0 THEN 'CONFLICTO'
        -- Verde: todo coincide
        ELSE 'SIMULADO_APROBADO'
        END AS nuevo_estado,
        -- Construir motivo
        GROUP_CONCAT(
            CASE WHEN stock IS NULL THEN 'Producto ' || producto_id || ' no existe'
                 WHEN disponible = 0 THEN 'Producto ' || producto_id || ' no disponible'
                 WHEN eliminado = 1 THEN 'Producto ' || producto_id || ' dado de baja'
                 WHEN cantidad > stock THEN 'Producto ' || producto_id || ' stock insuficiente (pedido ' || cantidad || ', disp ' || stock || ')'
                 WHEN precio_centavos_visto <> precio_centavos THEN 'Producto ' || producto_id || ' precio cambiado (visto ' || precio_centavos_visto || ', actual ' || precio_centavos || ')'
            END,
            '; '
        ) AS motivo
    FROM items_con_snapshot
    GROUP BY solicitud_uuid
)
UPDATE cola_sync
SET estado = c.nuevo_estado,
    motivo = c.motivo
FROM clasificacion c
WHERE cola_sync.solicitud_uuid = c.solicitud_uuid
  AND cola_sync.estado = 'PENDIENTE';
```

### 4.2 Consideraciones Importantes

- **Booleans en CSV**: `psql` exporta `t`/`f`. Al importar en SQLite, convertir: `CASE WHEN disponible = 't' THEN 1 ELSE 0 END` (o importar como TEXT y castear).
- **Prioridad RECHAZADO > CONFLICTO**: El CASE evalúa rojo primero; si hay cualquier item con stock IS NULL, disponible=0, eliminado=1, o cantidad>stock → RECHAZADO inmediato. Solo si SUM(rojo)=0 se evalúa CONFLICTO.
- **Idempotencia**: Solo `PENDIENTE` se procesa. Re-ejecutar no cambia `CONFLICTO`/`RECHAZADO`/`SIMULADO_APROBADO`.
- **No tocar PostgreSQL**: El semáforo es simulación pura. `SIMULADO_APROBADO` ≠ venta.

---

## 5. Casos de Prueba (Consigna 2.c)

| Caso | Preparación en PostgreSQL (copia) | Snapshot | Resultado Esperado |
|------|-----------------------------------|----------|-------------------|
| C2   | Borrador OK → Subir precio en servidor → Re-exportar snapshot | Precio distinto | CONFLICTO → Actualizar `precio_centavos_visto` en item_borrador → Nueva solicitud (nuevo UUID) → SIMULADO_APROBADO |
| C3   | Borrador con cantidad > stock actual | Stock menor | RECHAZADO (motivo: stock insuficiente) |
| C4   | Borrador con producto → Dar baja lógica en PG (activo=false) → Re-exportar | eliminado=1 | RECHAZADO (motivo: dado de baja); fila queda en producto_cache |
| C5   | Borrador sin cambios en servidor | Idéntico | SIMULADO_APROBADO |
| C6   | Reenviar mismo `solicitud_uuid` (INSERT duplicado) | - | Error PK (UNIQUE constraint), no reevalúa |

**Verificación final (PostgreSQL):**
```sql
SELECT count(*) FROM pedidos;      -- Debe ser igual al inicio
SELECT sum(stock) FROM productos;  -- Debe ser igual al inicio
```

---

## 6. Mapa de la Capa de Datos (Consigna 3.a)

| Motor | Qué Guarda | Quién Manda (Fuente de Verdad) |
|-------|------------|-------------------------------|
| **PostgreSQL** | Catálogo maestro (productos, precios, stock), Clientes, Pedidos confirmados, Pagos, Sucursales, Empleados, Auditoría, Roles | **PostgreSQL** - Fuente de verdad absoluta |
| **SQLite (Tablet)** | Caché de catálogo (producto_cache), Borradores locales (pedido_borrador, item_borrador), Cola de sync (cola_sync), Snapshot estático (snapshot_servidor) | **PostgreSQL** - La tablet solo propone; snapshot es foto pasada |
| **MongoDB (Unidad 7)** | Base `foodstore_u7`, colección `pedidos` (5 docs: _id=1,4,5,6,18). Cada doc: pedido completo con `detalle` embebido (3 líneas c/u, precios históricos NumberDecimal), `cliente` embebido (sin PII), `datos_envio`, `origen`. Propósito: lectura optimizada de pedidos completos, comparación con PG. | **PostgreSQL** - MongoDB es vista documental de lectura; sincronización manual/periódica desde PG. PG manda sobre datos transaccionales. |

---

## 7. Plan de Mantenimiento Extendido (Consigna 3.b)

*Agregado al plan Unidad 6 (SPEC_U6.md)*

| Actividad | Frecuencia | Responsable | Detalle |
|-----------|------------|-------------|---------|
| Respaldo PostgreSQL (custom, comprimido, paralelo) | Diaria 02:00 | DBA / Auto | `backup_foodstore.ps1` → `foodstore_tp` |
| Verificación integridad respaldo (`pg_restore -l`) | Post-respaldo | DBA | Log en `C:\backups\foodstore\logs\` |
| Health check (bloat, dead tuples, long tx, índices) | Diaria 06:00 | DBA / Monitoreo | `health_check.sql` |
| ANALYZE completo | Semanal Domingo 03:00 | Autovacuum / Manual | `maintenance.sql` |
| VACUUM (FULL solo si bloat > 30%) | Mensual / demanda | DBA | `maintenance.sql` (preferir pg_repack) |
| Refresco MV `mv_facturacion_categoria_mes` | Diaria 04:00 | Auto | `REFRESH MATERIALIZED VIEW CONCURRENTLY` |
| **Test restauración en entorno aislado** | **Semanal Sábado 10:00** | **DBA** | **`restore_test.ps1` + validaciones en `foodstore_tp_test`** |
| **Revisión cola_sync: CONFLICTO/RECHAZADO** | **Diaria / Cada sync** | **Vendedor / Soporte** | **Resolver conflictos de precio; rearmar borradores rechazados** |
| **Snapshot tablet: regenerar si PostgreSQL restaurado a versión anterior** | **Tras restore antiguo** | **DBA / Vendedor** | **Tablet debe detectar snapshot obsoleto (fecha_copia) y recargar catálogo** |
| Revisión logs y alertas | Diaria continua | DBA | Logs backup, restore, salud |
| **Code review con IA (scripts cursada)** | **Por entrega (Unidad 8)** | **Equipo** | **`bitacora_ia.md` + `informe.pdf` sección 3.c** |

**Si se restaura respaldo viejo de PostgreSQL:**
1. La tabla `productos` vuelve a estado anterior (precios/stock viejos)
2. Las tablets tienen `snapshot_servidor` y `producto_cache` con datos MÁS NUEVOS que el servidor restaurado
3. **Acción:** Detectar en tablet (`fecha_copia` > `pg_control_checkpoint` o versión BD), forzar regeneración de snapshot y recarga de `producto_cache`. Borradores PENDIENTES basados en datos nuevos pueden dar CONFLICTO/RECHAZADO al sincronizar.

---

## 8. Code Review con IA (Consigna 3.c)

**Proceso:**
1. Pedir a OpenCode (agente Plan) revisar todos los scripts: `scripts/*.sql`, `unidad6/*.sql`, `unidad4/*.sql`, `unidad5/*.sql`, `views.sql`, `indices.sql`
2. Tabla de hallazgos:

| Hallazgo | Unidad | Decisión | Motivo | Comprobación |
|----------|--------|----------|--------|--------------|
| Ej: Índice redundante en detalle_pedido | 6 | Descartado | Cubierto por uq_pedido_producto | `EXPLAIN ANALYZE` muestra mismo plan |
| ... | ... | ... | ... | ... |

3. Mínimo 3 hallazgos de 2+ unidades distintas, al menos 1 descartado con fundamento técnico.

---

## 9. Specs Kiro (Consigna 4.a)

**Archivos en `docs/kiro/`:**
- `requirements.md`: 4 requisitos EARS + casos (este documento resume)
- `design.md`: Este documento
- `tasks.md`: Tareas ordenadas (ver archivo separado)

---

## 10. Seguridad y Restricciones

- ✅ `PRAGMA foreign_keys = ON` obligatorio
- ✅ Tablas `STRICT` (SQLite 3.37+)
- ✅ Precios en centavos (INTEGER)
- ✅ CHECK constraints en todas las columnas críticas
- ✅ UUID v4 para idempotencia (`solicitud_uuid`, `id_local`)
- ❌ NUNCA `INSERT/UPDATE/DELETE` en `foodstore_tp` desde tablet
- ❌ NUNCA contraseñas/datos reales en SQLite ni prompts IA
- ❌ NUNCA `SIMULADO_APROBADO` = venta confirmada
- ❌ NUNCA `createdb -T foodstore_tp` (evita copiar datos reales/PII)