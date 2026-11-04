# spec: mv_facturacion_categoria_mes
Reporte: facturación por categoría y mes (pedidos entregados y activos).
Requisitos: WITH DATA + índice único (id_categoria, mes) para REFRESH CONCURRENTLY.
Aceptación: consultar la MV es notablemente más rápido que la consulta original.
