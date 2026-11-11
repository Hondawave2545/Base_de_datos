\timing on
SELECT clock_timestamp() AS inicio_sesion_b;
SELECT current_database() AS base, pg_backend_pid() AS pid_b;
BEGIN;
INSERT INTO public.detalle_pedido
    (id_detalle, id_pedido, id_producto, cantidad, precio_unitario, subtotal)
VALUES (150002, 1, 5, 1, 200.00, 200.00);
SELECT clock_timestamp() AS fin_insert_b;
COMMIT;
SELECT clock_timestamp() AS fin_sesion_b;

