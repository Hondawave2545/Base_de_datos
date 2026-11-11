\timing on
SELECT clock_timestamp() AS inicio_sesion_a;
SELECT current_database() AS base, pg_backend_pid() AS pid_a;
BEGIN;
INSERT INTO public.detalle_pedido
    (id_detalle, id_pedido, id_producto, cantidad, precio_unitario, subtotal)
VALUES (150001, 1, 4, 1, 100.00, 100.00);
SELECT clock_timestamp() AS fin_insert_a;
SELECT pg_sleep(6);
COMMIT;
SELECT clock_timestamp() AS fin_sesion_a;

