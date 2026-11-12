// migracion_u7.js - Unidad 7: Migracion Food Store (pedidos+detalle) a MongoDB
// Ejecutar con: mongo.exe --quiet foodstore_u7 migracion_u7.js
// Datos obtenidos de foodstore_tp (PostgreSQL) - SOLO LECTURA. Sin PII real.

(function() {
  var dbName = db.getName();
  if (dbName !== "foodstore_u7") {
    throw new Error("Debe ejecutarse contra foodstore_u7. DB actual: " + dbName);
  }

  var existing = db.getCollectionNames();
  var count = existing.indexOf("pedidos") >= 0 ? db.pedidos.count() : 0;
  print("PRECHECK: colecciones=" + tojson(existing) + " pedidos.count=" + count);
  if (count > 0) {
    throw new Error("ABORT: la coleccion pedidos ya tiene datos (" + count + "). No se modifica.");
  }

  var now = new Date();
  var docs = [
    {
      _id: 1,
      id_pedido: 1,
      fecha_pedido: ISODate("2026-03-15T05:29:53.916441Z"),
      estado: "cancelado",
      tipo_entrega: "delivery",
      id_sucursal: 1,
      id_empleado_repartidor: 3,
      total: NumberDecimal("39676.55"),
      activo: true,
      datos_envio: { ciudad: "Mendoza", direccion: "Calle 1" },
      cliente: {
        id_cliente: 684,
        cliente_ref: "CLI_684",
        fecha_registro: ISODate("2024-12-20T01:01:23.254231Z"),
        activo: true
      },
      detalle: [
        { id_detalle: 1, id_producto: 3, producto_nombre: "Producto 3", cantidad: 2, precio_unitario: NumberDecimal("4810.70"), subtotal: NumberDecimal("9621.40") },
        { id_detalle: 2, id_producto: 4, producto_nombre: "Producto 4", cantidad: 3, precio_unitario: NumberDecimal("4366.49"), subtotal: NumberDecimal("13099.47") },
        { id_detalle: 3, id_producto: 5, producto_nombre: "Producto 5", cantidad: 4, precio_unitario: NumberDecimal("4238.92"), subtotal: NumberDecimal("16955.68") }
      ],
      origen: { bd: "foodstore_tp", tabla: "pedidos+detalle_pedido+clientes+productos", migrado_en: now }
    },
    {
      _id: 4,
      id_pedido: 4,
      fecha_pedido: ISODate("2025-06-25T08:59:11.203800Z"),
      estado: "en_camino",
      tipo_entrega: "delivery",
      id_sucursal: 2,
      id_empleado_repartidor: 10,
      total: NumberDecimal("10547.69"),
      activo: true,
      datos_envio: { ciudad: "Mendoza", direccion: "Calle 4" },
      cliente: {
        id_cliente: 186,
        cliente_ref: "CLI_186",
        fecha_registro: ISODate("2026-05-02T01:01:23.254231Z"),
        activo: true
      },
      detalle: [
        { id_detalle: 10, id_producto: 6, producto_nombre: "Producto 6", cantidad: 1, precio_unitario: NumberDecimal("4209.08"), subtotal: NumberDecimal("4209.08") },
        { id_detalle: 11, id_producto: 7, producto_nombre: "Producto 7", cantidad: 1, precio_unitario: NumberDecimal("2816.98"), subtotal: NumberDecimal("2816.98") },
        { id_detalle: 12, id_producto: 8, producto_nombre: "Producto 8", cantidad: 1, precio_unitario: NumberDecimal("3521.63"), subtotal: NumberDecimal("3521.63") }
      ],
      origen: { bd: "foodstore_tp", tabla: "pedidos+detalle_pedido+clientes+productos", migrado_en: now }
    },
    {
      _id: 5,
      id_pedido: 5,
      fecha_pedido: ISODate("2025-03-30T13:24:57.080331Z"),
      estado: "en_preparacion",
      tipo_entrega: "delivery",
      id_sucursal: 2,
      id_empleado_repartidor: 9,
      total: NumberDecimal("24590.33"),
      activo: true,
      datos_envio: { ciudad: "Mendoza", direccion: "Calle 5" },
      cliente: {
        id_cliente: 367,
        cliente_ref: "CLI_367",
        fecha_registro: ISODate("2025-11-02T01:01:23.254231Z"),
        activo: true
      },
      detalle: [
        { id_detalle: 13, id_producto: 7, producto_nombre: "Producto 7", cantidad: 2, precio_unitario: NumberDecimal("2816.98"), subtotal: NumberDecimal("5633.96") },
        { id_detalle: 14, id_producto: 8, producto_nombre: "Producto 8", cantidad: 3, precio_unitario: NumberDecimal("3521.63"), subtotal: NumberDecimal("10564.89") },
        { id_detalle: 15, id_producto: 9, producto_nombre: "Producto 9", cantidad: 4, precio_unitario: NumberDecimal("2097.87"), subtotal: NumberDecimal("8391.48") }
      ],
      origen: { bd: "foodstore_tp", tabla: "pedidos+detalle_pedido+clientes+productos", migrado_en: now }
    },
    {
      _id: 6,
      id_pedido: 6,
      fecha_pedido: ISODate("2026-07-24T03:20:40.753825Z"),
      estado: "entregado",
      tipo_entrega: "delivery",
      id_sucursal: 1,
      id_empleado_repartidor: 5,
      total: NumberDecimal("21834.90"),
      activo: true,
      datos_envio: { ciudad: "Mendoza", direccion: "Calle 6" },
      cliente: {
        id_cliente: 933,
        cliente_ref: "CLI_933",
        fecha_registro: ISODate("2026-03-16T01:01:23.254231Z"),
        activo: true
      },
      detalle: [
        { id_detalle: 16, id_producto: 8, producto_nombre: "Producto 8", cantidad: 3, precio_unitario: NumberDecimal("3521.63"), subtotal: NumberDecimal("10564.89") },
        { id_detalle: 17, id_producto: 9, producto_nombre: "Producto 9", cantidad: 1, precio_unitario: NumberDecimal("2097.87"), subtotal: NumberDecimal("2097.87") },
        { id_detalle: 18, id_producto: 10, producto_nombre: "Producto 10", cantidad: 3, precio_unitario: NumberDecimal("3057.38"), subtotal: NumberDecimal("9172.14") }
      ],
      origen: { bd: "foodstore_tp", tabla: "pedidos+detalle_pedido+clientes+productos", migrado_en: now }
    },
    {
      _id: 18,
      id_pedido: 18,
      fecha_pedido: ISODate("2026-06-20T23:19:27.561011Z"),
      estado: "pendiente",
      tipo_entrega: "delivery",
      id_sucursal: 1,
      id_empleado_repartidor: 4,
      total: NumberDecimal("23949.34"),
      activo: true,
      datos_envio: { ciudad: "Mendoza", direccion: "Calle 18" },
      cliente: {
        id_cliente: 173,
        cliente_ref: "CLI_173",
        fecha_registro: ISODate("2026-05-15T01:01:23.254231Z"),
        activo: true
      },
      detalle: [
        { id_detalle: 52, id_producto: 20, producto_nombre: "Producto 20", cantidad: 3, precio_unitario: NumberDecimal("2861.39"), subtotal: NumberDecimal("8584.17") },
        { id_detalle: 53, id_producto: 21, producto_nombre: "Producto 21", cantidad: 1, precio_unitario: NumberDecimal("2931.19"), subtotal: NumberDecimal("2931.19") },
        { id_detalle: 54, id_producto: 22, producto_nombre: "Producto 22", cantidad: 3, precio_unitario: NumberDecimal("4144.66"), subtotal: NumberDecimal("12433.98") }
      ],
      origen: { bd: "foodstore_tp", tabla: "pedidos+detalle_pedido+clientes+productos", migrado_en: now }
    }
  ];

  var res = db.pedidos.insertMany(docs);
  print("INSERT_OK insertedCount=" + res.insertedIds.length);
  printjson(res.insertedIds);
})();
