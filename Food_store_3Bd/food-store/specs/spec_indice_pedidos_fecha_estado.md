# spec: indice_pedidos_fecha_estado
Objetivo: acelerar el reporte "pedidos entregados de un mes".
Consulta: SELECT id_pedido, fecha_pedido, total FROM pedidos
  WHERE fecha_pedido >= :desde AND fecha_pedido < :hasta AND estado = 'entregado' AND activo = TRUE;
Frecuencia: diaria. Columnas: fecha_pedido (alta selectividad), estado (baja), activo (condición parcial).
Aceptación: Seq Scan -> Index/Bitmap Scan y mejora de tiempo medible.
