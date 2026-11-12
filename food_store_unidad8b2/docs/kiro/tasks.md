# Tasks - Food Store Unidad 8

**Proyecto:** Food Store - Unidad 8: La base de la tablet y el cierre de la capa de datos
**Fecha:** 2026-11-12
**Versión:** 2.0 (corregida tras revisión Unidad 7 real y aislamiento PG)

---

## Orden de Ejecución

Las tareas están numeradas en orden de dependencia. Marcar `[x]` al completar y verificar.

---

### FASE 0: Entorno y Verificaciones Previas

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 0.1 | Verificar Python sqlite3 ≥ 3.37 con STRICT | `python -c "import sqlite3; print(sqlite3.sqlite_version)"` → 3.50.4 ✅ | `[x]` |
| 0.2 | Verificar PostgreSQL 18.6 disponible | `psql --version` → 18.6 ✅ | `[x]` |
| 0.3 | Confirmar estructura `food_store_unidad8b2/` creada | Directorios `movil/`, `docs/kiro/` existen | `[x]` |
| 0.4 | Documentar en README.md: versiones, herramientas, base aislada | README actualizado | `[x]` |
| 0.5 | Localizar trabajo Unidad 7 (MongoDB) real | Repo `Base_de_datos`, commit `c6e82a7`, carpeta `food_store_unidad7b2` con 5 pedidos migrados, colección `pedidos`, consultas a-d ejecutadas | `[x]` |

---

### FASE 1: Consigna 1 - La Base de la Tablet (30 pts)

#### 1.a Qué datos viajan (5 pts) - Documentación

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 1.1 | Crear tabla comparativa: columnas producto que viajan vs no viajan | En `informe.pdf` o `docs/1a_datos_viajan.md` | `[ ]` |
| 1.2 | Redactar justificación (2-3 oraciones): por qué y fuente de verdad | "PostgreSQL es fuente de verdad; tablet solo cache de catálogo vigente" | `[ ]` |

#### 1.b Script schema_sqlite.sql (15 pts)

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 1.3 | Crear `movil/schema_sqlite.sql` con PRAGMA foreign_keys=ON | Archivo existe, empieza con PRAGMA | `[ ]` |
| 1.4 | Definir tabla `producto_cache` STRICT con CHECKs | Columnas: id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia | `[ ]` |
| 1.5 | Definir tabla `pedido_borrador` STRICT | Columnas: id_local (PK UUID), usuario, forma_pago (CHECK 3 valores), fecha | `[ ]` |
| 1.6 | Definir tabla `item_borrador` STRICT | PK compuesta, FKs, CHECK cantidad>0, precio_centavos_visto>=0 | `[ ]` |
| 1.7 | Definir tabla `cola_sync` STRICT | PK solicitud_uuid, FK id_local, CHECK estado (4 valores), motivo TEXT | `[ ]` |
| 1.8 | Definir tabla `snapshot_servidor` STRICT | Para semáforo, sin fecha_copia | `[ ]` |
| 1.9 | Agregar PRAGMA journal_mode=WAL, synchronous=NORMAL, busy_timeout=5000 | Configuración performance/robustez | `[ ]` |
| 1.10 | Probar creación: `sqlite3 foodstore_movil.db < schema_sqlite.sql` | Base creada sin errores, tablas existen | `[ ]` |
| 1.11 | Verificar foreign_keys activas: `PRAGMA foreign_keys;` → 1 | ON confirmado | `[ ]` |
| 1.12 | Verificar tablas STRICT: `PRAGMA table_info(producto_cache);` | strict=1 en salida | `[ ]` |

#### 1.c Script pruebas_sqlite.sql (10 pts)

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 1.13 | Crear `movil/pruebas_sqlite.sql` | Archivo existe | `[ ]` |
| 1.14 | Test 1: Borrador completo BEGIN...COMMIT (cabecera + items + cola_sync) | Ejecuta sin error, filas insertadas | `[ ]` |
| 1.15 | Test 2: Operación con ROLLBACK (cantidad 0 o producto inexistente) | No deja filas nuevas, ROLLBACK efectivo | `[ ]` |
| 1.16 | Test 3: Caso C1 - Consulta catálogo disponible sin servidor | `SELECT * FROM producto_cache WHERE disponible=1 AND eliminado=0` retorna filas | `[ ]` |
| 1.17 | Test 4: Caso C7 - Cantidad 0 y producto inexistente dan error | CHECK cantidad>0 y FK fallan, sin filas parciales | `[ ]` |
| 1.18 | Ejecutar todos: `sqlite3 foodstore_movil.db < pruebas_sqlite.sql` | Salida limpia, todos los casos pasan | `[ ]` |

---

### FASE 2: Consigna 2 - Sincronizar y Resolver (35 pts)

#### 2.a Instantánea y Carga (5 pts) - BASE PG AISLADA CON DATOS SINTÉTICOS

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 2.1 | Crear BD de pruebas PostgreSQL: `foodstore_u8_test` **desde cero** (CREATE DATABASE + DDL mínimo) | `psql -l` muestra base, estructura mínima creada | `[x]` (auditado 2026-11-12) |
| 2.2 | Crear tablas mínimas: categorias, sucursales, productos (con precio, stock, activo) | `\d+` muestra tablas con constraints | `[x]` (auditado 2026-11-12) |
| 2.3 | Insertar datos SINTÉTICOS (inventados): 5 categorias, 3 sucursales, 15-20 productos con precios/stock variados | `SELECT * FROM productos;` muestra datos ficticios | `[x]` (auditado 2026-11-12: 15 productos, suma stock = 322) |
| 2.4 | Crear vista `v_snapshot_movil` en BD pruebas | `SELECT * FROM v_snapshot_movil LIMIT 5;` OK | `[x]` (auditado 2026-11-12: 6 columnas, 15 filas) |
| 2.5 | Exportar a CSV: `\copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER` | Archivo generado, cabecera + datos | `[x]` (auditado 2026-11-12: 16 líneas, 6 columnas, coincide con la vista) |
| 2.6 | Copiar CSV a `movil/servidor_snapshot.csv` | Archivo en lugar correcto | `[x]` (auditado 2026-11-12) |
| 2.7 | Importar en SQLite: `.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor` | Tabla poblada, conteo = vista PG | `[ ]` |
| 2.8 | Cargar `producto_cache` desde `snapshot_servidor` con `fecha_copia = datetime('now')` | `SELECT count(*) FROM producto_cache;` = snapshot | `[ ]` |
| 2.9 | Anotar fecha de la copia en documentación | En README o informe | `[ ]` |
| 2.10 | Verificar que `foodstore_tp` original NO fue tocada | `psql -d foodstore_tp -c "SELECT count(*) FROM productos;"` = valor original | `[x]` (auditado 2026-11-12: 40 productos, 2000 clientes, 50000 pedidos) |

#### 2.b Semáforo (15 pts)

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 2.11 | Crear `movil/semaforo.sql` | Archivo existe | `[ ]` |
| 2.12 | Implementar CTE `items_con_snapshot` con LEFT JOIN | Query correcta, maneja NULL (producto no existe) | `[ ]` |
| 2.13 | Implementar lógica CASE: RECHAZADO (prioridad) / CONFLICTO / SIMULADO_APROBADO | Clasificación correcta por solicitud_uuid | `[ ]` |
| 2.14 | Construir `motivo` concatenado con detalles por ítem | Motivo legible con IDs y valores | `[ ]` |
| 2.15 | UPDATE solo WHERE estado = 'PENDIENTE' | No reevalúa ya procesadas | `[ ]` |
| 2.16 | Manejar booleanos CSV (t/f → 1/0) en importación o query | Conversión correcta | `[ ]` |
| 2.17 | Probar semáforo con datos base (sin casos forzados) | Todas PENDIENTE → SIMULADO_APROBADO | `[ ]` |
| 2.18 | Verificar idempotencia: re-ejecutar semáforo no cambia estados | Segunda ejecución = mismos resultados | `[ ]` |

#### 2.c Casos C2-C6 (15 pts = 3 c/u)

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 2.19 | **C2**: Crear borrador → subir precio en PG → re-exportar snapshot → importar → semáforo → CONFLICTO | Estado = CONFLICTO, motivo menciona precio | `[ ]` |
| 2.20 | **C2-cont**: Actualizar `precio_centavos_visto` en item_borrador → nueva solicitud (nuevo UUID) → semáforo → SIMULADO_APROBADO | Nuevo UUID, estado verde | `[ ]` |
| 2.21 | **C3**: Borrador con cantidad > stock → semáforo → RECHAZADO | Motivo: "stock insuficiente" | `[ ]` |
| 2.22 | **C4**: Borrador con producto → baja lógica en PG (activo=false) → snapshot → semáforo → RECHAZADO | Motivo: "dado de baja"; fila queda en cache | `[ ]` |
| 2.23 | **C5**: Borrador sin cambios → semáforo → SIMULADO_APROBADO | Estado verde, motivo vacío o "OK" | `[ ]` |
| 2.24 | **C6**: Reenviar mismo `solicitud_uuid` (INSERT duplicado) → error PK | Error UNIQUE/PK, no reevalúa | `[ ]` |
| 2.25 | Para cada caso: documentar comando, resultado, explicación (1-2 oraciones) | En `informe.pdf` o `docs/2c_casos.md` | `[ ]` |
| 2.26 | Verificación final PG: `SELECT count(*) FROM pedidos;` (debe ser 0 en BD sintética) y `SELECT sum(stock) FROM productos;` inalterado | Conteos = valores iniciales sintéticos | `[ ]` |

---

### FASE 3: Consigna 3 - Integrar y Revisar (20 pts)

#### 3.a Mapa Capa de Datos (5 pts) - CON DATOS REALES U7

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 3.1 | Crear tabla/dibujo: 3 motores (PG, MongoDB real U7, SQLite) | En `informe.pdf` o `docs/3a_mapa.md` | `[ ]` |
| 3.2 | Completar: qué guarda cada uno, quién manda | PG = verdad absoluta; SQLite = cache+borradores; Mongo = pedidos embebidos (foodstore_u7.pedidos, 5 docs, IDs 1,4,5,6,18) | `[ ]` |

#### 3.b Plan Mantenimiento Extendido (5 pts)

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 3.3 | Agregar al plan U6: ¿Qué se respalda y cómo se prueba restauración? | En `informe.pdf` sección 3.b | `[ ]` |
| 3.4 | Agregar: ¿Qué hacen tablets si se restaura respaldo viejo PG? | Detectar snapshot obsoleto, forzar recarga | `[ ]` |
| 3.5 | Agregar: Cada cuánto y quién revisa CONFLICTO/RECHAZADO | Diaria / vendedor+soporte | `[ ]` |

#### 3.c Code Review con IA (10 pts)

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 3.6 | Pedir a OpenCode (Plan) revisar scripts: scripts/, unidad6/, unidad4/, unidad5/, views.sql, indices.sql | Sesión OpenCode iniciada | `[ ]` |
| 3.7 | Generar tabla hallazgos: hallazgo, unidad, decisión (aceptado/corregido/descartado), motivo | Mínimo 3 filas, 2+ unidades | `[ ]` |
| 3.8 | Desarrollar 3 hallazgos con comprobación en BD (EXPLAIN, conteos, etc.) | Evidencia técnica | `[ ]` |
| 3.9 | Al menos 1 hallazgo DESCARTADO con fundamento técnico | Ej: índice redundante cubierto por PK | `[ ]` |
| 3.10 | Registrar en `bitacora_ia.md` y `informe.pdf` sección 3.c | Documentación completa | `[ ]` |

---

### FASE 4: Consigna 4 - Kiro, Bitácora y Defensa (15 pts)

#### 4.a Specs Kiro (5 pts)

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 4.1 | `docs/kiro/requirements.md`: 4 requisitos EARS + caso prueba | ✅ Actualizado v2.0 | `[x]` |
| 4.2 | `docs/kiro/design.md`: Diseño técnico completo con U7 real | ✅ Actualizado v2.0 | `[x]` |
| 4.3 | `docs/kiro/tasks.md`: Este archivo (tareas ordenadas) | ✅ Actualizado v2.0 | `[x]` |

#### 4.b Bitácora IA y DUIA (5 pts)

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 4.4 | Crear `docs/bitacora_ia.md`: ≥3 entradas (qué pedí, acepté, descarté, por qué) | Formato: fecha, prompt, respuesta, decisión, motivo | `[ ]` |
| 4.5 | Crear `docs/DUIA.md`: Declaración Uso IA de cátedra | Plantilla oficial completada | `[ ]` |

#### 4.c README y Ensayo (5 pts)

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 4.6 | Actualizar `README.md` raíz: orden para crear todo desde cero | Pasos: 1) PG sintética, 2) snapshot, 3) SQLite, 4) semáforo, 5) casos, 6) docs | `[ ]` |
| 4.7 | Preparar ensayo 10 min: mapa, caso en vivo (C2/C3), hallazgo IA | Guion/notes para semana 13 | `[ ]` |

---

### FASE 5: Entrega Final

| # | Tarea | Verificación | Estado |
|---|-------|--------------|--------|
| 5.1 | Generar `informe.pdf` (máx 6 pág): 1.a, 2.c, 3.a, 3.b, 3.c | PDF legible, secciones completas | `[ ]` |
| 5.2 | Verificar estructura entrega completa | `food-store/movil/`: 4 sql + csv + db; `docs/`: informe.pdf, kiro/, bitacora_ia.md, DUIA.md | `[ ]` |
| 5.3 | Crear .zip o tag `tp8` en GitHub | Entrega en campus antes cierre semana 13 | `[ ]` |

---

## ESTRATEGIA DE AISLAMIENTO POSTGRESQL (CORREGIDA)

### ❌ NO HACER
```bash
# PROHIBIDO - Copia datos reales/PII de foodstore_tp
createdb -T foodstore_tp foodstore_unidad8
```

### ✅ HACER - Base sintética desde cero
```sql
-- 1. Crear BD vacía
CREATE DATABASE foodstore_u8_test;

-- 2. Conectar y crear SOLO tablas mínimas necesarias
\c foodstore_u8_test

-- categorias (mínimo 5)
CREATE TABLE categorias (
    id_categoria SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    descripcion TEXT,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- sucursales (mínimo 3)
CREATE TABLE sucursales (
    id_sucursal SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    direccion VARCHAR(200),
    telefono VARCHAR(20),
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- productos (15-20 filas sintéticas)
CREATE TABLE productos (
    id_producto SERIAL PRIMARY KEY,
    id_categoria INTEGER NOT NULL REFERENCES categorias(id_categoria),
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
    stock INTEGER NOT NULL CHECK (stock >= 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- 3. Insertar DATOS INVENTADOS (sintéticos)
INSERT INTO categorias (nombre, descripcion, activo) VALUES
('Pizzas', 'Pizzas artesanales', TRUE),
('Hamburguesas', 'Hamburguesas caseras', TRUE),
('Bebidas', 'Gaseosas y jugos', TRUE),
('Postres', 'Helados y tortas', TRUE),
('Ensaladas', 'Ensaladas frescas', TRUE);

INSERT INTO sucursales (nombre, direccion, telefono, activo) VALUES
('Sucursal Centro', 'Av. Siempre Viva 123', '261-4000001', TRUE),
('Sucursal Norte', 'Calle Falsa 456', '261-4000002', TRUE),
('Sucursal Sur', 'Blvd. Los Andes 789', '261-4000003', TRUE);

-- 15 productos con precios/stock variados para casos de prueba
INSERT INTO productos (id_categoria, nombre, descripcion, precio, stock, activo) VALUES
(1, 'Pizza Margarita', 'Tomate, mozzarella, albahaca', 12500.00, 20, TRUE),
(1, 'Pizza Fugazzeta', 'Cebolla, queso, orégano', 13200.00, 15, TRUE),
(1, 'Pizza Napolitana', 'Tomate, anchoas, alcaparras', 14000.00, 10, TRUE),
(2, 'Hamburguesa Clásica', 'Carne, lechuga, tomate, queso', 8500.00, 25, TRUE),
(2, 'Hamburguesa Doble', 'Doble carne, cheddar, bacon', 11000.00, 12, TRUE),
(2, 'Hamburguesa Vegana', 'Hamburguesa de lentejas, vegano', 9500.00, 8, TRUE),
(3, 'Gaseosa Cola 500ml', 'Botella retornable', 1800.00, 50, TRUE),
(3, 'Jugo Naranja 1L', 'Natural, sin azúcar', 2200.00, 30, TRUE),
(3, 'Agua Mineral 500ml', 'Sin gas', 1000.00, 60, TRUE),
(4, 'Helado Chocolate', '2 bolas, cobertura', 3500.00, 18, TRUE),
(4, 'Torta Selva Negra', 'Porción individual', 4200.00, 5, TRUE),
(4, 'Flan Casero', 'Con dulce de leche', 2800.00, 12, TRUE),
(5, 'Ensalada César', 'Lechuga, pollo, crutones, aderezo', 7500.00, 22, TRUE),
(5, 'Ensalada Griega', 'Tomate, pepino, aceitunas, feta', 7800.00, 15, TRUE),
(5, 'Ensalada Mixta', 'Lechuga, tomate, zanahoria, huevo', 6500.00, 20, TRUE);

-- 4. Crear vista v_snapshot_movil
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

### Verificación de aislamiento
```bash
# Confirmar que foodstore_tp original no cambió
psql -d foodstore_tp -c "SELECT count(*) FROM productos;"
# Debe dar el MISMO valor que antes (40 en el TP original)

# Confirmar BD sintética tiene solo datos inventados
psql -d foodstore_u8_test -c "SELECT count(*) FROM productos;"
# Debe dar 15 (nuestros datos sintéticos)
```

---

## Comandos de Referencia Rápida

```bash
# PostgreSQL - Crear BD sintética desde cero
psql -c "CREATE DATABASE foodstore_u8_test;"
psql -d foodstore_u8_test -f create_schema_sintetico.sql  # ver arriba

# PostgreSQL - Vista snapshot
psql -d foodstore_u8_test -c "CREATE OR REPLACE VIEW v_snapshot_movil AS ..."

# PostgreSQL - Exportar CSV
psql -d foodstore_u8_test -c "\copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER"

# SQLite - Crear base y tablas
sqlite3 movil/foodstore_movil.db < movil/schema_sqlite.sql

# SQLite - Importar snapshot (manejar booleanos t/f)
sqlite3 movil/foodstore_movil.db ".import --csv --skip 1 movil/servidor_snapshot.csv snapshot_servidor"

# SQLite - Cargar cache (convertir t/f a 1/0)
sqlite3 movil/foodstore_movil.db "INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia) SELECT id, nombre, precio_centavos, stock, CASE WHEN disponible='t' THEN 1 ELSE 0 END, CASE WHEN eliminado='t' THEN 1 ELSE 0 END, datetime('now') FROM snapshot_servidor;"

# SQLite - Ejecutar pruebas
sqlite3 movil/foodstore_movil.db < movil/pruebas_sqlite.sql

# SQLite - Ejecutar semáforo
sqlite3 movil/foodstore_movil.db < movil/semaforo.sql

# Verificar integridad PG tras pruebas
psql -d foodstore_u8_test -c "SELECT count(*) FROM pedidos; SELECT sum(stock) FROM productos;"
# Nota: pedidos=0 (no hay tabla pedidos en BD sintética), stock=suma inicial
```

---

## Criterios de Done por Fase

| Fase | Done Cuando |
|------|-------------|
| 0 | Entorno verificado, README documentado, Unidad 7 real localizada y documentada |
| 1 | `schema_sqlite.sql` crea 4 tablas STRICT + snapshot_servidor con FKs; `pruebas_sqlite.sql` pasa C1 y C7 |
| 2 | BD sintética PG creada; snapshot exportado/importado; semáforo clasifica con prioridad RECHAZADO>CONFLICTO; C2-C6 documentados y PG sintética inalterada |
| 3 | Mapa 3 motores con datos reales U7 (foodstore_u7.pedidos, 5 docs), plan extendido, code review IA con 3+ hallazgos (1 descartado) |
| 4 | Specs Kiro v2.0 completas, bitácora ≥3 entradas, DUIA, README funcional, ensayo listo |
| 5 | ZIP/tag listo, informe ≤6 pág, estructura verificada |

---

## Notas de Implementación

- **No modificar** `foodstore_tp` original ni unidades 1-7
- **Base PG sintética**: `foodstore_u8_test` creada con `CREATE DATABASE` + DDL mínimo + datos inventados
- **Datos sintéticos**: 5 categorías, 3 sucursales, 15 productos con precios/stock variados para cubrir casos C2-C6
- **SQLite**: Usar `sqlite3` CLI o Python `sqlite3` module (3.50.4 disponible)
- **UUID**: Generar con Python `uuid.uuid4()` o PowerShell `[Guid]::NewGuid()`
- **Booleanos CSV**: `psql` exporta `t`/`f` → convertir en importación o query SQLite con `CASE WHEN`
- **Evidencias**: Guardar salidas de comandos en `movil/evidencias/` o `docs/evidencias/`
- **Unidad 7 real**: Repo `Base_de_datos`, commit `c6e82a7`, carpeta `food_store_unidad7b2`, colección `foodstore_u7.pedidos` (5 docs)

---
## RESUMEN DE ESTADO — Unidad 8 (actualizado 2026-11-12)

### FASE 0: Entorno y Verificaciones Previas
Todas las tareas 0.1 a 0.5 completadas y verificadas. `[x]`

### FASE 1: Consigna 1 - La Base de la Tablet (30 pts)
- 1.a Qué datos viajan: completado (README + docs/mapa_capa_datos.md). `[x]`
- 1.b Script `movil/schema_sqlite.sql`: 5 tablas STRICT creadas, `foodstore_movil.db` generado. `[x]`
- 1.c Script `movil/pruebas_sqlite.sql`: C1 y C7 verificados (COMMIT, ROLLBACK, catálogo offline). `[x]`

### FASE 2: Consigna 2 - Sincronizar y resolver (35 pts)
- 2.a Instantánea: `v_snapshot_movil` verificada, CSV exportado e importado a `snapshot_servidor` + `producto_cache`. `[x]`
- 2.b Semáforo: `movil/semaforo.sql` implementado, prioridad RECHAZADO > CONFLICTO. `[x]`
- 2.c Casos C2-C6: todos ejecutados y verificados (C2 CONFLICTO→SIMULADO_APROBADO, C3 RECHAZADO, C4 RECHAZADO, C5 SIMULADO_APROBADO, C6 error PK). `foodstore_tp` y `foodstore_u8_test` sin modificaciones. `[x]`

### FASE 3: Consigna 3 - Integrar y revisar (20 pts)
- 3.a Mapa de 3 motores: `docs/mapa_capa_datos.md` (PostgreSQL, SQLite, MongoDB U7 con 5 docs). `[x]`
- 3.b Plan de mantenimiento extendido: en `design.md` sección 7 (incluye tablets). `[x]`
- 3.c Code review con IA: `bitacora_ia.md` con 5 hallazgos de 3 unidades, 2 descartados. `[x]`

### FASE 4: Consigna 4 - Kiro, bitácora y defensa (15 pts)
- `requirements.md`, `design.md`, `tasks.md` actualizados. `[x]`
- `bitacora_ia.md` creada (≥3 entradas). `[x]`
- `DUIA.md` creada. `[x]`
- README actualizado con tareas y verificaciones. `[x]`
- `informe.pdf`: pendiente (generar, máximo 6 páginas). `[ ]`
- Commit + push a `main` + tag `tp8`: pendiente. `[ ]`
