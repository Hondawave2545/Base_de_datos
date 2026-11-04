-- Carga de volumen en foodstore_tp (NUNCA en postgres). Requiere que clientes, productos (>=4),
-- sucursales y empleados ya tengan datos. Ejecutar como script completo (Alt+X en DBeaver).
-- Si alguna restricción CHECK/NOT NULL falla, copiá el mensaje de error y lo ajustamos.

-- 1) 50.000 pedidos
INSERT INTO pedidos (id_cliente, id_sucursal, id_empleado_repartidor, fecha_pedido,
                     estado, tipo_entrega, total, datos_envio, activo)
SELECT cli[1 + floor(x.r4 * array_length(cli,1))::int],
       suc[1 + floor(x.r5 * array_length(suc,1))::int],
       CASE WHEN x.r2 < 0.33 THEN NULL
            ELSE rep[1 + floor(x.r3 * array_length(rep,1))::int] END,
       now() - (x.r6 * 700 || ' days')::interval,
       (CASE WHEN x.r1 < 0.60 THEN 'entregado'
             WHEN x.r1 < 0.70 THEN 'cancelado'
             WHEN x.r1 < 0.80 THEN 'pendiente'
             WHEN x.r1 < 0.90 THEN 'en_preparacion'
             ELSE 'en_camino' END)::estado_pedido_enum,
       (CASE WHEN x.r2 < 0.33 THEN 'retiro_local' ELSE 'delivery' END)::tipo_entrega_enum,
       0,
       CASE WHEN x.r2 < 0.33 THEN '{}'::jsonb
            ELSE jsonb_build_object('direccion', 'Calle ' || x.g, 'ciudad', 'Mendoza') END,
       (x.r7 > 0.05)                                   -- ~5% inactivos
FROM (SELECT g, random() r1, random() r2, random() r3, random() r4,
             random() r5, random() r6, random() r7
      FROM generate_series(1, 50000) g) x,
     (SELECT array_agg(id_cliente) cli FROM clientes) c,
     (SELECT array_agg(id_sucursal) suc FROM sucursales) s,
     (SELECT COALESCE(array_agg(id_empleado) FILTER (WHERE rol = 'repartidor'),
                      array_agg(id_empleado)) rep FROM empleados) e;

-- 2) 3 renglones de detalle por pedido (productos distintos: respeta uq_pedido_producto)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario, subtotal)
SELECT p.id_pedido, pr.id_producto, q.cant, pr.precio, q.cant * pr.precio
FROM pedidos p
CROSS JOIN generate_series(1, 3) k
CROSS JOIN LATERAL (SELECT 1 + ((p.id_pedido * k) % 4) AS cant) q
JOIN (SELECT id_producto, precio,
             row_number() OVER (ORDER BY id_producto) rn,
             count(*) OVER () n
      FROM productos) pr
  ON pr.rn = 1 + ((p.id_pedido + k) % pr.n);

-- 3) Total del pedido = suma de sus subtotales
UPDATE pedidos p SET total = s.t
FROM (SELECT id_pedido, SUM(subtotal) t FROM detalle_pedido GROUP BY id_pedido) s
WHERE s.id_pedido = p.id_pedido;

-- 4) Un pago por pedido
INSERT INTO pagos (id_pedido, metodo_pago, monto, fecha_pago, estado)
SELECT id_pedido,
       (ARRAY['efectivo','tarjeta_credito','tarjeta_debito','mercado_pago'])[1 + (id_pedido % 4)]::metodo_pago_enum,
       total, fecha_pedido,
       (CASE estado WHEN 'cancelado' THEN 'rechazado'
                    WHEN 'pendiente' THEN 'pendiente'
                    ELSE 'aprobado' END)::estado_pago_enum
FROM pedidos;

ANALYZE;

-- Control:
SELECT (SELECT count(*) FROM pedidos) pedidos, (SELECT count(*) FROM detalle_pedido) detalles,
       (SELECT count(*) FROM pagos) pagos;
