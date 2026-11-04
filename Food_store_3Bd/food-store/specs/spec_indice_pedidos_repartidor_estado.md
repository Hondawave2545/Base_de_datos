# spec: indice_pedidos_repartidor_estado
Objetivo: listar rápido los pedidos "en_camino" de un repartidor.
Consulta: SELECT id_pedido, fecha_pedido, total FROM pedidos
  WHERE id_empleado_repartidor = :id AND estado = 'en_camino';
Frecuencia: alta (cada repartidor consulta su ruta). Columnas: id_empleado_repartidor (FK sin índice), estado.
Aceptación: Seq Scan -> Index/Bitmap Scan.
