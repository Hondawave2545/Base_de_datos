# Especificación Kiro — Design
## Parte A: Implementación del esquema de roles

> **Propósito:** este documento describe cómo se implementan en SQL los roles definidos en
> `requirements.md`. Es la especificación de diseño antes de escribir el script ejecutable.
>
> **Revisión 2 — 2026-11-11:** se amplió `ALTER DEFAULT PRIVILEGES`, se documentó el acceso al
> schema por herencia, se agregó el orden de ejecución, se listaron los sequences a verificar
> y se incorporaron los GRANT/REVOKE sobre funciones.
>
> **Revisión 3 — 2026-11-11:** se eliminó INSERT+UPDATE automático sobre tablas futuras (E1);
> se reordenó el GRANT EXECUTE de `fn_resetear_password` después de `CREATE ROLE admin_datos`
> (E2); se marcaron las firmas de funciones como provisionales (E3); se resolvió el acceso a
> `empleados.dni` con permiso de columna en `rol_soporte` (V3); se agregó `activo` al permiso
> de columna de `admin_datos` sobre `usuario` (V4).

---

## Orden de ejecución de los scripts

Antes de ejecutar `01_roles.sql`, los siguientes objetos deben existir en `foodstore_u5_test`:

| Orden | Script | Qué crea | Por qué es prerrequisito |
|---|---|---|---|
| 1 | `00_crear_usuario_tabla.sql` | Tabla `usuario`, funciones `fn_autenticar` y `fn_resetear_password` | `01_roles.sql` hace REVOKE y GRANT sobre `usuario` y sobre esas funciones. Si no existen, el script falla. Las firmas reales de las funciones deben estar definidas aquí antes de que `01_roles.sql` las referencia. |
| 2 | `views.sql` (Unidad 3, ya heredado en el clon) | Vistas `v_*` y `mv_facturacion_categoria_mes` | `rol_app_lectura` y `rol_reportes` reciben GRANT SELECT sobre estas vistas. Si no existen, los GRANT fallan. |
| 3 | `01_roles.sql` | Roles, permisos, sequences | Requiere que todo lo anterior exista. |

> **Verificación de seguridad antes de ejecutar cualquier script:**
> ```sql
> SELECT current_database();  -- debe retornar 'foodstore_u5_test'
> ```

---

## Decisiones de diseño

### 1. Separación entre roles de grupo y roles de login

Los roles de grupo (`rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`,
`rol_auditoria`) se crean con `NOLOGIN`. Representan conjuntos de privilegios, no identidades
que inician sesión.

Los roles de login (`app_web`, `admin_datos`) se crean con `LOGIN` y `CONNECTION LIMIT`. Se les
asigna una contraseña (en producción: SCRAM-SHA-256; en la base de pruebas: valor placeholder
que debe reemplazarse antes de usar en producción).

### 2. Acceso al schema `public` y propagación por herencia

El script ejecuta:
```sql
GRANT USAGE ON SCHEMA public TO
  rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, rol_auditoria;
```

Los roles de login `app_web` y `admin_datos` **no** reciben `GRANT USAGE ON SCHEMA public`
directamente. Lo obtienen por herencia de sus roles de grupo:
- `app_web` hereda `USAGE` a través de `rol_app_lectura` y `rol_app_escritura`.
- `admin_datos` hereda `USAGE` a través de los cuatro roles de grupo que tiene como miembro.

Esto es intencional: los privilegios sobre el schema están centralizados en los roles de grupo,
no duplicados en los de login. Si se agrega un nuevo rol de grupo en el futuro, se le otorga
`USAGE` en ese momento.

### 3. Privilegios sobre tablas base y vistas

| Rol | Tablas base — privilegios | Vistas — privilegios |
|---|---|---|
| `rol_app_lectura` | Ninguno | SELECT sobre `v_productos_vigentes`, `v_pedidos_cliente`, `v_detalle_pedido`, `v_clientes_publico` |
| `rol_app_escritura` | SELECT sobre `clientes`, `productos`, `categorias`; INSERT + UPDATE sobre `pedidos`, `detalle_pedido`, `pagos`; USAGE + SELECT sobre sequences (ver sección de sequences) | Ninguno |
| `rol_soporte` | SELECT sobre columnas específicas de `clientes`, `pedidos`, `detalle_pedido`, `pagos`, `empleados` (ver detalle de columnas en sección 3a); UPDATE sobre columna `estado` de `pedidos` únicamente | Ninguno |
| `rol_reportes` | Ninguno | SELECT sobre `mv_facturacion_categoria_mes`, `v_productos_vigentes`, `v_pedidos_cliente` |
| `rol_auditoria` | SELECT sobre `auditoria_log` (cuando se cree en Parte B) | Ninguno |

#### 3a. Permisos de columna en rol_soporte sobre tablas sensibles
*(Resolución V3)*

**Decisión sobre `empleados.dni`:** `rol_soporte` necesita poder identificar al repartidor
asignado a un pedido (nombre, sucursal, rol) para resolver incidencias de entrega. No necesita
el DNI para ninguna de esas operaciones — el DNI es un dato de identidad civil de alta
sensibilidad que no tiene función operativa en la gestión de soporte.

Por lo tanto, el acceso a `empleados` **no** se otorga como `SELECT` sobre toda la tabla.
Se otorga como permiso de columna, excluyendo `dni`:

```sql
-- Columnas de empleados accesibles para rol_soporte (dni excluido)
GRANT SELECT (id_empleado, id_sucursal, nombre, apellido, rol,
              fecha_contratacion, activo)
  ON empleados TO rol_soporte;
```

Esto requiere que en el script `01_roles.sql` el paso F1 liste columnas explícitas para
`empleados`, en lugar de un `GRANT SELECT ON empleados` sin restricción.

Para las demás tablas de `rol_soporte` (`clientes`, `pedidos`, `detalle_pedido`, `pagos`)
se otorga SELECT sobre la tabla completa, porque:
- `clientes`: soporte necesita nombre, apellido, email y dirección para contactar al cliente;
  no hay columna de credencial en esta tabla.
- `pedidos`, `detalle_pedido`, `pagos`: contienen datos operativos del pedido; soporte
  necesita verlos completos para resolver incidencias.

### 4. Permiso a nivel de columna sobre `usuario` (tabla sensible)
*(Resolución V4 — se agrega columna `activo`)*

```sql
-- Columnas accesibles para admin_datos: no sensibles + activo
GRANT SELECT (id_usuario, email, rol, fecha_alta, activo) ON usuario TO admin_datos;
-- La columna password_hash NO se incluye en ningún GRANT
```

**Decisión sobre `activo`:** se incluye porque el administrador de datos necesita poder
verificar si una cuenta está habilitada o deshabilitada al diagnosticar problemas de acceso
o al gestionar el ciclo de vida de las cuentas. Sin `activo`, `admin_datos` no podría
distinguir entre una cuenta que no existe y una que existe pero está inactiva, lo que haría
inoperante la tarea de administración de cuentas. Es información de estado del sistema, no
un dato personal sensible en sí mismo.

`password_hash` continúa excluida en todos los casos. Ningún otro rol recibe acceso a
`usuario` —ni por tabla completa ni por columnas parciales.

Este es el ejemplo de permiso a nivel de columna que exige la consigna.

### 5. Permisos sobre funciones de autenticación
*(E3 — firmas marcadas como provisionales)*

> **IMPORTANTE:** las firmas de las funciones que aparecen a continuación son **provisionales**.
> Los tipos exactos de los parámetros (`TEXT`, `VARCHAR`, u otro tipo) deben confirmarse
> leyendo la definición real en `00_crear_usuario_tabla.sql` una vez que ese script esté
> escrito. Un REVOKE o GRANT con firma incorrecta falla en PostgreSQL; no hay efecto silencioso.
> Antes de ejecutar `01_roles.sql`, verificar con:
> ```sql
> SELECT p.proname, pg_get_function_arguments(p.oid) AS firma
> FROM pg_proc p
> JOIN pg_namespace n ON n.oid = p.pronamespace
> WHERE n.nspname = 'public'
>   AND p.proname IN ('fn_autenticar', 'fn_resetear_password');
> ```

Por defecto PostgreSQL otorga `EXECUTE` sobre funciones nuevas a `PUBLIC`. Este comportamiento
debe revertirse explícitamente antes de hacer los GRANT selectivos:

```sql
-- Revocar el EXECUTE implícito de PUBLIC
-- [AJUSTAR FIRMAS según resultado de la consulta anterior]
REVOKE ALL ON FUNCTION fn_autenticar(TEXT, TEXT)         FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_resetear_password(TEXT, TEXT)  FROM PUBLIC;

-- Otorgar EXECUTE solo a los roles que lo necesitan
-- fn_autenticar: invocable por rol_app_lectura (y por herencia, por app_web)
GRANT EXECUTE ON FUNCTION fn_autenticar(TEXT, TEXT)        TO rol_app_lectura;
-- fn_resetear_password: se otorga a admin_datos — ver posición en pseudocódigo (Paso L9)
-- [AJUSTAR FIRMA según resultado de la consulta anterior]
```

Justificación:
- `fn_autenticar` recibe `EXECUTE` para `rol_app_lectura` porque la autenticación es una
  operación legítima de la aplicación web y `app_web` hereda ese rol. No se otorga a `PUBLIC`
  porque permitiría que cualquier conexión a la base intente autenticarse sin restricción de rol.
- `fn_resetear_password` recibe `EXECUTE` directamente para `admin_datos` (no para un rol
  de grupo) porque es una operación de administración que no corresponde a `app_web` ni a
  ningún otro rol de bajo privilegio. Se ubica en el Paso L9, después de crear `admin_datos`.
- Ambas funciones son `SECURITY DEFINER`: corren con los privilegios del propietario. El
  control del EXECUTE es la única barrera real entre el invocador y los datos de `usuario`.

### 6. ALTER DEFAULT PRIVILEGES
*(E1 — eliminado INSERT+UPDATE automático sobre tablas futuras)*

```sql
-- Tablas que postgres cree en el futuro heredan SELECT para los roles de lectura
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO rol_app_lectura, rol_reportes;

-- Tablas que postgres cree en el futuro heredan SELECT para soporte (solo lectura)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO rol_soporte;
```

**Por qué se eliminó el DEFAULT de INSERT+UPDATE para `rol_app_escritura`:**
La versión anterior incluía:
```sql
-- ELIMINADO — no se aplica
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public
--   GRANT INSERT, UPDATE ON TABLES TO rol_app_escritura;
```
Otorgar INSERT+UPDATE automáticamente sobre cualquier tabla futura viola el principio de
mínimo privilegio: la aplicación web no debería poder escribir en tablas de auditoría, de
configuración, ni en cualquier otra tabla nueva sin revisión previa. Los permisos de escritura
de `rol_app_escritura` sobre tablas futuras deben otorgarse de forma explícita, caso a caso,
después de evaluar qué escritura corresponde a ese rol sobre esa tabla específica.

**Nota sobre J3 (SELECT para rol_soporte en DEFAULT):** se mantiene con la siguiente
aclaración: SELECT sobre tablas futuras es de bajo riesgo (solo lectura), pero tampoco debe
asumirse automáticamente para cualquier tabla nueva. Si se crean tablas de configuración
interna o de administración, habrá que revocar el SELECT de `rol_soporte` sobre esas tablas
explícitamente, o bien aceptar que soporte puede leerlas. Este punto debe revisarse cada vez
que se agrega una tabla nueva al schema.

**Alcance y limitación de ALTER DEFAULT PRIVILEGES:** solo aplica a objetos creados por el
rol que ejecuta la sentencia (típicamente `postgres`) **después** de que se ejecute. No aplica
retroactivamente a tablas ya existentes, ni a tablas creadas por otros roles.

### 7. Sequences
*(Nombres pendientes de comprobación en el entorno real)*

`rol_app_escritura` necesita `USAGE` y `SELECT` sobre los sequences de las tablas donde tiene
INSERT, para que `nextval()` funcione al insertar filas.

**Los nombres exactos deben verificarse en la base antes de ejecutar el script:**

```sql
-- Ejecutar en foodstore_u5_test para obtener los nombres reales
SELECT sequence_name
FROM information_schema.sequences
WHERE sequence_schema = 'public'
ORDER BY sequence_name;
```

Sequences probables según el esquema observado en las unidades anteriores (sujetos a
confirmación — no usar sin verificar):

| Tabla | Columna PK | Nombre probable del sequence | Certeza |
|---|---|---|---|
| `pedidos` | `id_pedido` (BIGINT) | `pedidos_id_pedido_seq` | Media — depende del tipo declarado |
| `detalle_pedido` | `id_detalle` (BIGINT) | `detalle_pedido_id_detalle_seq` | Media |
| `pagos` | `id_pago` (BIGINT o SERIAL) | `pagos_id_pago_seq` | Media |

> Si las columnas se declararon con `GENERATED ALWAYS AS IDENTITY`, los sequences internos
> se gestionan de forma diferente y el GRANT sobre sequences podría no ser necesario.
> Confirmar con la consulta anterior antes de incluir o excluir este paso del script.

La sentencia de GRANT, una vez verificados los nombres reales:
```sql
-- [AJUSTAR NOMBRES tras verificación con information_schema.sequences]
GRANT USAGE, SELECT ON SEQUENCE
  pedidos_id_pedido_seq,
  detalle_pedido_id_detalle_seq,
  pagos_id_pago_seq
TO rol_app_escritura;
```

---

## Esquema de sentencias (pseudocódigo ordenado)

> Este pseudocódigo refleja el orden de ejecución correcto en el script SQL definitivo.
> Los ítems marcados con `[VERIFICAR]` requieren comprobación en el entorno real antes
> de ejecutar.

```
-- PRERREQUISITOS (verificar antes de ejecutar)
-- P1. current_database() = 'foodstore_u5_test'
-- P2. tabla usuario existe (00_crear_usuario_tabla.sql ya ejecutado)
-- P3. funciones fn_autenticar y fn_resetear_password existen
-- P4. firmas reales de P3 verificadas con pg_get_function_arguments()
-- P5. nombres de sequences verificados con information_schema.sequences
-- P6. vistas v_* y mv_facturacion_categoria_mes existen

-- PASO A: Revocar privilegios implícitos de PUBLIC
A1. REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC
A2. REVOKE ALL ON SCHEMA public FROM PUBLIC
A3. REVOKE ALL ON FUNCTION fn_autenticar([VERIFICAR firma])        FROM PUBLIC
A4. REVOKE ALL ON FUNCTION fn_resetear_password([VERIFICAR firma]) FROM PUBLIC

-- PASO B: Crear roles de grupo (NOLOGIN)
B1. CREATE ROLE rol_app_lectura   NOLOGIN
B2. CREATE ROLE rol_app_escritura NOLOGIN
B3. CREATE ROLE rol_soporte       NOLOGIN
B4. CREATE ROLE rol_reportes      NOLOGIN
B5. CREATE ROLE rol_auditoria     NOLOGIN

-- PASO C: Acceso al schema
C1. GRANT USAGE ON SCHEMA public TO
      rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, rol_auditoria

-- PASO D: Privilegios para rol_app_lectura (solo vistas)
D1. GRANT SELECT ON v_productos_vigentes   TO rol_app_lectura
D2. GRANT SELECT ON v_pedidos_cliente      TO rol_app_lectura
D3. GRANT SELECT ON v_detalle_pedido       TO rol_app_lectura
D4. GRANT SELECT ON v_clientes_publico     TO rol_app_lectura

-- PASO E: Privilegios para rol_app_escritura
E1. GRANT SELECT            ON clientes, productos, categorias TO rol_app_escritura
E2. GRANT INSERT, UPDATE    ON pedidos                         TO rol_app_escritura
E3. GRANT INSERT, UPDATE    ON detalle_pedido                  TO rol_app_escritura
E4. GRANT INSERT, UPDATE    ON pagos                           TO rol_app_escritura
E5. GRANT USAGE, SELECT     ON SEQUENCE [VERIFICAR nombres]    TO rol_app_escritura

-- PASO F: Privilegios para rol_soporte
-- F1 usa permisos de columna sobre empleados (dni excluido)
F1a. GRANT SELECT ON clientes, pedidos, detalle_pedido, pagos TO rol_soporte
F1b. GRANT SELECT (id_empleado, id_sucursal, nombre, apellido, rol,
                   fecha_contratacion, activo)
       ON empleados TO rol_soporte               -- dni excluido (V3)
F2.  GRANT UPDATE (estado) ON pedidos TO rol_soporte  -- solo la columna estado

-- PASO G: Privilegios para rol_reportes (solo vistas y MV)
G1. GRANT SELECT ON mv_facturacion_categoria_mes TO rol_reportes
G2. GRANT SELECT ON v_productos_vigentes         TO rol_reportes
G3. GRANT SELECT ON v_pedidos_cliente            TO rol_reportes

-- PASO H: Privilegios para rol_auditoria (tabla pendiente de Parte B)
H1. GRANT SELECT ON auditoria_log TO rol_auditoria  ← ejecutar después de crear la tabla

-- PASO I: Permisos sobre fn_autenticar (fn_resetear_password se otorga en L9)
I1. GRANT EXECUTE ON FUNCTION fn_autenticar([VERIFICAR firma]) TO rol_app_lectura

-- PASO J: ALTER DEFAULT PRIVILEGES
J1. ALTER DEFAULT PRIVILEGES IN SCHEMA public
      GRANT SELECT ON TABLES TO rol_app_lectura, rol_reportes
-- J2 ELIMINADO: no se otorga INSERT+UPDATE automático a rol_app_escritura (E1)
J3. ALTER DEFAULT PRIVILEGES IN SCHEMA public
      GRANT SELECT ON TABLES TO rol_soporte

-- PASO K: Permiso de columna sobre tabla sensible usuario
K1. GRANT SELECT (id_usuario, email, rol, fecha_alta, activo)
      ON usuario TO admin_datos            -- activo incluido (V4); password_hash excluida

-- PASO L: Crear roles de login y otorgar membresías
L1. CREATE ROLE app_web LOGIN CONNECTION LIMIT 10 PASSWORD '[placeholder]'
L2. GRANT rol_app_lectura    TO app_web
L3. GRANT rol_app_escritura  TO app_web

L4. CREATE ROLE admin_datos LOGIN CONNECTION LIMIT 5 PASSWORD '[placeholder]'
L5. GRANT rol_app_lectura    TO admin_datos
L6. GRANT rol_app_escritura  TO admin_datos
L7. GRANT rol_soporte         TO admin_datos
L8. GRANT rol_reportes        TO admin_datos
L9. GRANT EXECUTE ON FUNCTION fn_resetear_password([VERIFICAR firma])
      TO admin_datos                       -- aquí, después de L4 (E2)
```

---

## Idempotencia

El script usa `IF NOT EXISTS` en la cláusula de creación de roles donde PostgreSQL lo soporta.
La sección de limpieza (comentada por defecto) permite re-ejecutar con `DROP ROLE IF EXISTS`.

---

## Verificación post-ejecución

El script incluye al final las siguientes consultas de verificación:

```sql
-- 1. Privilegios por rol sobre tablas (incluye permisos de columna)
SELECT grantee, table_schema, table_name, privilege_type, column_name
FROM information_schema.role_column_grants
WHERE grantee IN ('rol_soporte', 'admin_datos')
  AND table_schema = 'public'
ORDER BY grantee, table_name, column_name;

-- 2. Privilegios por rol sobre tablas completas
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte',
                  'rol_reportes','rol_auditoria','admin_datos')
  AND table_schema = 'public'
ORDER BY grantee, table_name, privilege_type;

-- 3. Roles de login y membresías
\du app_web
\du admin_datos

-- 4. Permisos sobre funciones
SELECT routine_name, grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public'
  AND routine_name IN ('fn_autenticar', 'fn_resetear_password')
ORDER BY routine_name, grantee;
```

> **Nota sobre la consulta 1:** `information_schema.role_column_grants` muestra los permisos
> otorgados a nivel de columna. Se agregó esta consulta específicamente para verificar que el
> permiso de columna sobre `empleados` para `rol_soporte` y el permiso de columna sobre
> `usuario` para `admin_datos` quedaron configurados correctamente.

La salida de las cuatro consultas se guarda como evidencia en `evidencias/`.

---

## Restricciones que no se implementan (y por qué)

| Restricción | Decisión |
|---|---|
| Row-Level Security (RLS) | Fuera del alcance del TP. Mencionado en informe como mejora posible para `clientes` y `pedidos`. |
| Política de expiración de contraseñas | Requiere configuración del servidor (`password_encryption`, `pg_hba.conf`), fuera del scope de este script. Se documenta como limitación. |
| Restricciones de IP (`pg_hba.conf`) | Se documenta en informe de auditoría pero no se modifica en este TP para no alterar la conectividad del entorno de desarrollo. |
| `GRANT UPDATE` genérico a `rol_soporte` en `ALTER DEFAULT PRIVILEGES` | Deliberadamente omitido: otorgar UPDATE sobre toda columna de tablas futuras rompería el principio de mínimo privilegio que el permiso de columna sobre `pedidos.estado` busca sostener. |
| `GRANT INSERT, UPDATE` genérico a `rol_app_escritura` en `ALTER DEFAULT PRIVILEGES` | Deliberadamente omitido (E1): la escritura sobre tablas futuras debe evaluarse caso a caso, no otorgarse automáticamente. |

---

## Próximo paso

Con este diseño revisado y aprobado, se escriben las sentencias definitivas en `sql/01_roles.sql`.
Antes de ejecutarlo:
1. Verificar que `foodstore_u5_test` fue creada.
2. Ejecutar `00_crear_usuario_tabla.sql` (tabla `usuario` y funciones) y anotar las firmas reales.
3. Confirmar los nombres reales de los sequences con `information_schema.sequences`.
4. Ajustar en `01_roles.sql` los ítems marcados `[VERIFICAR]` con los valores reales.
