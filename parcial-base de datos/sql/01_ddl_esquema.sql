
-- TRABAJO PRÁCTICO INTEGRADOR: FOOD STORE
-- Archivo: 01_ddl_esquema.sql
-- Motor de Referencia: PostgreSQL 16+
-- Objetivo: Definición completa de tipos, tablas, restricciones e índices.


-- 1. LIMPIEZA DE ESTRUCTURAS PREVIAS (Para ejecución limpia)
DROP TABLE IF EXISTS pagos CASCADE;
DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedidos CASCADE;
DROP TABLE IF EXISTS productos CASCADE;
DROP TABLE IF EXISTS categorias CASCADE;
DROP TABLE IF EXISTS empleados CASCADE;
DROP TABLE IF EXISTS sucursales CASCADE;
DROP TABLE IF EXISTS clientes CASCADE;

DROP TYPE IF EXISTS estado_pago_enum CASCADE;
DROP TYPE IF EXISTS metodo_pago_enum CASCADE;
DROP TYPE IF EXISTS tipo_entrega_enum CASCADE;
DROP TYPE IF EXISTS estado_pedido_enum CASCADE;
DROP TYPE IF EXISTS rol_empleado_enum CASCADE;

-- 2. DEFINICIÓN DE TIPOS ENUMERADOS NATIVOS
CREATE TYPE rol_empleado_enum AS ENUM ('cajero', 'repartidor', 'gerente');
CREATE TYPE estado_pedido_enum AS ENUM ('pendiente', 'en_preparacion', 'en_camino', 'entregado', 'cancelado');
CREATE TYPE tipo_entrega_enum AS ENUM ('delivery', 'retiro_local');
CREATE TYPE metodo_pago_enum AS ENUM ('efectivo', 'tarjeta_credito', 'tarjeta_debito', 'mercado_pago');
CREATE TYPE estado_pago_enum AS ENUM ('pendiente', 'aprobado', 'rechazado');

-- 3. CREACIÓN DE TABLAS MAESTRAS (Catálogos y Usuarios)

-- Clientes (Soft delete integrado con columna 'activo')
CREATE TABLE clientes (
    id_cliente INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    telefono VARCHAR(30),
    direccion_entrega VARCHAR(255),
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Sucursales
CREATE TABLE sucursales (
    id_sucursal INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    direccion VARCHAR(255) NOT NULL,
    telefono VARCHAR(30),
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Empleados
CREATE TABLE empleados (
    id_empleado INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal INT NOT NULL REFERENCES sucursales(id_sucursal),
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    dni VARCHAR(20) NOT NULL UNIQUE,
    rol rol_empleado_enum NOT NULL,
    fecha_contratacion DATE NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Categorías de Productos
CREATE TABLE categorias (
    id_categoria INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Productos
CREATE TABLE productos (
    id_producto INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_categoria INT NOT NULL REFERENCES categorias(id_categoria),
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    precio NUMERIC(10,2) NOT NULL CHECK (precio > 0),
    stock INT NOT NULL CHECK (stock >= 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- 4. CREACIÓN DE TABLAS TRANSACCIONALES

-- Pedidos (Con JSONB para direcciones y restricción lógica para reparto)
CREATE TABLE pedidos (
    id_pedido INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente INT NOT NULL REFERENCES clientes(id_cliente),
    id_sucursal INT NOT NULL REFERENCES sucursales(id_sucursal),
    id_empleado_repartidor INT REFERENCES empleados(id_empleado),
    fecha_pedido TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado estado_pedido_enum NOT NULL DEFAULT 'pendiente',
    tipo_entrega tipo_entrega_enum NOT NULL,
    total NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (total >= 0),
    datos_envio JSONB,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_repartidor_delivery CHECK (
        tipo_entrega = 'delivery' OR id_empleado_repartidor IS NULL
    )
);

-- Detalle de Pedido (Tabla intermedia N:M entre Pedido y Producto)
CREATE TABLE detalle_pedido (
    id_detalle INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido INT NOT NULL REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
    id_producto INT NOT NULL REFERENCES productos(id_producto),
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario > 0),
    subtotal NUMERIC(10,2) NOT NULL CHECK (subtotal > 0),
    CONSTRAINT uq_pedido_producto UNIQUE (id_pedido, id_producto)
);

-- Pagos
CREATE TABLE pagos (
    id_pago INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido INT NOT NULL REFERENCES pedidos(id_pedido),
    metodo_pago metodo_pago_enum NOT NULL,
    monto NUMERIC(10,2) NOT NULL CHECK (monto > 0),
    fecha_pago TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado estado_pago_enum NOT NULL DEFAULT 'pendiente'
);

-- 5. ÍNDICES DE RENDIMIENTO Y SOFT DELETE
CREATE INDEX idx_pedidos_cliente ON pedidos(id_cliente);
CREATE INDEX idx_pedidos_sucursal ON pedidos(id_sucursal);
CREATE INDEX idx_productos_categoria ON productos(id_categoria);
CREATE INDEX idx_detalle_pedido_producto ON detalle_pedido(id_producto);

-- Índices Parciales (Búsqueda optimizada omitiendo dados de baja)
CREATE INDEX idx_clientes_activos ON clientes(id_cliente) WHERE activo = TRUE;
CREATE INDEX idx_productos_activos ON productos(nombre) WHERE activo = TRUE;
