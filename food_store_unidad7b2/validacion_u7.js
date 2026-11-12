// validacion_u7.js - Validacion migracion Unidad 7
// Ejecutar: mongo.exe --quiet foodstore_u7 validacion_u7.js

(function() {
  print("=== VALIDACION UNIDAD 7 ===");
  var count = db.pedidos.count();
  print("COUNT=" + count);

  var ids = db.pedidos.find({}, {_id:1}).sort({_id:1}).toArray().map(function(d){ return d._id; });
  print("IDS=" + tojson(ids));

  var expected = [1,4,5,6,18];
  var idsMatch = (ids.length === expected.length) && ids.every(function(v,i){ return v === expected[i]; });
  print("IDS_MATCH=" + idsMatch);

  var lineas = db.pedidos.aggregate([
    {$project: {id_pedido:1, n_lineas: {$size: "$detalle"}}},
    {$sort: {id_pedido:1}}
  ]).toArray();
  print("LINEAS_POR_PEDIDO=" + tojson(lineas));
  var all3 = lineas.every(function(d){ return d.n_lineas === 3; });
  print("TODOS_3_LINEAS=" + all3);

  var checks = db.pedidos.aggregate([
    {$project: {
      id_pedido:1, estado:1, fecha_pedido:1, total:1,
      detalle:1,
      suma_subtotales: {$sum: "$detalle.subtotal"},
      lineas_ok: {$allElementsTrue: {$map: {
        input: "$detalle",
        as: "d",
        in: {$eq: ["$$d.subtotal", {$multiply: ["$$d.cantidad", "$$d.precio_unitario"]}]}
      }}}
    }},
    {$project: {
      id_pedido:1, estado:1, fecha_pedido:1,
      total_str: {$toString:"$total"},
      suma_str: {$toString:"$suma_subtotales"},
      total_match: {$eq:["$total","$suma_subtotales"]},
      lineas_ok:1,
      n_lineas: {$size:"$detalle"}
    }},
    {$sort:{id_pedido:1}}
  ]).toArray();
  print("CHECKS=" + tojson(checks));

  var dups = db.pedidos.aggregate([
    {$group:{_id:"$id_pedido", c:{$sum:1}}},
    {$match:{c:{$gt:1}}}
  ]).toArray();
  print("DUPLICADOS=" + tojson(dups));

  var resumen = {
    count_ok: count === 5,
    ids_ok: idsMatch,
    lineas_ok: all3,
    total_match_all: checks.every(function(d){return d.total_match;}),
    lineas_calc_all: checks.every(function(d){return d.lineas_ok;}),
    sin_duplicados: dups.length === 0
  };
  print("RESUMEN=" + tojson(resumen));
})();
