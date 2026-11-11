# Índice de evidencias — Unidad 4

Este directorio reúne las transcripciones y resultados reales de las pruebas de la Unidad 4. Todas las ejecuciones se hicieron sobre la base aislada `foodstore_u4_test_20261110` (PostgreSQL 18.6) el **2026-11-11**. No se accedió a `foodstore_tp`.

**Organización:** los archivos se conservaron con sus nombres originales. No se eliminó ni renombró ninguna evidencia. Las transcripciones están numeradas en el orden en que se ejecutaron las pruebas.

## Secuencia de las pruebas

| Orden | Archivo | Tipo | Contenido |
|---|---|---|---|
| 00 | `00_consigna_texto.txt` | Texto | Texto extraído de `unidad4.pdf` para consultar la consigna |
| 01 | `01_inspeccion_previa.txt` | Salida de `psql` | Estructura de las tablas, columnas, `activo`, conteos, triggers, constraints y auditoría previa |
| 01 | `inspect_pre.sql` | SQL auxiliar | Consulta que generó `01_inspeccion_previa.txt` |
| 02 | `02_drop_schema.txt` | Salida de `psql` | Reinstalación limpia: `current_database()`, `DROP SCHEMA mayorista_u4 CASCADE` y control de los 150.000 detalles |
| 03 | `03_parte1_desde_archivo.txt` | Salida de `psql` | Ejecución completa de `tp_fnbc_control_lote.sql` desde disco |
| 04 | `04_parte2_desde_archivo.txt` | Salida de `psql` | Ejecución completa de `tp_desnormalizacion_top_categorias.sql` desde disco |
| 05 | `05_medicion_fecha_con_datos.sql` | SQL auxiliar | Medición de lectura con la fecha literal `2026-11-10` |
| 05 | `05_medicion_fecha_con_datos.txt` | Salida de `psql` | Planes `EXPLAIN ANALYZE`, buffers y top 5 de la fecha con ventas |
| 06 | `concurrencia_A.sql` | SQL auxiliar | Sesión A: inserta un detalle y duerme 6 s con el advisory lock tomado |
| 06 | `concurrencia_B.sql` | SQL auxiliar | Sesión B: inserta otro detalle y queda bloqueada por el lock |
| 06 | `concurrencia_auditoria.sql` | SQL auxiliar | Auditoría posterior a las dos escrituras concurrentes |
| 06 | `06_concurrencia_A_out.txt` | Salida de `psql` | Tiempos y PID de la sesión A |
| 06 | `06_concurrencia_A_err.txt` | Error estándar | Vacío (0 bytes): la sesión A no produjo errores |
| 06 | `06_concurrencia_B_out.txt` | Salida de `psql` | Tiempos y PID de la sesión B |
| 06 | `06_concurrencia_B_err.txt` | Error estándar | Vacío (0 bytes): la sesión B no produjo errores |
| 06 | `06_concurrencia_monitor.txt` | Monitor | Muestreo de `pg_stat_activity` cada 600 ms: B en `Lock/advisory` y A en `PgSleep` |
| 06 | `06_concurrencia_auditoria.txt` | Salida de `psql` | Filas de prueba presentes y diferencia fuente/resumen igual a 0 |
| 07 | `07_limpieza_concurrencia.sql` | SQL auxiliar | Borrado de las dos filas de prueba |
| 07 | `07_limpieza_concurrencia.txt` | Salida de `psql` | `DELETE 2`, conteos restaurados y auditoría final |
| 08 | `08_estado_final.sql` | SQL auxiliar | Consulta de cierre: base, conteos, diferencias, top 5 y constraints |
| 08 | `08_estado_final.txt` | Salida de `psql` | Estado final verificado de la base de test |
| — | `INDICE.md` | Índice | Este archivo |

## Resultados clave que respaldan estas evidencias

| Prueba | Resultado |
|---|---|
| Parte 1 | 0 diferencias original/vista; 3/3 filas; FK inválida y FD contradictoria rechazadas |
| Parte 2 | 9 auditorías DML con 0 diferencias; `TRUNCATE` + `ROLLBACK` restauró 150.000 detalles |
| Lectura (2026-11-10) | 188,606 ms normalizada vs 0,174 ms con resumen; 1.904 vs 3 buffers |
| Escritura | 3,837 ms sin trigger vs 284,971 ms con trigger (284,531 ms en el trigger); ambas con `ROLLBACK` |
| Concurrencia | Sesiones con PID 20536 y 13576; B esperó en `Lock/advisory` ~5 s; ambas commitearon; auditoría 0 diferencias |
| Estado final | 50.000 pedidos, 150.000 detalles, 40 productos, 5 categorías, 5 filas de resumen, 6 triggers, 0 diferencias |

## Cómo leer las evidencias

1. Empezar por `01_inspeccion_previa.txt` para conocer la estructura y el estado inicial.
2. Seguir con `03_parte1_desde_archivo.txt` y `04_parte2_desde_archivo.txt`, que son las ejecuciones completas de los dos scripts entregables.
3. Revisar `05_medicion_fecha_con_datos.txt` para los planes de lectura antes/después.
4. Revisar `06_concurrencia_monitor.txt` y los archivos `06_concurrencia_*` para la prueba de concurrencia.
5. Cerrar con `07_limpieza_concurrencia.txt` y `08_estado_final.txt`, que muestran que el fixture quedó restaurado y sin diferencias.

Los archivos `06_concurrencia_A_err.txt` y `06_concurrencia_B_err.txt` están vacíos porque `psql` no escribió errores en esas sesiones; su tamaño 0 es el resultado esperado y no una evidencia faltante.

No se generaron capturas de pantalla. Las transcripciones conservan los tiempos, los PID, los planes y las salidas completas de `psql`.
