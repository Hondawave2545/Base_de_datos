# Food Store — Unidad 3: índices, vistas y vistas materializadas

Base de Datos II — Tecnicatura Universitaria en Programación.
Motor: PostgreSQL. Herramienta de consulta: DBeaver.
Este trabajo agrega índices y vistas sin modificar las tablas base.

## Contenido
| Archivo | Descripción |
|---|---|
| `indices.sql` | Índices aceptados (Parte A) |
| `views.sql` | Vistas (Parte B) y vista materializada (Parte C) |
| `informe_mediciones.md` | EXPLAIN ANALYZE antes/después, costo de escritura, índices descartados, verificación de vistas, frecuencia de refresco |
| `duia.md` | Bitácora de uso de IA |
| `specs/` | Especificaciones de cada pieza |
| `scripts/` | Scripts de carga de datos y de medición |

## Cómo reproducir las pruebas
Siempre sobre una **copia** de la base, nunca sobre la base original.

1. **Crear la copia.** Desde otra base (por ejemplo `libreria`), ejecutar por separado:
   ```sql
   SELECT pg_terminate_backend(pid) FROM pg_stat_activity
   WHERE datname = 'postgres' AND pid <> pg_backend_pid();
   CREATE DATABASE foodstore_tp TEMPLATE postgres;
   ```
2. **Cargar datos** en `foodstore_tp` (cada archivo completo con `Alt + X` en DBeaver):
   - `scripts/00_base.sql` (una sola vez): categorías, sucursales, empleados, 2.000 clientes y 40 productos.
   - `scripts/01_volumen.sql`: 50.000 pedidos, 150.000 detalles y 50.000 pagos.
3. **Medir ANTES de crear índices:**
   - `scripts/consultas_a_medir.sql` (C1 a C4). Ejecutar cada `EXPLAIN` dos veces y anotar la segunda.
   - `scripts/medir_escritura.sql` (E1 a E3). Cada bloque con `Alt + X`; terminan en `ROLLBACK`. Repetir 3 veces y tomar la mediana.
4. **Crear los índices:** `indices.sql` y luego `ANALYZE pedidos; ANALYZE pagos;`
5. **Medir DESPUÉS:** repetir los dos scripts del paso 3.
6. **Crear vistas y vista materializada:** `views.sql`.
7. **Verificar equivalencia de vistas:** `scripts/verificar_equivalencia.sql` (0 filas en ambos sentidos = idénticas). El patrón se repite para cada vista; las consultas manuales usadas están en `informe_mediciones.md`.
8. **Probar el refresco:** `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;`

## Resultados resumidos
| Consulta | Antes | Después | Mejora |
|---|---|---|---|
| C1 pedidos entregados de un mes | 15,095 ms | 1,809 ms | 8,3x |
| C2 pedidos en camino de un repartidor | 11,806 ms | 0,621 ms | 19x |
| C3 pagos de un pedido | 6,199 ms | 0,106 ms | 58x |
| Facturación por categoría y mes (MV) | 184,143 ms | 0,058 ms | 3.175x |

Índices descartados por redundancia o baja cardinalidad: `detalle_pedido(id_pedido)`, `detalle_pedido(id_producto)` y `pedidos(estado)`. Detalle en `informe_mediciones.md`.

## Historial de commits (uno por pieza)
```
git commit -m "Índice parcial pedidos(fecha_pedido, estado) — evita Seq Scan en reporte mensual"
git commit -m "Índice pedidos(id_empleado_repartidor, estado) — pedidos en camino por repartidor"
git commit -m "Índice pagos(id_pedido) — FK sin índice"
git commit -m "Vistas v_productos_vigentes, v_pedidos_cliente, v_detalle_pedido, v_clientes_publico"
git commit -m "Vista materializada facturación por categoría y mes + índice único"
git commit -m "Informe de mediciones y DUIA"
```
