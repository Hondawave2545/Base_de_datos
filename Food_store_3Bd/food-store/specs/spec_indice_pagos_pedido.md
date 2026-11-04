# spec: indice_pagos_pedido
Objetivo: obtener los pagos de un pedido.
Consulta: SELECT * FROM pagos WHERE id_pedido = :id;
Frecuencia: alta. Columna: id_pedido (FK sin índice).
Aceptación: Seq Scan -> Index Scan.
