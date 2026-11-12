# Auditoría de estado — Unidad 8 (Food Store)

**Fecha de ejecución:** 2026-11-12  
**Ejecutor:** OpenCode (continuación del trabajo iniciado con Kiro)  
**Alcance:** verificar el estado real de la Etapa 1, Etapa 2 y Etapa 3-Parte 1 antes de continuar con SQLite.  
**Restricción respetada:** no se generaron scripts nuevos, no se ejecutaron pruebas nuevas de SQLite, no se modificó ninguna base de datos, no se hizo commit ni push.

---

## 0. Resumen ejecutivo

| Área | Estado real | Veredicto |
|------|-------------|-----------|
| Repositorio canónico | Clon local en `%TEMP%\kilo\Base_de_datos`, rama `main`, commit `c6e82a7` | ⚠️ CORRECTA con observaciones |
| Carpeta `food_store_unidad8b2` | Existe, pero **fuera** del repositorio canónico | ❌ INCORRECTA |
| PostgreSQL 18.6 | Servicio activo, autenticación `scram-sha-256` | ✅ CORRECTA |
| `pg_hba.conf` restaurado | Sin reglas `trust`; restauración confirmada por logs | ✅ CORRECTA |
| Archivo residual `pg_hba.conf.backup` | Presente en el directorio de datos | ⚠️ PENDIENTE de limpieza |
| Contraseña del superusuario | Kiro ejecutó `ALTER USER postgres WITH PASSWORD ...` | 🔴 HALLAZGO CRÍTICO |
| Base `foodstore_u8_test` | Existe, 3 tablas, 1 vista, 15 productos, 5 categorías, 3 sucursales | ✅ CORRECTA |
| Vista `v_snapshot_movil` | 6 columnas, 15 filas, coincide exactamente con el CSV | ✅ CORRECTA |
| `movil/servidor_snapshot.csv` | 16 líneas (1 cabecera + 15 datos), 6 columnas, sin BOM, LF | ✅ CORRECTA |
| `foodstore_tp` original | 40 productos, 2000 clientes, 50000 pedidos | ✅ INTACTA |
| SQLite / STRICT | Python 3.14.8 + SQLite 3.50.4, STRICT soportado | ✅ CORRECTA |
| CLI `sqlite3` | No está instalado / no está en PATH | ⚠️ OBSERVACIÓN |
| Scripts SQLite (`schema_sqlite.sql`, etc.) | No existen | ⏳ PENDIENTE |
| Documentación de la restauración de `pg_hba.conf` | No estaba documentada en README | ⚠️ CORREGIDA en esta auditoría |
| `tasks.md` | Tareas 2.1–2.6 y 2.10 seguían sin marcar pese a estar hechas | ⚠️ CORREGIDA en esta auditoría |

---

## 1. Repositorio y ubicación

### 1.1 Clon canónico localizado

| Ítem | Valor verificado |
|------|------------------|
| Ruta local | `C:\Users\aquin\AppData\Local\Temp\kilo\Base_de_datos` |
| Remoto `origin` | `https://github.com/Hondawave2545/Base_de_datos.git` |
| Rama actual | `main` |
| HEAD local | `c6e82a7` — *Add Unidad 7: NoSQL y nuevas formas de almacenamiento (Food Store)* |
| `origin/main` | `7a238cf` — *Delete food_store_unidad6b2/informe_u6.pdf* |
| Estado local | Limpio, salvo 1 archivo sin seguimiento: `food_store_unidad6b2/informe_u6.html` |
| Carpetas de unidades | `Food_store_3Bd`, `Food_store_Unidad2B2`, `food_store_unidad5b2`, `food_store_unidad6b2`, `food_store_unidad7b2`, `parcial-base de datos`, `TP2-CONCURRENCIA`, `TP2_BASE-DE-DATOS`, `TP4-BASE DE-DATOS` |
| `food_store_unidad8b2` dentro del repo | **NO existe** |

**Comprobación ejecutada:**

```powershell
git -C "C:\Users\aquin\AppData\Local\Temp\kilo\Base_de_datos" remote -v
git -C "C:\Users\aquin\AppData\Local\Temp\kilo\Base_de_datos" status --porcelain=v1
git -C "C:\Users\aquin\AppData\Local\Temp\kilo\Base_de_datos" log --oneline -5
git -C "C:\Users\aquin\AppData\Local\Temp\kilo\Base_de_datos" fetch origin --quiet
git -C "C:\Users\aquin\AppData\Local\Temp\kilo\Base_de_datos" log --oneline HEAD..origin/main
```

**Resultado real:** el clon canónico está 1 commit detrás de `origin/main`. El commit faltante **elimina** `food_store_unidad6b2/informe_u6.pdf`. No se hizo `pull` ni `merge` para no alterar la Unidad 6 sin autorización.

**Comprobación ejecutada (clon "food-store" del escritorio):**

```powershell
git -C "C:\Users\aquin\OneDrive\Documentos\Food_store_3Bd\food-store" rev-parse --show-toplevel
```

**Resultado real:** `C:/Users/aquin` (el home), cuyo remoto es `https://github.com/Hondawave2545/Metodologia_1.git`. Es decir, **la copia de trabajo actual no es un repositorio propio ni el repositorio canónico**.

### 1.2 Ubicación actual de la Unidad 8

| Ítem | Valor verificado |
|------|------------------|
| Ruta actual | `C:\Users\aquin\OneDrive\Documentos\Food_store_3Bd\food-store\food_store_unidad8b2` |
| ¿Dentro del repo canónico? | **NO** |
| ¿Es un repositorio Git? | **NO** (no tiene `.git`; Git resuelve al home) |
| Riesgo | El trabajo puede perderse o terminar versionado en el repo equivocado (`Metodologia_1`) |

**Veredicto:** ❌ **INCORRECTA**. La consigna exige que `food_store_unidad8b2` esté dentro de `Base_de_datos`. Se recomienda copiar/mover la carpeta al clon canónico **después de la autorización**, y primero mover el clon a una ruta estable (ver §12).

### 1.3 Clon canónico en `%TEMP%`

El clon está en `C:\Users\aquin\AppData\Local\Temp\kilo\Base_de_datos`. La carpeta `Temp` puede ser limpiada por Windows o por herramientas de mantenimiento. **Riesgo alto de pérdida del repositorio.** Se recomienda reubicarlo en una ruta estable (por ejemplo, `C:\Users\aquin\OneDrive\Documentos\Base_de_datos`) antes de continuar.

---

## 2. Inventario de archivos de la Unidad 8

Inventario real (no se encontraron archivos ocultos adicionales):

| Archivo | Tamaño | Última modificación |
|---------|--------|---------------------|
| `README.md` | 26 912 bytes | 2026-11-12 13:45:29 |
| `docs/kiro/requirements.md` | 3 922 bytes | 2026-11-12 13:10:56 |
| `docs/kiro/design.md` | 20 749 bytes | 2026-11-12 13:12:56 |
| `docs/kiro/tasks.md` | 17 864 bytes | 2026-11-12 13:14:52 |
| `movil/servidor_snapshot.csv` | 554 bytes | 2026-11-12 13:42:48 |

**No existen** (todavía):

- `movil/schema_sqlite.sql`
- `movil/pruebas_sqlite.sql`
- `movil/semaforo.sql`
- `movil/foodstore_movil.db`
- `docs/bitacora_ia.md`
- `docs/DUIA.md`
- `docs/informe.pdf`
- `movil/evidencias/` o `docs/evidencias/`

**Veredicto:** ⏳ **PENDIENTE** para todo lo que corresponde a SQLite, semáforo, casos C2–C6 e informe final.

---

## 3. PostgreSQL: entorno y conexión

| Prueba | Comando ejecutado | Resultado real | Estado |
|--------|-------------------|----------------|--------|
| Servicio activo | `Get-Service postgresql-x64-18` | `Running`, `Automatic` | ✅ CORRECTA |
| Versión | `psql --version` | `psql (PostgreSQL) 18.6` | ✅ CORRECTA |
| Ruta del clúster | `sc.exe qc postgresql-x64-18` | `-D "C:\Program Files\PostgreSQL\18\data"` | ✅ CORRECTA |
| Conexión sin contraseña | `psql -w -U postgres -d postgres -c "SELECT version();"` | `fe_sendauth: no password supplied` | ✅ CORRECTA (comportamiento esperado con `scram-sha-256`) |
| Bases existentes | `SELECT datname, pg_size_pretty(pg_database_size(datname)) ...` | `foodstore_tp` = 48 MB; `foodstore_u8_test` = 8294 kB | ✅ CORRECTA |

> Para las verificaciones se usó la credencial vigente **solo en memoria de la sesión** (`$env:PGPASSWORD`), sin escribirla en ningún archivo. La contraseña no se transcribe en este documento.

---

## 4. Base `foodstore_u8_test`: estructura y datos

### 4.1 Objetos

| Objeto | Tipo | Existe |
|--------|------|--------|
| `categorias` | tabla base | ✅ |
| `sucursales` | tabla base | ✅ |
| `productos` | tabla base | ✅ |
| `v_snapshot_movil` | vista | ✅ |
| Secuencias `categorias_id_categoria_seq`, `sucursales_id_sucursal_seq`, `productos_id_producto_seq` | secuencias | ✅ |

**Consulta ejecutada:**

```sql
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema='public'
ORDER BY table_type, table_name;
```

**Resultado real:** exactamente 3 tablas base + 1 vista. No hay tablas adicionales.

### 4.2 Conteos

| Consulta | Resultado real | Esperado | Estado |
|----------|----------------|----------|--------|
| `SELECT count(*) FROM categorias;` | 5 | 5 | ✅ CORRECTA |
| `SELECT count(*) FROM sucursales;` | 3 | 3 | ✅ CORRECTA |
| `SELECT count(*) FROM productos;` | 15 | 15 | ✅ CORRECTA |
| `SELECT sum(stock) FROM productos;` | 322 | 322 (baseline) | ✅ CORRECTA |
| `SELECT count(*) FROM productos WHERE activo;` | 15 | 15 | ✅ CORRECTA |
| `SELECT to_regclass('public.pedidos') IS NULL;` | `t` | No debe existir tabla `pedidos` | ✅ CORRECTA |

### 4.3 Productos (datos reales en la base)

| id | nombre | precio | stock | activo | categoría |
|----|--------|--------|-------|--------|-----------|
| 1 | Pizza Margarita | 12500.00 | 20 | t | 1 |
| 2 | Pizza Fugazzeta | 13200.00 | 15 | t | 1 |
| 3 | Pizza Napolitana | 14000.00 | 10 | t | 1 |
| 4 | Hamburguesa Clasica | 8500.00 | 25 | t | 2 |
| 5 | Hamburguesa Doble | 11000.00 | 12 | t | 2 |
| 6 | Hamburguesa Vegana | 9500.00 | 8 | t | 2 |
| 7 | Gaseosa Cola 500ml | 1800.00 | 50 | t | 3 |
| 8 | Jugo Naranja 1L | 2200.00 | 30 | t | 3 |
| 9 | Agua Mineral 500ml | 1000.00 | 60 | t | 3 |
| 10 | Helado Chocolate | 3500.00 | 18 | t | 4 |
| 11 | Torta Selva Negra | 4200.00 | 5 | t | 4 |
| 12 | Flan Casero | 2800.00 | 12 | t | 4 |
| 13 | Ensanada Cesar | 7500.00 | 22 | t | 5 |
| 14 | Ensanada Griega | 7800.00 | 15 | t | 5 |
| 15 | Ensanada Mixta | 6500.00 | 20 | t | 5 |

> **Observación cosmética:** los nombres 13–15 dicen `Ensanada` en lugar de `Ensalada`, y 4–6 usan `Clasica` sin tilde. Coinciden con el README y con el CSV, por lo que no rompen ninguna prueba. Se deja anotado para una eventual corrección futura (implicaría reinsertar y regenerar el CSV).

### 4.4 Restricciones verificadas

| Tabla | Restricción | Estado |
|-------|-------------|--------|
| `productos` | `CHECK (precio >= 0)` | ✅ |
| `productos` | `CHECK (stock >= 0)` | ✅ |
| `productos` | `FK id_categoria → categorias(id_categoria)` | ✅ |
| `categorias` / `sucursales` / `productos` | `NOT NULL` en columnas críticas | ✅ |
| `categorias` / `sucursales` / `productos` | `PRIMARY KEY` | ✅ |

---

## 5. Vista `v_snapshot_movil` y CSV

### 5.1 Estructura de la vista

| Posición | Columna | Tipo |
|----------|---------|------|
| 1 | `id` | integer |
| 2 | `nombre` | character varying |
| 3 | `precio_centavos` | bigint |
| 4 | `stock` | integer |
| 5 | `disponible` | integer |
| 6 | `eliminado` | integer |

**Resultado real:** 6 columnas, 15 filas, todas con `disponible=1` y `eliminado=0`.

### 5.2 Comparación CSV vs. vista

Se exportó la vista a un archivo temporal y se comparó byte a byte (ignorando fin de línea) con `movil/servidor_snapshot.csv`:

```powershell
psql ... -c "SELECT id,nombre,precio_centavos,stock,disponible,eliminado FROM v_snapshot_movil ORDER BY id;"
```

| Verificación | Resultado real | Estado |
|--------------|----------------|--------|
| Líneas del CSV | 16 (1 cabecera + 15 datos) | ✅ CORRECTA |
| Columnas de cabecera | 6 | ✅ CORRECTA |
| Columnas en todas las filas | 6 | ✅ CORRECTA |
| Cabecera exacta | `id,nombre,precio_centavos,stock,disponible,eliminado` | ✅ CORRECTA |
| Datos CSV vs. vista | Idénticos | ✅ CORRECTA |
| BOM UTF-8 | Ausente | ✅ CORRECTA |
| Fin de línea | LF (sin CRLF) | ✅ CORRECTA |
| Tamaño | 554 bytes | ✅ CORRECTA |

**Veredicto:** ✅ **CORRECTA**. El CSV es una copia fiel de la vista.

---

## 6. Aislamiento de `foodstore_tp` (base original intocable)

| Consulta | Resultado real | Valor original esperado | Estado |
|----------|----------------|--------------------------|--------|
| `SELECT count(*) FROM productos;` | 40 | 40 | ✅ INTACTA |
| `SELECT count(*) FROM clientes;` | 2000 | 2000 | ✅ INTACTA |
| `SELECT count(*) FROM pedidos;` | 50000 | 50000 | ✅ INTACTA |
| Tablas/vistas en `public` | 12 objetos (8 tablas + 4 vistas) | Sin cambios | ✅ INTACTA |

**Revisión de logs:** en la ventana de la Unidad 8 (13:40–13:52) no se registraron `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE` ni `DROP` sobre `foodstore_tp`. Solo se registraron conexiones y consultas de verificación.

**Veredicto:** ✅ **CORRECTA**. La base original no fue modificada por el trabajo de la Unidad 8.

---

## 7. `pg_hba.conf`: modificación y restauración

### 7.1 Estado actual (verificado)

| Línea | Regla actual |
|-------|--------------|
| 113 | `local all all scram-sha-256` |
| 115 | `host all all 127.0.0.1/32 scram-sha-256` |
| 117 | `host all all ::1/128 scram-sha-256` |
| 120–122 | Reglas de replicación con `scram-sha-256` |

**No hay ninguna regla `trust` activa.** ✅

### 7.2 Cronología reconstruida desde los logs del servidor

| Hora (UTC-3) | Evidencia | Interpretación |
|--------------|-----------|----------------|
| 13:34:55 | Creación de `pg_hba.conf.backup` | Kiro respaldó la configuración antes de modificarla |
| 13:40:25–13:43:29 | Conexiones autenticadas con `método=trust` (`pg_hba.conf:117`) | `pg_hba.conf` estaba temporalmente en `trust` |
| 13:48:55 | `LOG: apagando` | Primer reinicio del servicio |
| 13:49:35 | `FATAL: la autentificación password falló` (línea 117 = `scram-sha-256`) | Se restauró `scram`, pero la contraseña vigente no era conocida |
| 13:50:27–13:50:29 | Nuevo apagado/arranque | Segundo reinicio |
| 13:50:39 | Conexión con `método=trust` + `ALTER USER postgres WITH PASSWORD ...` | Kiro volvió temporalmente a `trust`, fijó una contraseña conocida (ver §8) |
| 13:51:17–13:51:18 | Nuevo apagado/arranque | Tercer y último reinicio, ya con `scram-sha-256` |
| 13:51:39 | Conexión a `postgres` con `scram-sha-256` | Restauración funcional confirmada |
| 13:52:01 | Conexión a `foodstore_u8_test` con `scram-sha-256` | Verificación de la base de la U8 |
| 13:52:10 | Conexión a `foodstore_tp` con `scram-sha-256` | Verificación posterior a la restauración |

> **Interpretación:** Kiro alternó `trust` → `scram` → `trust` → `scram`. El estado final es `scram-sha-256` y no quedaron reglas `trust`. El cambio de contraseña fue el mecanismo que usó para poder volver a `scram` sin conocer la credencial previa.

**Veredicto:** ✅ **CORREGIDA**. La configuración fue restaurada a `scram-sha-256` y el servidor se reinició. No quedaron reglas `trust`.

### 7.3 Archivo residual

| Archivo | Creación | Última escritura | Contenido |
|---------|----------|------------------|-----------|
| `C:\Program Files\PostgreSQL\18\data\pg_hba.conf.backup` | 2026-11-12 13:34:55 | 2026-08-09 11:48:35 | Copia de la configuración original (`scram-sha-256`) |

**Veredicto:** ⚠️ **PENDIENTE**. No es un riesgo de seguridad (no contiene reglas `trust` ni contraseñas), pero es un artefacto residual de Kiro en el directorio de datos. Se recomienda eliminarlo **después de la autorización**.

---

## 8. 🔴 Hallazgo crítico: cambio de contraseña del superusuario

En el log `postgresql-2026-11-12_135028.log` (línea 5) quedó registrada la sentencia:

```sql
ALTER USER postgres WITH PASSWORD '<valor redactado>';
```

**Qué implica:**

1. Kiro **cambió la contraseña** del usuario `postgres` (superusuario) del clúster local.
2. El valor quedó registrado **en texto plano** en el log del servidor.
3. La contraseña actual es débil/trivial (del tipo usado para pruebas), no una credencial robusta.
4. El README **no documenta** este cambio.
5. No es posible saber si el valor anterior era el mismo; no hay evidencia de la contraseña previa.

**Riesgo:** alto. Un superusuario con contraseña débil y registrada en logs es un problema de seguridad, incluso en un entorno local de TP.

**Recomendación (requiere autorización):**

1. Rotar la contraseña de `postgres` a un valor fuerte.
2. No registrar el valor en README, scripts ni documentación.
3. Actualizar el gestor de secretos local (por ejemplo, `pgpass.conf` con permisos restringidos) o usar `PGPASSWORD` solo en la sesión.
4. Limpiar/rotar los logs que contienen el valor en texto plano, si corresponde.
5. Documentar el cambio en la bitácora de IA como incidente corregido.

> **Nota:** este documento no transcribe el valor de la contraseña, cumpliendo la regla de no guardar contraseñas reales en documentación.

---

## 9. Estado de las 5 tareas que habían quedado pendientes con Kiro

| # | Tarea solicitada | Estado real | Evidencia |
|---|------------------|-------------|-----------|
| 1 | Verificar si se modificó `pg_hba.conf` | ✅ HECHO | Logs 13:40–13:43 muestran `trust`; backup creado 13:34:55 |
| 2 | Restaurar la configuración anterior | ✅ HECHO | `pg_hba.conf` actual en `scram-sha-256`; logs 13:52 con `scram` |
| 3 | Comprobar que no quedaron reglas `trust` | ✅ HECHO | Lectura completa de `pg_hba.conf`; 0 reglas `trust` |
| 4 | Verificar el CSV y sus 6 columnas | ✅ HECHO | 16 líneas, 6 columnas, comparación exacta con la vista |
| 5 | Documentar todo en el README | ⚠️ PARCIAL → CORREGIDO en esta auditoría | El README no documentaba la restauración ni el cambio de contraseña; se agregó la sección de auditoría |

**Conclusión:** Kiro **sí restauró** `pg_hba.conf` antes de quedarse sin créditos, pero **no documentó** la restauración ni el cambio de contraseña. La documentación quedó incompleta.

---

## 10. SQLite: disponibilidad y soporte STRICT

| Prueba | Comando | Resultado real | Estado |
|--------|---------|----------------|--------|
| Python | `python --version` | `Python 3.14.8` | ✅ CORRECTA |
| Versión SQLite | `sqlite3.sqlite_version` | `3.50.4` | ✅ CORRECTA |
| Soporte STRICT | `CREATE TABLE t (...) STRICT` en memoria | Creación y `INSERT` exitosos | ✅ CORRECTA |
| CLI `sqlite3` | `sqlite3 --version` | `CommandNotFoundException` | ⚠️ OBSERVACIÓN |
| `PRAGMA foreign_keys` | conexión nueva | `0` (debe activarse por conexión) | ✅ CORRECTA (comportamiento esperado) |

**Conclusión:** se puede trabajar con SQLite vía Python (`sqlite3`), pero **no hay CLI `sqlite3` instalado**. Los comandos de `tasks.md` que usan `sqlite3 archivo.db < script.sql` deberán adaptarse a Python o instalarse el CLI. Esto se resolverá en la próxima etapa con autorización.

---

## 11. Matriz de pruebas de la auditoría

| # | Qué se quería comprobar | Comando ejecutado | Resultado real | Estado |
|---|-------------------------|-------------------|----------------|--------|
| A01 | ¿Existe el clon canónico? | `git -C "%TEMP%\kilo\Base_de_datos" remote -v` | `origin = .../Base_de_datos.git` | ✅ CORRECTA |
| A02 | ¿La rama es `main`? | `git branch --show-current` | `main` | ✅ CORRECTA |
| A03 | ¿Hay cambios locales? | `git status --porcelain=v1` | Solo `?? food_store_unidad6b2/informe_u6.html` | ✅ CORRECTA |
| A04 | ¿Está al día con origin? | `git log --oneline HEAD..origin/main` | 1 commit: `7a238cf` (borra PDF U6) | ⚠️ OBSERVACIÓN |
| A05 | ¿La U8 está dentro del repo? | `git ls-files | Select-String unidad8` | Sin resultados | ❌ INCORRECTA |
| A06 | ¿Existe `foodstore_u8_test`? | `SELECT datname ...` | Sí, 8294 kB | ✅ CORRECTA |
| A07 | ¿Existen las 3 tablas? | `information_schema.tables` | `categorias`, `sucursales`, `productos` | ✅ CORRECTA |
| A08 | ¿Existe la vista? | `information_schema.tables` | `v_snapshot_movil` (VIEW) | ✅ CORRECTA |
| A09 | ¿Hay 15 productos? | `SELECT count(*) FROM productos;` | 15 | ✅ CORRECTA |
| A10 | ¿Los datos son sintéticos? | `SELECT ... FROM productos;` | 15 productos inventados | ✅ CORRECTA |
| A11 | ¿La vista tiene 6 columnas? | `information_schema.columns` | 6 columnas correctas | ✅ CORRECTA |
| A12 | ¿El CSV tiene 6 columnas? | Python `csv.reader` | 6 columnas en cabecera y datos | ✅ CORRECTA |
| A13 | ¿El CSV coincide con la vista? | Comparación Python | Idénticos | ✅ CORRECTA |
| A14 | ¿`foodstore_tp` está intacta? | `count(*)` en productos/clientes/pedidos | 40 / 2000 / 50000 | ✅ CORRECTA |
| A15 | ¿Quedaron reglas `trust`? | Lectura de `pg_hba.conf` | 0 reglas `trust` | ✅ CORRECTA |
| A16 | ¿Se restauró `pg_hba.conf`? | Logs 13:51–13:52 | `scram-sha-256` funcionando | ✅ CORRECTA |
| A17 | ¿Quedó backup residual? | `Get-ChildItem pg_hba*` | `pg_hba.conf.backup` presente | ⚠️ PENDIENTE |
| A18 | ¿Se cambió la contraseña de `postgres`? | Logs 13:50:39 | `ALTER USER ... PASSWORD ...` | 🔴 CRÍTICO |
| A19 | ¿SQLite soporta STRICT? | Python `CREATE TABLE ... STRICT` | OK | ✅ CORRECTA |
| A20 | ¿Existe CLI `sqlite3`? | `sqlite3 --version` | No instalado | ⚠️ OBSERVACIÓN |

---

## 12. Riesgos y recomendaciones (para autorización)

| Prioridad | Riesgo | Recomendación |
|-----------|--------|---------------|
| 🔴 CRÍTICA | Contraseña de `postgres` débil y registrada en logs | Rotarla y documentar el incidente; no guardar el valor en archivos |
| 🔴 ALTA | La U8 está fuera del repositorio canónico y sin Git | Copiar/mover `food_store_unidad8b2` al clon canónico antes de seguir |
| 🔴 ALTA | El clon canónico está en `%TEMP%` | Reubicarlo en una ruta estable antes de commitear |
| 🟠 MEDIA | El clon local está 1 commit detrás de `origin/main` y ese commit borra un PDF de U6 | Decidir estrategia: alinear con `origin/main` (acepta la baja del PDF) o resolver antes de commitear |
| 🟠 MEDIA | `pg_hba.conf.backup` residual en el directorio de datos | Eliminarlo tras autorización |
| 🟡 BAJA | `tasks.md` tenía tareas hechas sin marcar | Corregido en esta auditoría |
| 🟡 BAJA | Nombres `Ensanada`/`Clasica` sin tilde | Cosmético; no afecta pruebas. Corregir solo si se regenera el snapshot |
| 🟡 BAJA | No hay CLI `sqlite3` | Usar Python `sqlite3` o instalar el CLI antes de la Parte 2 |

---

## 13. Qué NO se hizo en esta auditoría

- No se creó `schema_sqlite.sql`, `pruebas_sqlite.sql`, `semaforo.sql` ni `foodstore_movil.db`.
- No se ejecutaron pruebas C1, C7 ni C2–C6.
- No se modificó ninguna base de datos (`foodstore_tp` ni `foodstore_u8_test`).
- No se modificó `pg_hba.conf` ni se reinició el servicio.
- No se eliminó `pg_hba.conf.backup`.
- No se movió ni copió la carpeta de la Unidad 8.
- No se hizo `git pull`, `merge`, `commit` ni `push`.
- Solo se ejecutó `git fetch` (actualiza referencias remotas, no archivos de trabajo).

---

## 14. Conclusión

La Etapa 3-Parte 1 (PostgreSQL sintético + vista + CSV) está **realizada y verificada**. Las tareas de seguridad que habían quedado pendientes con Kiro están **resueltas en los hechos** (`pg_hba.conf` restaurado, sin `trust`), pero **no estaban documentadas**.

Los dos bloqueantes principales antes de continuar son:

1. **Seguridad:** la contraseña del superusuario `postgres` fue cambiada por Kiro a un valor débil y quedó en logs.
2. **Ubicación/versionado:** la carpeta `food_store_unidad8b2` está fuera del repositorio canónico y el clon canónico está en `%TEMP%`.

**Estado:** auditoría terminada. Se espera autorización para resolver los bloqueantes y continuar con `schema_sqlite.sql` y la Parte 2 (SQLite).
