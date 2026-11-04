# Food Store — Unidad 3 (Índices, vistas y vistas materializadas)
Motor: PostgreSQL. Base de pruebas: `foodstore_tp` (copia de `postgres`).

## Reproducir
0. Crear copia: `CREATE DATABASE foodstore_tp TEMPLATE postgres;`
1. Cargar datos base: `scripts/00_base.sql` (una sola vez) y luego `scripts/01_volumen.sql`
2. Medir ANTES: `scripts/consultas_a_medir.sql` (C1–C4) y `scripts/medir_escritura.sql`
3. Crear índices: `indices.sql`; medir DESPUÉS (repetir ambos scripts)
4. `views.sql`
5. `scripts/verificar_equivalencia.sql`

## Commits (uno por pieza)
git commit -m "Índice parcial pedidos(fecha_pedido, estado) — evita Seq Scan en reporte mensual"
git commit -m "Índice pedidos(id_empleado_repartidor, estado) — pedidos en camino por repartidor"
git commit -m "Índice pagos(id_pedido) — FK sin índice"
git commit -m "Vistas B1–B4 (clientes/empleados sin datos sensibles)"
git commit -m "Vista materializada facturación por categoría y mes + índice único"
