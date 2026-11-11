# Unidad 4 — FNBC y desnormalización controlada

Entrega individual — Comisión 3. Integrante: Aquino.

Esta carpeta reúne exclusivamente los archivos de la Unidad 4 del trabajo de Food Store: los dos scripts SQL, el informe y las transcripciones de las pruebas ejecutadas.

## Contenido

| Archivo o carpeta | Contenido |
|---|---|
| `tp_fnbc_control_lote.sql` | Ejercicio 1: análisis de dependencias funcionales, claves candidatas, descomposición en FNBC y vista de compatibilidad. |
| `tp_desnormalizacion_top_categorias.sql` | Ejercicio 2: consulta normalizada, resumen diario por categoría mantenido por triggers, comparación de rendimiento y auditoría de sincronización. |
| `informe_unidad4.md` | Informe con el análisis, los resultados medidos, la explicación del filtro `eliminado = FALSE` y las limitaciones. |
| `evidencias/` | Transcripciones reales de `psql`: inspección previa, ejecución de ambos scripts, mediciones, prueba de concurrencia y limpieza. |
| `evidencias/INDICE.md` | Orden y descripción de cada archivo de evidencia. |
| `evidencias/capturas/` | Carpeta reservada para incorporar capturas de pantalla más adelante. |
| `README.md` | Este archivo. |

## Orden de lectura sugerido

1. `informe_unidad4.md`, para entender el problema, las decisiones y los resultados.
2. `tp_fnbc_control_lote.sql` y `tp_desnormalizacion_top_categorias.sql`, para revisar la implementación.
3. `evidencias/INDICE.md`, para ubicar cada transcripción y seguir el orden de las pruebas.

## Base de pruebas

Las pruebas se ejecutaron en la base aislada `foodstore_u4_test_20261110` (PostgreSQL 18.6), con un fixture sintético de 50.000 pedidos, 150.000 detalles, 40 productos y 5 categorías. No se usaron datos de la base real ni se ejecutaron cambios sobre `foodstore_tp`.

## Nota sobre las capturas

La carpeta `evidencias/capturas/` se conserva para agregar imágenes posteriormente. Al momento de esta publicación no se encontraron capturas recientes verificables, por lo que la carpeta se mantiene en Git mediante el archivo `.gitkeep`.
