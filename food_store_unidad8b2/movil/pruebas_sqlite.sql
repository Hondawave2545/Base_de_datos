-- ============================================================================
-- Food Store - Unidad 8 - Pruebas SQLite (Consigna 1.c)
-- Base: foodstore_movil.db
-- Requisitos cubiertos: REQ-02 (borradores atómicos), REQ-01 (C1), REQ-04 (C7)
-- Ejecutar con: PRAGMA foreign_keys = ON;
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- TEST 1: Borrador completo guardado con BEGIN...COMMIT
-- Cabecera + items + cola_sync en una sola transacción.
-- ----------------------------------------------------------------------------
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('11111111-1111-1111-1111-111111111101', 'vendedor_01', 'EFECTIVO', '2026-11-12T10:00:00');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-1111-1111-111111111101', 1, 2, 1250000);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '11111111-1111-1111-1111-111111111101', 'PENDIENTE', 'Borrador listo para sincronizar');
COMMIT;

-- Verificación TEST 1
SELECT 'TEST1_borrador_commit' AS test, count(*) AS filas FROM pedido_borrador WHERE id_local = '11111111-1111-1111-1111-111111111101';
SELECT 'TEST1_item_commit' AS test, count(*) AS filas FROM item_borrador WHERE id_local = '11111111-1111-1111-1111-111111111101';
SELECT 'TEST1_cola_sync_commit' AS test, count(*) AS filas FROM cola_sync WHERE solicitud_uuid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

-- ----------------------------------------------------------------------------
-- TEST 2: Operación con ROLLBACK (cantidad 0 -> CHECK falla)
-- No debe dejar filas parciales.
-- ----------------------------------------------------------------------------
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('22222222-2222-2222-2222-222222222202', 'vendedor_01', 'TARJETA', '2026-11-12T10:05:00');
-- Esta inserción debe fallar: cantidad = 0 viola CHECK (cantidad > 0)
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('22222222-2222-2222-2222-222222222202', 1, 0, 1250000);
ROLLBACK;

-- Verificación TEST 2: no debe haber filas del borrador 2222... (ROLLBACK efectivo)
SELECT 'TEST2_pedido_rollback' AS test, count(*) AS filas FROM pedido_borrador WHERE id_local = '22222222-2222-2222-2222-222222222202';
SELECT 'TEST2_item_rollback' AS test, count(*) AS filas FROM item_borrador WHERE id_local = '22222222-2222-2222-2222-222222222202';

-- ----------------------------------------------------------------------------
-- TEST 3: ROLLBACK por producto inexistente (FK falla)
-- ----------------------------------------------------------------------------
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('33333333-3333-3333-3333-333333333303', 'vendedor_01', 'TRANSFERENCIA', '2026-11-12T10:10:00');
-- Esta inserción debe fallar: producto_id = 999 no existe en producto_cache (FK)
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('33333333-3333-3333-3333-333333333303', 999, 1, 100000);
ROLLBACK;

-- Verificación TEST 3: no debe haber filas del borrador 3333... (ROLLBACK efectivo)
SELECT 'TEST3_pedido_rollback' AS test, count(*) AS filas FROM pedido_borrador WHERE id_local = '33333333-3333-3333-3333-333333333303';
SELECT 'TEST3_item_rollback' AS test, count(*) AS filas FROM item_borrador WHERE id_local = '33333333-3333-3333-3333-333333333303';

-- ----------------------------------------------------------------------------
-- CASO C1: Consulta catálogo disponible sin servidor
-- producto_cache tiene los datos; no requiere conexión a PostgreSQL.
-- ----------------------------------------------------------------------------
SELECT 'C1_catalogo_disponible' AS caso, count(*) AS filas
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0;

-- ----------------------------------------------------------------------------
-- CASO C7: Cantidad 0 y producto inexistente dan error (sin filas parciales)
-- ----------------------------------------------------------------------------
-- C7-a: cantidad 0 viola CHECK (cantidad > 0)
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('77777777-7777-7777-7777-77777777777a', 'vendedor_01', 'EFECTIVO', '2026-11-12T11:00:00');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('77777777-7777-7777-7777-77777777777a', 1, 0, 1250000);
ROLLBACK;
SELECT 'C7a_cantidad_cero' AS caso, count(*) AS filas FROM pedido_borrador WHERE id_local = '77777777-7777-7777-7777-77777777777a';

-- C7-b: producto inexistente viola FK (producto_cache)
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('77777777-7777-7777-7777-77777777777b', 'vendedor_01', 'EFECTIVO', '2026-11-12T11:01:00');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('77777777-7777-7777-7777-77777777777b', 999, 1, 100000);
ROLLBACK;
SELECT 'C7b_producto_inexistente' AS caso, count(*) AS filas FROM pedido_borrador WHERE id_local = '77777777-7777-7777-7777-77777777777b';

-- ============================================================================
-- Fin de pruebas
-- ============================================================================
