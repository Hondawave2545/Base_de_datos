# Especificación Kiro — Requirements
## Parte A: Roles y permisos de mínimo privilegio en Food Store

> **Propósito:** este documento es la especificación previa que la consigna exige redactar en Kiro
> antes de escribir el script de roles. Responde a "qué roles necesita Food Store y por qué", sin
> escribir todavía ninguna sentencia SQL.
>
> **Revisión 2 — 2026-11-11:** se corrigió el duplicado de `pagos`, se amplió la justificación de
> `admin_datos`, se incorporaron permisos sobre funciones y se agregó una nota sobre sequences.

---

## Contexto del sistema

Food Store es un sistema de gestión de pedidos de comida con las siguientes tablas en `public`:

| Tabla | Contenido | Sensibilidad |
|---|---|---|
| `clientes` | nombre, apellido, email, teléfono, dirección de entrega | **Alta** — datos personales |
| `usuario` | email, hash de contraseña, rol de aplicación | **Muy alta** — credenciales |
| `pedidos` | id_cliente, estado, total, datos_envio | Alta |
| `detalle_pedido` | id_pedido, id_producto, cantidades, precios | Media |
| `pagos` | id_pedido, método_pago, monto, estado_pago | Alta |
| `productos` | nombre, precio, stock, categoría | Baja–Media (stock es dato operativo) |
| `categorias` | nombre, descripción | Baja |
| `empleados` | nombre, apellido, DNI, rol, sucursal | Alta |
| `sucursales` | nombre, dirección, teléfono | Baja |

> **Nota:** `pagos` aparece una sola vez. La fila duplicada que existía en la versión anterior fue
> eliminada (corrección C1).

Vistas existentes (Unidad 3):
- `v_clientes_publico` — sin teléfono ni dirección
- `v_pedidos_cliente` — pedidos activos con datos del cliente (sin datos de contacto)
- `v_productos_vigentes` — productos activos con categoría
- `v_detalle_pedido` — detalle con nombre del producto
- `mv_facturacion_categoria_mes` — vista materializada de facturación

Funciones relevantes para la seguridad:
- `fn_autenticar(email, password)` — verifica credenciales; `SECURITY DEFINER`
- `fn_resetear_password(email, nueva_password)` — fuerza cambio de contraseña; `SECURITY DEFINER`

---

## Roles requeridos

La consigna exige como mínimo cuatro roles de grupo y dos roles de login.
Se identifican los siguientes, con justificación de negocio:

### Roles de grupo

| Rol | Qué habilita | Por qué ese alcance y no otro |
|---|---|---|
| `rol_app_lectura` | SELECT sobre vistas públicas (`v_productos_vigentes`, `v_pedidos_cliente`, `v_detalle_pedido`, `v_clientes_publico`) | La aplicación web necesita mostrar datos de menú y estado de pedidos. No necesita acceder a las tablas base directamente ni leer credenciales. Leer vistas en lugar de tablas base ya filtra teléfono y dirección del cliente. |
| `rol_app_escritura` | SELECT sobre `clientes`, `productos`, `categorias`; INSERT + UPDATE sobre `pedidos`, `detalle_pedido`, `pagos`; USAGE + SELECT sobre los sequences correspondientes | El flujo de creación de un pedido requiere leer clientes y productos, e insertar o actualizar pedidos y pagos. No requiere UPDATE sobre clientes ni acceso a `usuario`. El SELECT sobre `productos` incluye la columna `stock`; se acepta esto intencionalmente porque la lectura del stock es necesaria para validar disponibilidad antes de insertar un detalle. No se otorga UPDATE sobre `productos` ni sobre `stock` directamente: esa actualización debe hacerse mediante el flujo controlado del sistema, no por este rol. |
| `rol_soporte` | SELECT sobre `clientes`, `pedidos`, `detalle_pedido`, `pagos`, `empleados`; UPDATE sobre la columna `estado` de `pedidos` únicamente (permiso a nivel de columna) | El equipo de soporte necesita ver el estado de un pedido y actualizarlo cuando corresponde (por ejemplo, marcar un pedido como entregado a pedido del cliente), pero no debe poder modificar montos, datos personales ni credenciales. Limitar UPDATE a la columna `estado` reduce la superficie de error y fraude. |
| `rol_reportes` | SELECT sobre `mv_facturacion_categoria_mes`, `v_productos_vigentes`, `v_pedidos_cliente` | El equipo de análisis trabaja sobre la vista materializada de facturación y sobre vistas de productos y pedidos. No necesita datos de clientes identificables ni acceso a tablas operativas en tiempo real. Se usa la vista `mv_facturacion_categoria_mes` y no las tablas fuente, para no exponer datos de pedidos individuales. |

### Roles de login

| Rol | Qué es | Operaciones que hereda y por qué |
|---|---|---|
| `app_web` | Usuario de login con membresía en `rol_app_lectura` y `rol_app_escritura` | Representa la conexión de la aplicación web de Food Store. Necesita mostrar el menú y el estado de los pedidos (lectura) y procesar pedidos nuevos y pagos (escritura). No necesita acceso de soporte ni de reportes: esas funciones las ejercen personas, no la aplicación. No es superusuario, no puede crear objetos, no puede modificar roles ni leer credenciales. |
| `admin_datos` | Usuario de login con membresía en `rol_app_lectura`, `rol_app_escritura`, `rol_soporte` y `rol_reportes` | Representa al administrador de datos (DBA o analista senior). Necesita: leer vistas de la aplicación (`rol_app_lectura`) para verificar lo que ve el usuario final; leer y escribir en las tablas operativas (`rol_app_escritura`) para correcciones manuales autorizadas; ver el estado de pedidos y actualizarlos (`rol_soporte`) para resolver incidencias; acceder a reportes de facturación (`rol_reportes`) para análisis. Adicionalmente, `admin_datos` recibe acceso a columnas no sensibles de `usuario` mediante un permiso de columna explícito (ver sección de permisos sobre tabla sensible). No tiene privilegios de superusuario ni puede modificar la configuración del servidor. |

> **Justificación de por qué `admin_datos` hereda todos los roles de grupo:** el administrador de datos
> necesita poder reconstruir cualquier estado del sistema de forma controlada. Sin embargo, esto no
> le otorga permisos que no estén ya definidos para esos roles — la suma de privilegios es exactamente
> la unión de los GRANT de los cuatro roles, sin ningún privilegio adicional implícito.
> (Corrección C2)

### Rol adicional propuesto

| Rol | Justificación |
|---|---|
| `rol_auditoria` | Rol de solo lectura sobre la tabla `auditoria_log` (si se crea en Parte B). Permite revisar el log de auditoría sin acceso a tablas operativas. Principio: quien registra eventos no debería ser el mismo que los consulta sin restricciones. Este rol no se otorga a `app_web` ni a `admin_datos` por defecto; se asigna a un rol de login de auditoría separado si la cátedra lo requiere. |

---

## Principio de mínimo privilegio — aplicaciones concretas

1. **Ningún rol de aplicación tiene acceso directo a la tabla `usuario`.**
   Solo `admin_datos` puede leer columnas no sensibles de `usuario`, mediante un permiso de columna
   explícito. La columna `password_hash` no aparece en ningún GRANT.

2. **`rol_soporte` solo puede actualizar la columna `estado` de `pedidos`.**
   No puede tocar `total`, `datos_envio` ni ningún dato del cliente.

3. **Ningún rol de grupo puede CREATE, DROP, TRUNCATE ni modificar la estructura de las tablas.**
   Solo el superusuario `postgres` puede hacerlo.

4. **`app_web` no es miembro de `admin_datos`** y viceversa. Los privilegios no se acumulan entre
   los dos roles de login de forma cruzada.

5. **`ALTER DEFAULT PRIVILEGES`** asegura que las tablas creadas en el futuro hereden la misma
   política, sin necesidad de GRANT manual. Ver `design.md` para su alcance exacto.

6. **`fn_autenticar` es invocable por `rol_app_lectura`** (y por extensión por `app_web`), pero
   no por `PUBLIC`. `fn_resetear_password` es invocable solo por `admin_datos`. Ver sección
   de permisos sobre funciones más abajo.

---

## Permisos sobre funciones de autenticación
*(Corrección C3)*

Las funciones `fn_autenticar` y `fn_resetear_password` son `SECURITY DEFINER`: corren con los
privilegios de su propietario (`postgres`), no con los del invocador. Por eso el control de quién
puede invocarlas es especialmente importante: si un rol no autorizado puede llamarlas, podría ejecutar
operaciones sobre `usuario` que de otra forma le estarían vedadas.

| Función | EXECUTE otorgado a | Justificación |
|---|---|---|
| `fn_autenticar` | `rol_app_lectura` | La aplicación web necesita verificar credenciales al hacer login. `app_web` hereda `rol_app_lectura`, por lo que puede invocarla. No se otorga a `PUBLIC` porque eso permitiría que cualquier conexión a la base intente autenticarse sin restricción de rol. |
| `fn_resetear_password` | `admin_datos` directamente | Es una operación privilegiada de administración. Solo el administrador de datos debería poder forzar el cambio de contraseña de una cuenta. No se otorga a ningún rol de grupo porque implicaría que `app_web` también podría resetear contraseñas, lo que no corresponde a su función. |

> **Nota sobre REVOKE implícito:** por defecto, PostgreSQL otorga `EXECUTE` sobre funciones a `PUBLIC`.
> Antes de los GRANT anteriores, debe ejecutarse:
> `REVOKE ALL ON FUNCTION fn_autenticar(...) FROM PUBLIC;`
> `REVOKE ALL ON FUNCTION fn_resetear_password(...) FROM PUBLIC;`
> Esto es parte del script `01_roles.sql`.

---

## Restricciones y consideraciones

- **La tabla `usuario` debe existir antes de ejecutar `roles.sql`.** Ver nota de orden de ejecución
  en `design.md`.
- Los roles no deben poder hacer `SET ROLE` a otro rol más privilegiado que el suyo.
- Se evita `GRANT ALL` en cualquier tabla: cada privilegio se otorga por nombre.
- Se documenta al menos un caso en que la IA propuso un permiso más amplio de lo necesario
  (ver `BITACORA.md`).
- **Sobre sequences:** `rol_app_escritura` necesita `USAGE` y `SELECT` sobre los sequences que
  generan los IDs de las tablas en las que tiene INSERT. Los nombres exactos de los sequences deben
  verificarse en el catálogo de `foodstore_u5_test` antes de ejecutar el script, porque dependen de
  cómo se definieron los tipos de las columnas (`SERIAL`, `BIGSERIAL` o `IDENTITY`). Ver `design.md`
  para los nombres a verificar.
  (Corrección C4)

---

## Criterios de verificación (Parte A, punto 3)

Después de ejecutar `roles.sql`, se debe poder demostrar:

```sql
-- Cada rol tiene exactamente los privilegios previstos aquí
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes','rol_auditoria')
ORDER BY grantee, table_name, privilege_type;

-- Los roles de login existen y tienen la membresía correcta
\du app_web
\du admin_datos

-- Verificar permisos sobre funciones
SELECT routine_name, grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public'
  AND routine_name IN ('fn_autenticar', 'fn_resetear_password')
ORDER BY routine_name, grantee;
```

---

## Próximo paso

Este documento es el input para `docs/kiro_roles_spec/design.md`, que describe cómo se implementan
estos requisitos en SQL, y para `sql/01_roles.sql`, que es el script ejecutable.
