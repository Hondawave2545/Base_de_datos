# BITACORA.md — Registro de uso de IA

> **Formato obligatorio según la consigna de Unidad 5.**
> Tres columnas: Prompt enviado a la IA · Respuesta relevante recibida (resumida) · Validación o corrección humana aplicada.
>
> Herramienta utilizada: **Kiro** (asistente de IA integrado en el IDE).
> OpenCode no fue utilizado en este trabajo; no se declara su uso.
>
> Última actualización: 2026-11-11

---

## Tabla de interacciones

| # | Parte | Prompt enviado a Kiro | Respuesta relevante recibida (resumida) | Validación / corrección humana |
|---|---|---|---|---|
| 1 | Setup | Leer la consigna del PDF de Unidad 5, inspeccionar el proyecto y presentar un plan de trabajo detallado antes de modificar nada. | Kiro leyó el PDF completo (7 páginas), inspeccionó la estructura del proyecto, identificó qué elementos existían (tablas, funciones, roles) y cuáles faltaban, y presentó un plan de 10 pasos con estructura de carpetas propuesta. También identificó que `foodstore_u5_test` no existía y que la tabla `usuario` y las funciones `fn_autenticar` / `fn_resetear_password` debían reconstruirse. | El estudiante revisó el plan, aprobó la estructura y definió las reglas de trabajo: base aislada, no tocar unidades anteriores, no inventar resultados, registrar solo el uso real de Kiro. |
| 2 | Setup | Crear la carpeta `unidad5/` con toda la estructura de archivos propuesta, README propio y documentación inicial. No ejecutar SQL ni modificar bases de datos. | Kiro creó 17 archivos: carpetas `sql/`, `docs/kiro_roles_spec/`, `docs/`, `evidencias/`, y los archivos README, BITACORA, procedimiento de clonado, especificaciones de Kiro y esqueletos de cada entregable. | El estudiante verificó que ninguna unidad anterior fue modificada (timestamps intactos) y aprobó la estructura. |
| 3 | A | Revisar `requirements.md` y `design.md` comparándolos con la consigna y proponer correcciones. | Kiro identificó 9 correcciones (C1–C9): duplicado de `pagos`, justificación insuficiente de `admin_datos`, ausencia de permisos sobre funciones, nota sobre sequences, herencia del schema, `ALTER DEFAULT PRIVILEGES` incompleto, orden de ejecución, nombres de sequences y permisos de funciones en el pseudocódigo. | El estudiante aprobó las 9 correcciones y pidió aplicarlas. Se aplicaron sobre ambos archivos. |
| 4 | A | Segunda revisión de las specs corregidas: verificar consistencia, permisos excesivos, orden de ejecución y adaptación al esquema real. | Kiro encontró 3 errores adicionales (E1–E3) y 4 puntos a verificar (V1–V4): `ALTER DEFAULT PRIVILEGES` con INSERT+UPDATE automático, orden de L9 antes de L4, firmas provisionales, DNI en `rol_soporte`, y columna `activo` en `admin_datos`. | El estudiante pidió aplicar E1–E3 y resolver V3 y V4 con criterio de mínimo privilegio. Se aplicaron: DNI excluido con permiso de columna, `activo` incluido en `usuario`, INSERT+UPDATE automático eliminado, L9 reubicado. |
| 5 | A | Redactar el script completo `01_roles.sql` tomando como base las specs corregidas. | Kiro escribió el script completo (230 líneas) con guarda de base, REVOKE de PUBLIC, 5 roles NOLOGIN, GRANT de schema, permisos por pasos D–K, `ALTER DEFAULT PRIVILEGES` (solo J1), 2 roles de login sin contraseña, permiso de columna sobre `usuario` y `empleados`, y 4 consultas de verificación. | El estudiante leyó el script íntegro y solicitó una revisión de seguridad. |
| 6 | A | Revisión de seguridad de `01_roles.sql`: contraseñas literales, firmas provisionales, sequences comentados, `ALTER DEFAULT PRIVILEGES`, REVOKE y orden de creación. | Kiro identificó: contraseñas placeholder literales en `CREATE ROLE`, Paso K antes de L4 (error de orden), J3 otorgaba SELECT automático a `rol_soporte` sobre tablas futuras, advertencia insuficiente sobre REVOKE del schema, firmas no marcadas como provisionales. | El estudiante aprobó las correcciones. Se aplicaron: contraseñas eliminadas del script (se documentó usar `ALTER ROLE` aparte), K movido a después de L4, J3 eliminado con justificación, advertencia ampliada. Resultado: 31/31 checks de consistencia OK. |
| 7 | C | Prompt al enviar el log anonimizado del simulacro: "Analizá este fragmento de log de PostgreSQL de una base de desarrollo. ¿Qué ocurrió? ¿Cuál sería tu hipótesis de contención?" | Kiro analizó el log anonimizado (3 intentos fallidos → login exitoso → lectura completa de `usuario` → intento de GRANT admin_datos fallido) e identificó: secuencia de fuerza bruta de baja intensidad, comportamiento post-autenticación anómalo (lectura masiva de cuentas), intento de escalamiento rechazado. Hipótesis: cuenta comprometida usada para reconocimiento y preparación de escalamiento. | El estudiante contrastó la respuesta de Kiro con la ejecución real: 5/5 aciertos (intentos fallidos, login exitoso, lectura masiva, escalamiento rechazado, hipótesis). No se detectaron alucinaciones ni omisiones. Documentado en `informe_incidente.md` secciones 4 y 5. |
| 8 | D | Dada la consulta sobre `usuario_anon` (por rol y mes de alta), escribí la consulta equivalente sobre la tabla real `usuario`. | Kiro propuso: `SELECT rol, date_trunc('month', fecha_alta)::date AS mes_alta, count(*) FROM public.usuario GROUP BY rol, date_trunc('month', fecha_alta)::date ORDER BY mes_alta, rol;` | La consulta es correcta: usa exactamente la misma expresión de truncado de fecha que se aplicó al crear `usuario_anon`, garantizando equivalencia. No requirió corrección. La diferencia simétrica dio 0 filas — equivalencia confirmada. |

---

## Caso más significativo de error o imprecisión de la IA

**Interacción #:** 4 (segunda revisión de specs) y 6 (revisión de seguridad de `01_roles.sql`)

**Descripción del error más significativo:**

En la interacción 4, Kiro no detectó inicialmente el error de **orden de dependencia del Paso K**: el GRANT sobre columnas de `usuario` para `admin_datos` estaba ubicado antes del `CREATE ROLE admin_datos`. Esta es una violación de dependencia que causa un error de ejecución en PostgreSQL ("role admin_datos does not exist"), pero pasó inadvertida en la primera redacción del pseudocódigo y solo se detectó en la revisión de seguridad (interacción 6).

En la interacción 6 Kiro también detectó que las **contraseñas placeholder estaban literales en el script** (`PASSWORD 'placeholder_app_web_cambiar'`), lo que hubiera significado subir credenciales a un repositorio Git. Este es un problema de seguridad de impacto real si el repositorio se hace público.

**Cómo se lo detectó:**
- El error de orden: mediante un análisis sistemático de dependencias en el pseudocódigo, verificando que cada grantee existiera antes del GRANT correspondiente.
- Las contraseñas: mediante una revisión explícita de criterio "¿qué información sensible está en texto plano en el script?".

**Corrección aplicada:**
- Paso K movido al Paso L-post (después de `CREATE ROLE admin_datos`, paso L4).
- Contraseñas eliminadas completamente del script; reemplazadas por instrucciones en comentarios para usar `ALTER ROLE ... PASSWORD '...'` en sesión separada.

---

## Nota sobre la herramienta

La consigna nombra OpenCode como asistente de IA de terminal. En este trabajo se utilizó **Kiro** (IDE con asistente integrado) para todas las tareas que la consigna asigna a OpenCode: escritura y revisión de SQL, planificación por especificaciones, y participación en la reconstrucción del log de la Parte C. Esta sustitución no altera los objetivos de aprendizaje del TP.

---

## Historial de sesiones de trabajo

| Fecha | Sesión | Actividad | Estado |
|---|---|---|---|
| 2026-11-11 | 1 | Lectura de consigna, inspección del proyecto, plan de trabajo, creación de estructura. | ✅ Completo |
| 2026-11-11 | 2 | Redacción de specs (requirements.md + design.md), revisiones iterativas (R1→R3), escritura y revisión de seguridad de `01_roles.sql`. | ✅ Completo |
| 2026-11-11 | 3 | Completar scripts `00`, `03`, `04`, `05`; redactar informes B, C, D; actualizar BITACORA y README. | ✅ Completo |
| 2026-11-11 | 4 | Crear `foodstore_u5_test`, ejecutar scripts en orden (00, 01, 02, 03, 04, 05), capturar evidencias de Partes A, B, C, D. | ✅ Completo |
| 2026-11-11 | 5 | Completar secciones pendientes de informes con resultados reales, actualizar BITACORA con interacciones #7 y #8. | ✅ Completo |
| 2026-11-11 | 6 | Revisión final, commits, push a GitHub. | ✅ Completo |
