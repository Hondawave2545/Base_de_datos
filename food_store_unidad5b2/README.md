# Unidad 5 — Administración y seguridad de Food Store

> **Base de Datos II — Tecnicatura Universitaria en Programación**
> Trabajo Práctico — Unidad 5: Administración y seguridad
> Roles, auditoría, incidentes y protección de datos personales

---

## Estado del trabajo

| Parte | Descripción | Scripts | Documentación | Evidencias |
|---|---|---|---|---|
| **Setup** | Estructura, specs, procedimiento de clonado | `00_crear_usuario_tabla.sql` ✅ | `procedimiento_clonado.md` ✅ | — |
| **A** | Roles y permisos | `01_roles.sql` ✅ | `kiro_roles_spec/` ✅ | `evidencias/01_roles_permisos.txt` ✅ |
| **B** | Auditoría | `02_auditoria_config.sql` ✅, `03_auditoria_test.sql` ✅ | `informe_auditoria.md` ✅ | `log_auditoria_prueba.txt` ✅ |
| **C** | Simulacro | `04_simulacro_incidente.sql` ✅ | `informe_incidente.md` ✅ | `log_simulacro_anonimizado.txt` ✅ |
| **D** | Anonimización | `05_usuario_anon.sql` ✅ | `verificacion_equivalencia.md` ✅ | `evidencias/04_usuario_anon.txt` ✅ |
| **E** | Bitácora y Git | — | `BITACORA.md` ✅ | `evidencias/` ✅ |

**Estado general:** ✅ **COMPLETADO** — Todas las partes ejecutadas, probadas y documentadas con resultados reales.

---

## Datos de la entrega

| Campo | Valor |
|---|---|
| Materia | Base de Datos II |
| Unidad | 5 — Semana 9 |
| Integrante | Aquino |
| Modalidad | Individual |
| Fecha de inicio | 2026-11-11 |
| Fecha de finalización | 2026-11-11 |
| Motor | PostgreSQL 18.6 |
| Base de desarrollo | `foodstore_u5_test` (clon de `foodstore_tp`) |
| Herramienta de IA | Kiro (en lugar de OpenCode — ver BITACORA.md) |

---

## Estructura del trabajo

```
unidad5/
├── sql/
│   ├── 00_crear_usuario_tabla.sql  ✅ ejecutado  Tabla usuario + funciones de autenticación
│   ├── 01_roles.sql                ✅ ejecutado  Roles, GRANT, REVOKE, ALTER DEFAULT PRIVILEGES
│   ├── 02_auditoria_config.sql     ✅ ejecutado  Verificación y documentación de parámetros de log
│   ├── 03_auditoria_test.sql       ✅ ejecutado  Secuencia de prueba de auditoría
│   ├── 04_simulacro_incidente.sql  ✅ ejecutado  Simulacro completo (Parte C)
│   └── 05_usuario_anon.sql         ✅ ejecutado  Anonimización y verificación de equivalencia
├── docs/
│   ├── kiro_roles_spec/
│   │   ├── requirements.md         ✅ listo  Spec Kiro — qué roles necesita Food Store
│   │   └── design.md               ✅ listo  Spec Kiro — diseño e implementación (Rev. 3)
│   ├── procedimiento_clonado.md    ✅ listo  Procedimiento seguro para crear foodstore_u5_test
│   ├── informe_auditoria.md        ✅ completo Parte B — con resultados reales
│   ├── log_auditoria_prueba.txt    ✅ real  Log capturado de la secuencia de auditoría
│   ├── log_simulacro_anonimizado.txt ✅ real  Log anonimizado del simulacro
│   ├── informe_incidente.md        ✅ completo Parte C — con resultados reales y contraste
│   └── verificacion_equivalencia.md ✅ completo Parte D — equivalencia confirmada (0 filas diff)
├── evidencias/
│   ├── INDICE.md                   ✅ actualizado
│   ├── 01_roles_permisos.txt       ✅ salida psql con verificaciones
│   ├── 02_auditoria_test.txt       ✅ salida psql de auditoría
│   ├── 03_simulacro.txt            ✅ salida psql de simulacro
│   ├── 04_usuario_anon.txt         ✅ salida psql de anonimización
│   └── capturas/                   (opcional)
├── BITACORA.md                     ✅ completo  Interacciones 1–8 registradas
└── README.md                       ✅ este archivo
```

---

## Resumen de resultados de pruebas

| Prueba | Resultado | Detalle |
|---|---|---|
| Guarda de base en cada script | ✅ PASS | RAISE EXCEPTION si la base no es `foodstore_u5_test` |
| Tabla `usuario` creada | ✅ PASS | 4 columnas + funciones `fn_autenticar` y `fn_resetear_password` |
| Roles creados | ✅ PASS | 5 NOLOGIN + 2 LOGIN; membresías según spec |
| `rol_soporte` sobre `empleados` | ✅ PASS | SELECT sobre columnas específicas; `dni` NO aparece en `role_column_grants` |
| `admin_datos` sobre `usuario` | ✅ PASS | SELECT sobre `id_usuario, email, rol, fecha_alta, activo`; `password_hash` NO |
| `fn_autenticar` EXECUTE | ✅ PASS | Solo `rol_app_lectura`; `PUBLIC` NO aparece |
| `fn_resetear_password` EXECUTE | ✅ PASS | Solo `admin_datos`; `PUBLIC` NO aparece |
| Secuencia de auditoría | ✅ PASS | Log contiene marcas `U5-AUDITORIA-TEST: inicio` y `fin`; INSERT/UPDATE registrados |
| Simulacro Fase 4 | ✅ PASS | NOTICE: "OK: escalamiento rechazado correctamente (insufficient_privilege)" |
| Diferencia simétrica `usuario_anon` | ✅ PASS | 0 filas — agregados idénticos entre tabla real y anonimizada |

---

## Qué se realizó en cada parte de la Unidad 5

### Setup — Preparación del entorno
- Creación de la estructura de carpetas `unidad5/` con specs Kiro, scripts SQL, docs y evidencias.
- Redacción de `requirements.md` y `design.md` especificando roles, justificaciones y diseño de implementación.
- Procedimiento documentado para clonar `foodstore_tp` → `foodstore_u5_test` de forma segura.
- **Ejecución real:** `foodstore_u5_test` creada como clon exacto (50k pedidos, 150k detalles, 2k clientes, 40 productos, 50k pagos).

### Parte A — Roles y permisos de mínimo privilegio
- Tabla `usuario` y funciones `fn_autenticar` / `fn_resetear_password` creadas (script `00_crear_usuario_tabla.sql`).
- Script `01_roles.sql` implementa:
  - 5 roles de grupo: `rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`, `rol_auditoria` (todos NOLOGIN).
  - 2 roles de login: `app_web` (hereda lectura+escritura), `admin_datos` (hereda todos los roles de grupo).
  - REVOKE ALL de PUBLIC sobre tablas, schema y funciones.
  - GRANT selectivos: vistas para lectura, tablas base para escritura/soporte, columna `estado` de `pedidos` para soporte (permiso de columna).
  - Permiso de columna sobre `usuario` para `admin_datos`: `id_usuario, email, rol, fecha_alta, activo` (sin `password_hash`).
  - Permiso de columna sobre `empleados` para `rol_soporte`: excluye `dni`.
  - EXECUTE sobre `fn_autenticar` para `rol_app_lectura`; sobre `fn_resetear_password` para `admin_datos`.
  - `ALTER DEFAULT PRIVILEGES` solo SELECT para roles de lectura (no escritura automática).
  - Sequences confirmados: `pedidos_id_pedido_seq`, `detalle_pedido_id_detalle_seq`, `pagos_id_pago_seq`.
- Contraseñas configuradas fuera del script con `ALTER ROLE ... PASSWORD`.

### Parte B — Configuración y prueba de auditoría
- Parámetros de auditoría configurados a nivel de instancia:
  - `log_connections = on`, `log_disconnections = on`, `log_statement = 'mod'`, `log_line_prefix = '%t [%p] %u@%d '`, `logging_collector = on`.
- Script `03_auditoria_test.sql` ejecutado generando: conexión, INSERT con ROLLBACK, UPDATE con ROLLBACK, login fallido, login exitoso, desconexión.
- Log capturado en `docs/log_auditoria_prueba.txt` con marcas `U5-AUDITORIA-TEST`.
- **Nota:** `log_statement = 'mod'` registra INSERT/UPDATE/DDL pero NO SELECT simples.

### Parte C — Simulacro de incidente
- Script `04_simulacro_incidente.sql` ejecuta 4 fases:
  1. 3 logins fallidos deliberados vía `fn_autenticar`.
  2. 1 login exitoso.
  3. Lectura masiva de `usuario` (columnas no sensibles).
  4. Intento de escalamiento: `SET ROLE app_web; GRANT admin_datos TO app_web;` → **RECHAZADO** con `insufficient_privilege`.
- Log capturado y anonimizado en `docs/log_simulacro_anonimizado.txt`.
- Contraste con análisis de Kiro: **aciertos en todos los aspectos** (5/5).

### Parte D — Anonimización y verificación de equivalencia
- Script `05_usuario_anon.sql` crea `usuario_anon` con:
  - `email` sintético determinista: `'usuario_' || id_usuario || '@anon.local'`
  - `rol` conservado, `fecha_alta` truncada a mes (`mes_alta`), `activo` conservado.
  - `password_hash` **excluido completamente**.
- Consultas de agregación por `rol` y `mes_alta` sobre ambas tablas producen **resultados idénticos**.
- Diferencia simétrica: **0 filas** — equivalencia confirmada.
- Consulta equivalente sobre tabla real validada con Kiro (interacción #8).

### Parte E — Bitácora y entrega
- `BITACORA.md` actualizada con 8 interacciones documentadas.
- Evidencias reales guardadas en `evidencias/`.
- Preparación para commit y push a GitHub.

---

## Cómo ejecutar las pruebas (secuencia completa)

```powershell
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$base = "foodstore_u5_test"
$user = "postgres"

# Verificar base
& $psql -h localhost -p 5432 -U $user -d $base -c "SELECT current_database();"

# Paso 0: crear tabla usuario y funciones
& $psql -h localhost -p 5432 -U $user -d $base -v ON_ERROR_STOP=1 `
  -f "unidad5\sql\00_crear_usuario_tabla.sql" `
  2>&1 | Tee-Object "unidad5\evidencias\00_crear_usuario.txt"

# Verificar firmas reales (antes de ejecutar 01_roles.sql)
& $psql -h localhost -p 5432 -U $user -d $base -c "
  SELECT proname, pg_get_function_arguments(oid) AS firma
  FROM pg_proc WHERE pronamespace='public'::regnamespace
  AND proname IN ('fn_autenticar','fn_resetear_password');"

# Verificar nombres de sequences
& $psql -h localhost -p 5432 -U $user -d $base -c "
  SELECT sequencename FROM pg_sequences WHERE schemaname = 'public' ORDER BY sequencename;"

# Parte A: roles y permisos
& $psql -h localhost -p 5432 -U $user -d $base -v ON_ERROR_STOP=1 `
  -f "unidad5\sql\01_roles.sql" `
  2>&1 | Tee-Object "unidad5\evidencias\01_roles_permisos.txt"

# Configurar auditoría (requiere superusuario)
& $psql -h localhost -p 5432 -U $user -d postgres -c "
  ALTER SYSTEM SET log_connections = 'on';
  ALTER SYSTEM SET log_disconnections = 'on';
  ALTER SYSTEM SET log_statement = 'mod';
  ALTER SYSTEM SET log_line_prefix = '%t [%p] %u@%d ';
  SELECT pg_reload_conf();"

# Parte B: secuencia de prueba de auditoría
& $psql -h localhost -p 5432 -U $user -d $base -v ON_ERROR_STOP=1 `
  -f "unidad5\sql\03_auditoria_test.sql" `
  2>&1 | Tee-Object "unidad5\evidencias\02_auditoria_test.txt"

# Capturar log en C:\Program Files\PostgreSQL\18\data\log\

# Parte C: simulacro de incidente
& $psql -h localhost -p 5432 -U $user -d $base -v ON_ERROR_STOP=1 `
  -f "unidad5\sql\04_simulacro_incidente.sql" `
  2>&1 | Tee-Object "unidad5\evidencias\03_simulacro.txt"

# Parte D: usuario_anon y verificación de equivalencia
& $psql -h localhost -p 5432 -U $user -d $base -v ON_ERROR_STOP=1 `
  -f "unidad5\sql\05_usuario_anon.sql" `
  2>&1 | Tee-Object "unidad5\evidencias\04_usuario_anon.txt"
```

> Si `psql` no está en el PATH: `C:\Program Files\PostgreSQL\18\bin\psql.exe`

---

## Reglas de protección de datos

- ❌ **NUNCA** ejecutar ningún script sobre `foodstore_tp`.
- ❌ **NUNCA** usar `foodstore_u4_test_20261110` para pruebas de Unidad 5.
- ✅ Siempre verificar `SELECT current_database();` antes de cada script.
- ✅ Las contraseñas de los roles de login **no están en ningún script**. Configurar con `ALTER ROLE ... PASSWORD '...'` en sesión separada.
- ✅ No subir a Git archivos con contraseñas, hashes, emails reales o datos personales.

---

## Historial de commits (realizado)

```
git add unidad5/
git commit -m "U5: Trabajo Práctico completo - Roles, Auditoría, Simulacro, Anonimización"
git push origin main
```

**Verificación pre-push:**
```powershell
# Revisar que solo hay archivos de unidad5
git diff --cached --name-only | Where-Object { $_ -notmatch "unidad5" }
# Debe retornar vacío

# Revisar que no hay contraseñas
git diff --cached | Select-String -Pattern "PASSWORD|password_hash|pw_" | 
  Where-Object { $_ -notmatch "^--" }
```

---

## Enlace al repositorio

Carpeta `food_store_unidad5b2` en: https://github.com/Hondawave2545/Base_de_datos.git
