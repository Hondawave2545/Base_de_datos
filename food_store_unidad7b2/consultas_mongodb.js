// consultas_mongodb.js - Unidad 7 Food Store (foodstore_u7.pedidos)
// Ejecutar: "C:\Program Files\MongoDB\Server\4.4\bin\mongo.exe" --quiet foodstore_u7 consultas_mongodb.js

print("=== a) Todos los pedidos (id y estado) ===");
printjson(db.pedidos.find({}, { _id: 0, id_pedido: 1, estado: 1 }).sort({ id_pedido: 1 }).toArray());

print("\n=== b) Pedidos filtrados por estado 'entregado' ===");
printjson(db.pedidos.find(
  { estado: "entregado" },
  { _id: 0, id_pedido: 1, estado: 1, fecha_pedido: 1, total: 1 }
).sort({ id_pedido: 1 }).toArray());

print("\n=== c) Pedidos que contienen producto id_producto=8 en detalle ===");
printjson(db.pedidos.find(
  { "detalle.id_producto": 8 },
  { _id: 0, id_pedido: 1, estado: 1, "detalle.$": 1 }
).sort({ id_pedido: 1 }).toArray());

print("\n=== c-alt) Pedidos con producto id_producto=8 (todas las lineas) ===");
printjson(db.pedidos.find(
  { "detalle.id_producto": 8 },
  { _id: 0, id_pedido: 1, estado: 1, total: 1 }
).sort({ id_pedido: 1 }).toArray());

print("\n=== d) Pedidos con total > 20000 (umbral=20000) ===");
printjson(db.pedidos.find(
  { total: { $gt: NumberDecimal("20000") } },
  { _id: 0, id_pedido: 1, estado: 1, total: 1 }
).sort({ id_pedido: 1 }).toArray());

print("\n// Justificacion umbral d): 20000 separa pedidos de ticket alto del subconjunto migrado.");
print("// En los 5 pedidos seleccionados, 4 superan 20000 (1,5,6,18) y 1 queda por debajo (4=10547.69),");
print("// permitiendo verificar el filtro de comparacion numerica sobre NumberDecimal sin excluir todos los casos.");
