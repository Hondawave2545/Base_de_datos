# Índice de evidencias — Unidad 5

Todas las ejecuciones se hacen sobre `foodstore_u5_test` (PostgreSQL 18.6).
No se accede a `foodstore_tp` ni a `foodstore_u4_test_20261110`.

---

## Estado de las evidencias

| Archivo | Parte | Contenido | Estado |
|---|---|---|---|
| `00_crear_usuario.txt` | Setup | Salida de psql: creación de tabla `usuario`, funciones y datos de prueba | ✅ Completado |
| `01_roles_permisos.txt` | A | Salida de psql: ejecución de `01_roles.sql` + consultas de verificación | ✅ Completado |
| `02_auditoria_test.txt` | B | Salida de psql: secuencia de prueba de auditoría + conteos finales | ✅ Completado |
| `03_simulacro.txt` | C | Salida de psql: simulacro completo + verificación post-simulacro | ✅ Completado |
| `04_usuario_anon.txt` | D | Salida de psql: creación de `usuario_anon` + resultados de equivalencia | ✅ Completado |
| `capturas/` | — | Capturas de DBeaver si la cátedra las exige | ⏳ Opcional |

Los archivos `.txt` son transcripciones completas de sesiones `psql` generadas con:
```powershell
psql ... -f "unidad5\sql\XX_archivo.sql" 2>&1 | Tee-Object "unidad5\evidencias\XX_nombre.txt"
```

---

## Resultados confirmados (ejecución real 2026-11-11)

| Prueba | Resultado |
|---|---|
| Guarda de base en cada script | ✅ PASS — RAISE EXCEPTION si la base no es `foodstore_u5_test` |
| Tabla `usuario` creada | ✅ PASS — 4 columnas + funciones `fn_autenticar` y `fn_resetear_password` |
| Roles creados | ✅ PASS — 5 NOLOGIN + 2 LOGIN; membresías según spec |
| `rol_soporte` sobre `empleados` | ✅ PASS — SELECT sobre columnas específicas; `dni` NO aparece en `role_column_grants` |
| `admin_datos` sobre `usuario` | ✅ PASS — SELECT sobre `id_usuario, email, rol, fecha_alta, activo`; `password_hash` NO |
| `fn_autenticar` EXECUTE | ✅ PASS — Solo `rol_app_lectura`; `PUBLIC` NO aparece |
| `fn_resetear_password` EXECUTE | ✅ PASS — Solo `admin_datos`; `PUBLIC` NO aparece |
| Secuencia de auditoría | ✅ PASS — Log contiene marcas `U5-AUDITORIA-TEST: inicio` y `fin` |
| Simulacro Fase 4 | ✅ PASS — NOTICE: "OK: escalamiento rechazado correctamente (insufficient_privilege)" |
| Diferencia simétrica `usuario_anon` | ✅ PASS — 0 filas |

---

## Notas

- Los archivos de evidencia de esta carpeta NO se rellenan manualmente.
- El contenido real proviene exclusivamente de las salidas de `psql`.
- Última actualización del índice: 2026-11-11 (ejecución completa)
