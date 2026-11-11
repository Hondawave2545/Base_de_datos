# Informe de auditoría — Parte B

> **Estado de ejecución:** COMPLETADO — 2026-11-11
> Los parámetros de auditoría se configuraron y la prueba se ejecutó exitosamente.

---

## Datos de la prueba

| Campo | Valor |
|---|---|
| Base de prueba | `foodstore_u5_test` |
| Motor | PostgreSQL 18.6, Windows x64 |
| Script de prueba | `sql/03_auditoria_test.sql` |
| Fecha de ejecución | 2026-11-11 19:25:32 |

---

## 1. Parámetros de auditoría configurados

Los parámetros de log de PostgreSQL son de contexto `superuser` o `sighup`: se aplican a **nivel de instancia** con `ALTER SYSTEM` o editando `postgresql.conf`, no por base de datos individualmente.

| Parámetro | Valor aplicado | Qué registra |
|---|---|---|
| `log_connections` | `on` | Cada conexión nueva al servidor |
| `log_disconnections` | `on` | Cada cierre de sesión |
| `log_statement` | `mod` | INSERT, UPDATE, DELETE, DDL (no SELECT) |
| `log_line_prefix` | `'%t [%p] %u@%d '` | Timestamp, PID, usuario@base |
| `logging_collector` | `on` | Redirigir a archivo (no stderr) |

**Cómo se aplicaron:**
```sql
ALTER SYSTEM SET log_connections     = 'on';
ALTER SYSTEM SET log_disconnections  = 'on';
ALTER SYSTEM SET log_statement       = 'mod';
ALTER SYSTEM SET log_line_prefix     = '%t [%p] %u@%d ';
SELECT pg_reload_conf();
```

**Ubicación del log en Windows:**
`C:\Program Files\PostgreSQL\18\data\log\`

---

## 2. Estado actual de los parámetros (verificado)

Consulta ejecutada:
```sql
SELECT name, setting, context
FROM pg_settings
WHERE name IN (
  'log_connections','log_disconnections','log_statement',
  'log_line_prefix','logging_collector','log_directory','log_filename'
)
ORDER BY name;
```

Resultado:
```
        name        |    setting     
--------------------+----------------
 log_connections    | on
 log_disconnections | on
 log_line_prefix    | %t [%p] %u@%d 
 log_statement      | mod
 logging_collector  | on
```

---

## 3. Fragmento del log capturado

Ver: `docs/log_auditoria_prueba.txt`

El script marca el inicio y el fin de la secuencia con:
```
LOG: U5-AUDITORIA-TEST: inicio de secuencia de prueba — base: foodstore_u5_test
LOG: U5-AUDITORIA-TEST: fin de secuencia de prueba
```

Fragmento capturado (relevante):
```
2026-11-11 19:25:32 -03 [18448] [desconocido]@[desconocido] LOG:  conexión recibida: host=::1 port=59300
2026-11-11 19:25:32 -03 [18448] postgres@foodstore_u5_test LOG:  conexión autenticada: identidad=«postgres» método=scram-sha-256
2026-11-11 19:25:32 -03 [18448] postgres@foodstore_u5_test LOG:  conexión autorizada: usuario=postgres base_de_datos=foodstore_u5_test
2026-11-11 19:25:32 -03 [18448] postgres@foodstore_u5_test LOG:  U5-AUDITORIA-TEST: inicio de secuencia de prueba — base: foodstore_u5_test
2026-11-11 19:25:32 -03 [18448] postgres@foodstore_u5_test LOG:  sentencia: INSERT INTO public.usuario (email, password_hash, rol) VALUES ('prueba_auditoria@foodstore.local', 'hash_prueba_temporal', 'soporte');
2026-11-11 19:25:32 -03 [18448] postgres@foodstore_u5_test LOG:  sentencia: UPDATE pedidos SET estado = 'en_camino' WHERE id_pedido = (SELECT id_pedido FROM pedidos LIMIT 1);
2026-11-11 19:25:32 -03 [18448] postgres@foodstore_u5_test LOG:  U5-AUDITORIA-TEST: fin de secuencia de prueba
2026-11-11 19:25:32 -03 [18448] postgres@foodstore_u5_test LOG:  desconexión: duración de sesión: 0:00:00.518 usuario=postgres base=foodstore_u5_test host=::1 port=59300
```

**Nota:** Con `log_statement = 'mod'` se registran INSERT y UPDATE (y DDL), pero NO los SELECT simples ni las llamadas a `fn_autenticar`. Para capturar también los SELECT se requeriría `log_statement = 'all'`.

---

## 4. Qué información de auditoría provee el log nativo

Sobre el fragmento obtenido:

| Campo de auditoría | Qué registra | Dónde aparece |
|---|---|---|
| **Quién** | Usuario de PostgreSQL que ejecutó la operación | `%u` en log_line_prefix |
| **Qué** | La sentencia SQL ejecutada | Cuerpo del mensaje `statement:` |
| **Cuándo** | Timestamp del evento | `%t` en log_line_prefix |
| **PID** | Identificador del proceso de servidor | `%p` en log_line_prefix |
| **En qué base** | Nombre de la base de datos | `%d` en log_line_prefix |

**Qué NO registra el log nativo (con `log_statement = 'mod'`):**
- Sentencias SELECT simples (requiere `log_statement = 'all'`).
- Qué filas específicas fueron leídas o modificadas (granularidad de fila).
- El valor anterior y el nuevo valor en un UPDATE.
- Operaciones dentro de funciones `SECURITY DEFINER` bajo su propia identidad.

**Para mayor granularidad:** se necesitaría la extensión `pgaudit`, que registra cada objeto accedido y su categoría (READ, WRITE, DDL). No se instala en este TP; se menciona como mejora posible.

---

## 5. El archivo de log como activo sensible

**¿El propio archivo de log es un activo sensible?**

Sí. El log puede contener sentencias SQL completas con valores de parámetros, información sobre la estructura de la base, y patrones de uso que revelan la lógica del negocio. Si `log_statement = 'all'`, también puede contener fragmentos de datos de las consultas.

**¿Quién debería poder leerlo y con qué permisos?**

Solo el administrador del sistema operativo que tiene responsabilidad sobre el servidor. Los permisos del archivo de log deberían ser al menos `600` en sistemas Unix (solo el propietario del proceso PostgreSQL puede leer y escribir). En Windows, el directorio `data\log\` debería estar restringido al usuario del servicio PostgreSQL y al administrador.

A nivel del motor PostgreSQL, la lectura del log desde SQL requiere el rol `pg_monitor` (PostgreSQL 10+) o superusuario. No debe exponerse a roles de aplicación.

---

## 6. Pendientes completados

- [x] Autorización para ejecutar `ALTER SYSTEM` y aplicar los parámetros de auditoría.
- [x] Creación de `foodstore_u5_test` y ejecución de `00_crear_usuario_tabla.sql` y `01_roles.sql`.
- [x] Ejecución de `03_auditoria_test.sql` y captura del fragmento de log.
- [x] Completar la tabla de "Estado actual de los parámetros" (sección 2).
- [x] Completar la sección 3 con el fragmento real del log.
- [x] Registrar la interacción en `BITACORA.md`.
