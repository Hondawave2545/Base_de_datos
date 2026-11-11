# Procedimiento seguro de clonado — foodstore_u5_test

> **Estado:** pendiente de ejecución — requiere autorización del estudiante.
> Este documento describe los pasos; no los ejecuta.

---

## Objetivo

Crear la base de datos `foodstore_u5_test` como copia exacta de `foodstore_tp`, para que todas las
pruebas de la Unidad 5 se realicen sobre una instancia aislada sin riesgo de afectar la base original.

---

## Por qué un clon y no la base original

- La Parte A crea roles y permisos nuevos.
- La Parte B modifica parámetros del servidor y deja logs.
- La Parte C ejecuta operaciones deliberadamente anómalas (intentos de login fallidos, lecturas masivas, intento de escalamiento).
- La Parte D crea una tabla `usuario_anon` en `public`.
- Ninguna de estas operaciones debe quedar registrada en `foodstore_tp`.

---

## Prerrequisitos

- Tener acceso como superusuario (`postgres`) a la instancia local de PostgreSQL 18.
- `foodstore_tp` debe estar en estado consistente (sin transacciones abiertas, sin conexiones activas además de la propia).
- `psql` disponible en el PATH o usando la ruta completa `C:\Program Files\PostgreSQL\18\bin\psql.exe`.

---

## Paso 1 — Verificar que foodstore_tp existe y está accesible

```sql
-- Ejecutar desde otra base (por ejemplo, 'postgres')
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS tamaño
FROM pg_database
WHERE datname IN ('foodstore_tp', 'foodstore_u5_test');
```

Resultado esperado: una fila para `foodstore_tp`, ninguna para `foodstore_u5_test`.

---

## Paso 2 — Terminar conexiones activas a foodstore_tp

> `CREATE DATABASE ... TEMPLATE` requiere que la base plantilla no tenga conexiones activas.
> Este comando desconecta conexiones de otras sesiones, pero **no termina la propia**.

```sql
-- Ejecutar desde la base 'postgres' (u otra que no sea foodstore_tp)
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'foodstore_tp'
  AND pid <> pg_backend_pid();
```

Si hay conexiones activas de DBeaver u otras herramientas, cerrarlas primero desde esas herramientas.

---

## Paso 3 — Crear el clon

```sql
-- Ejecutar desde la base 'postgres' (u otra que no sea foodstore_tp)
CREATE DATABASE foodstore_u5_test
  TEMPLATE foodstore_tp
  OWNER postgres;
```

Esto copia estructura, datos, tipos, índices, vistas, funciones y extensiones exactamente.

> **Nota:** los roles de login (si ya existieran en `foodstore_tp`) también se copian como objetos de la
> base, pero los roles de servidor se gestionan a nivel de instancia, no de base. Los roles de Unidad 5
> se crean desde cero en `foodstore_u5_test`.

---

## Paso 4 — Verificar el clon

```sql
-- Conectarse a foodstore_u5_test y verificar
SELECT current_database();

SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Conteos básicos
SELECT
  (SELECT count(*) FROM pedidos)        pedidos,
  (SELECT count(*) FROM detalle_pedido) detalles,
  (SELECT count(*) FROM productos)      productos,
  (SELECT count(*) FROM clientes)       clientes,
  (SELECT count(*) FROM pagos)          pagos;
```

Resultados esperados (coherentes con Unidades 1–4):
- 50.000 pedidos, 150.000 detalles, 2.000 clientes, 40 productos, 50.000 pagos.

---

## Paso 5 — Verificar que foodstore_tp está intacta

```sql
-- Desde foodstore_tp
SELECT current_database();
SELECT count(*) FROM pedidos;  -- debe seguir siendo 50.000
```

---

## Consideraciones adicionales

### ¿Y los triggers de Unidad 4?

Si `foodstore_tp` tiene instalados los triggers de `mayorista_u4` (creados en Unidad 4), el clon los
heredará. Antes de comenzar las pruebas de Unidad 5 hay que decidir si:

- **Dejarlos:** no interfieren con los permisos ni la auditoría, pero pueden complicar la Parte C.
- **Eliminarlos del clon:** con `DROP SCHEMA mayorista_u4 CASCADE` en `foodstore_u5_test` (no en `foodstore_tp`).

Esta decisión se toma con el estudiante antes de ejecutar.

### ¿Y los índices y vistas de Unidad 3?

Se heredan con el clon. No interfieren con los objetivos de Unidad 5 y pueden conservarse.

### ¿Qué pasa si foodstore_tp no tiene datos?

Si la base `foodstore_tp` está vacía o con datos parciales, el clon también estará vacío.
En ese caso, después de crear el clon hay que ejecutar los scripts de carga:

```powershell
psql -h localhost -p 5432 -U postgres -d foodstore_u5_test -v ON_ERROR_STOP=1 `
  -f "food-store/scripts/00_base.sql"

psql -h localhost -p 5432 -U postgres -d foodstore_u5_test -v ON_ERROR_STOP=1 `
  -f "food-store/scripts/01_volumen.sql"
```

---

## Recordatorio de seguridad

Antes de ejecutar **cualquier** operación, verificar siempre:

```sql
SELECT current_database();
-- Resultado esperado: foodstore_u5_test
```

Si el resultado es `foodstore_tp`, `postgres` o cualquier otra base: **detener y reconectar**.
