-- ============================================================================
-- Food Store - Unidad 8 - Esquema SQLite de la tablet
-- Base: foodstore_movil.db
-- ============================================================================

-- Configuración de robustez y rendimiento
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

-- ----------------------------------------------------------------------------
-- Tabla: snapshot_servidor
-- Copia estática (punto en el tiempo) de v_snapshot_movil de PostgreSQL.
-- No tiene fecha_copia: es el dato crudo tal como viaja del servidor.
-- ----------------------------------------------------------------------------
CREATE TABLE snapshot_servidor (
    id                 INTEGER NOT NULL,
    nombre             TEXT    NOT NULL,
    precio_centavos    INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock              INTEGER NOT NULL CHECK (stock >= 0),
    disponible         INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado          INTEGER NOT NULL CHECK (eliminado IN (0, 1)),
    PRIMARY KEY (id)
) STRICT;

-- ----------------------------------------------------------------------------
-- Tabla: producto_cache
-- Caché del catálogo vigente en la tablet. Se carga desde snapshot_servidor.
-- ----------------------------------------------------------------------------
CREATE TABLE producto_cache (
    id                 INTEGER NOT NULL,
    nombre             TEXT    NOT NULL,
    precio_centavos    INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto        INTEGER NOT NULL CHECK (stock_visto >= 0),
    disponible         INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado          INTEGER NOT NULL CHECK (eliminado IN (0, 1)),
    fecha_copia        TEXT    NOT NULL,
    PRIMARY KEY (id)
) STRICT;

-- ----------------------------------------------------------------------------
-- Tabla: pedido_borrador
-- Cabecera de un borrador de pedido armado en la tablet (offline).
-- ----------------------------------------------------------------------------
CREATE TABLE pedido_borrador (
    id_local       TEXT    NOT NULL, -- UUID v4 generado en la tablet
    usuario        TEXT    NOT NULL CHECK (length(usuario) > 0),
    forma_pago     TEXT    NOT NULL CHECK (forma_pago IN ('EFECTIVO','TARJETA','TRANSFERENCIA')),
    fecha          TEXT    NOT NULL, -- ISO 8601
    PRIMARY KEY (id_local)
) STRICT;

-- ----------------------------------------------------------------------------
-- Tabla: item_borrador
-- Líneas de un borrador de pedido.
-- ----------------------------------------------------------------------------
CREATE TABLE item_borrador (
    id_local                 TEXT    NOT NULL,
    producto_id              INTEGER NOT NULL,
    cantidad                 INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto    INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id),
    FOREIGN KEY (id_local) REFERENCES pedido_borrador (id_local) ON DELETE CASCADE,
    FOREIGN KEY (producto_id) REFERENCES producto_cache (id)
) STRICT;

-- ----------------------------------------------------------------------------
-- Tabla: cola_sync
-- Estado de sincronización de cada solicitud (móvil propone, servidor dispone).
-- ----------------------------------------------------------------------------
CREATE TABLE cola_sync (
    solicitud_uuid   TEXT    NOT NULL, -- UUID v4, idempotencia
    id_local         TEXT    NOT NULL,
    estado           TEXT    NOT NULL CHECK (estado IN ('PENDIENTE','RECHAZADO','CONFLICTO','SIMULADO_APROBADO')),
    motivo           TEXT    NOT NULL CHECK (length(motivo) > 0),
    PRIMARY KEY (solicitud_uuid),
    FOREIGN KEY (id_local) REFERENCES pedido_borrador (id_local) ON DELETE CASCADE
) STRICT;

-- Índices para consultas frecuentes
CREATE INDEX idx_producto_cache_disponible ON producto_cache (disponible, eliminado);
CREATE INDEX idx_item_borrador_producto ON item_borrador (producto_id);
CREATE INDEX idx_cola_sync_estado ON cola_sync (estado);
CREATE INDEX idx_cola_sync_id_local ON cola_sync (id_local);

-- ============================================================================
-- Fin del esquema
-- ============================================================================
