# TRABAJO PRÁCTICO INTEGRADOR: FOOD STORE
**Asignatura:** Bases de Datos II  
**Motor de Referencia:** PostgreSQL 16+  
**Entregable:** Primera Entrega Parcial 

---

## 1. Diseño, Modelado y Normalización
### 1.1 Modelo ER y Paso al Modelo Relacional
 Parte 1 

Modelo ER (entidades, atributos, claves, cardinalidad, participación)


Entidades y atributos
CLIENTE

id_cliente (PK)
nombre, apellido
email (único)
telefono
direccion_entrega
fecha_registro
activo (para soft delete)
SUCURSAL

id_sucursal (PK)
nombre
direccion
telefono
activo
EMPLEADO

id_empleado (PK)
id_sucursal (FK → SUCURSAL)
nombre, apellido, dni
rol (ENUM: cajero, repartidor, gerente)
fecha_contratacion
activo
CATEGORIA

id_categoria (PK)
nombre
descripcion
PRODUCTO

id_producto (PK)
id_categoria (FK → CATEGORIA)
nombre, descripcion
precio
stock
activo
PEDIDO

id_pedido (PK)
id_cliente (FK → CLIENTE)
id_sucursal (FK → SUCURSAL)
id_empleado_repartidor (FK → EMPLEADO, nullable)
fecha_pedido
estado (ENUM: pendiente, en_preparacion, en_camino, entregado, cancelado)
tipo_entrega (ENUM: delivery, retiro_local)
total
activo
DETALLE_PEDIDO (tabla intermedia — resuelve N:M entre PEDIDO y PRODUCTO)

id_detalle (PK)
id_pedido (FK → PEDIDO)
id_producto (FK → PRODUCTO)
cantidad
precio_unitario
subtotal
PAGO

id_pago (PK)
id_pedido (FK → PEDIDO)
metodo_pago (ENUM: efectivo, tarjeta_credito, tarjeta_debito, mercado_pago)
monto
fecha_pago
estado (ENUM: pendiente, aprobado, rechazado)

aclaracion:

EMPLEADO–PEDIDO es opcional (línea punteada del lado de EMPLEADO): si el pedido es retiro_local, no hay repartidor asignado.
PEDIDO–PAGO es 1:N y no 1:1: así modelás el caso de un pago rechazado seguido de un reintento, sin perder el historial. Si tu cátedra prefiere simplicidad, se puede bajar a 1:1.
El soft delete (activo) lo puse en CLIENTE, SUCURSAL, EMPLEADO y PRODUCTO — en las entidades "catálogo/maestras" que no deberían borrarse físicamente porque tienen historial asociado (pedidos, ventas). PEDIDO y PAGO normalmente no se soft-deletean, se cancelan vía el campo estado.
* **Relaciones 1:N:** Resueltas mediante propagación de clave primaria como clave foránea (FK). Ejemplos: `categoria` $\rightarrow$ `producto`, `cliente` $\rightarrow$ `pedido`.
* **Relaciones N:M:** Resueltas mediante la tabla intermedia `detalle_pedido`. Esta tabla descompone la relación entre `pedido` y `producto` incorporando atributos propios de la transacción: `cantidad`, `precio_unitario` y `subtotal`.

### 1.2 Justificación de Normalización (3FN / BCNF)
El esquema se encuentra normalizado en **Tercera Forma Normal (3FN)** y **BCNF**:

Verificación de 3FN (dependencias transitivas)

Acá es donde hay que prestar atención, tabla por tabla:

clientes: id_cliente → nombre, apellido, email, telefono, direccion_entrega, fecha_registro, activo. Ningún atributo no-clave depende de otro atributo no-clave.  3FN.

empleados: id_empleado → id_sucursal, nombre, apellido, dni, rol, fecha_contratacion, activo. id_sucursal es FK, no genera transitividad porque no derivamos datos de sucursal acá (no guardamos nombre_sucursal en empleados).  3FN.

productos: id_producto → id_categoria, nombre, descripcion, precio, stock, activo. Mismo caso: no guardamos nombre_categoria en productos, evitando la transitividad id_producto → id_categoria → nombre_categoria.  3FN.

pedidos: id_pedido → id_cliente, id_sucursal, id_empleado_repartidor, fecha_pedido, estado, tipo_entrega, total, activo. Punto de atención: total es un atributo derivado (suma de los subtotales de detalle_pedido). Estrictamente, esto viola normalización pura porque total depende transitivamente de datos en otra tabla. Lo dejamos igual por una razón práctica: es común en sistemas transaccionales desnormalizar así por rendimiento, pero hay que justificarlo en el informe y mantenerlo consistente con un trigger que recalcule total cada vez que cambie detalle_pedido.

detalle_pedido: (id_pedido, id_producto) → cantidad, precio_unitario, subtotal. Acá subtotal = cantidad × precio_unitario — también es un atributo derivado, y precio_unitario es una copia histórica de productos.precio (necesaria para que el precio del pedido no cambie si el producto se actualiza después). Ambos son desnormalizaciones intencionales, justificadas por integridad histórica y performance. Se documenta la excepción.

pagos: id_pago → id_pedido, metodo_pago, monto, fecha_pago, estado. Sin transitividad. 3FN.

sucursales y categorias: triviales, todos los atributos dependen directamente de la PK. 3FN.

Verificación de BCNF

BCNF exige que toda dependencia funcional tenga como determinante una superclave. Revisando cada tabla: en ningún caso hay un atributo no-clave que determine a otro atributo no-clave que a su vez sea parte de una clave candidata alternativa (no hay claves candidatas superpuestas, como sí pasaría por ejemplo si dni de empleados determinara cosas de forma independiente al id — pero dni es solo UNIQUE, no genera una segunda clave candidata con atributos dependientes de ella). Todas las tablas están en BCNF. 


---

## 2. Definición de Estructura y Manipulación de Datos (DDL y DML)

### 2.1 Uso de Características Nativas de PostgreSQL 16+

El diseño físico del proyecto aprovecha intencionalmente características específicas de PostgreSQL, evitando un DDL genérico portable a cualquier motor:

Tipos ENUM: se definieron 5 tipos enumerados (rol_empleado_enum, estado_pedido_enum, tipo_entrega_enum, metodo_pago_enum, estado_pago_enum) en lugar de VARCHAR con CHECK IN (...), aportando validación a nivel de tipo de dato y mayor claridad semántica en el esquema.

Columnas IDENTITY: todas las claves primarias usan GENERATED ALWAYS AS IDENTITY en lugar de SERIAL, que es el estándar SQL recomendado desde PostgreSQL 10 y evita el manejo directo de secuencias.
TIMESTAMPTZ: todos los campos de fecha/hora (fecha_registro, fecha_pedido, fecha_pago) usan TIMESTAMPTZ en vez de TIMESTAMP, para evitar ambigüedades de huso horario.

JSONB: la dirección de entrega de cada pedido (pedidos.direccion_entrega) se modela como JSONB, dado que es un dato semi-estructurado propio de esa transacción puntual (puede diferir de la dirección habitual del cliente).

Tablas de transición en triggers (REFERENCING NEW TABLE): se utilizan para recalcular pedidos.total a partir de múltiples filas insertadas en detalle_pedido en una sola sentencia, en vez de disparar el trigger fila por fila.
Procedimientos con CALL: se reservan para operaciones transaccionales compuestas (ej. registrar un pedido completo: validar stock, descontar stock y registrar el pago como una unidad atómica), a diferencia de las funciones (FUNCTION), que se invocan en expresiones SELECT y devuelven un valor simple.

### 2.2 Borrado Lógico (*Soft Delete*)
2.2 DDL completo: tipos de datos, claves y restricciones

El script food_store_ddl.sql implementa el modelo relacional definido en 1.1, aplicando en la práctica las características nativas descriptas en 2.1. Resumen de las decisiones técnicas más relevantes por tabla:

Tipos de datos

NUMERIC(10,2) para todos los valores monetarios (precio, total, monto, subtotal) — nunca FLOAT, porque los errores de redondeo de punto flotante son inaceptables en montos de dinero.
VARCHAR(n) con longitud acotada en campos de texto (nombre, email, dirección) en vez de TEXT sin límite, para forzar un límite razonable a nivel de esquema.
DATE para fecha_contratacion (no necesita hora), TIMESTAMPTZ para todo lo que sí necesita hora + huso horario (registros, pedidos, pagos).

Claves

Todas las PK son INTEGER GENERATED ALWAYS AS IDENTITY — autoincrementales, sin intervención manual.
Todas las FK están declaradas con REFERENCES, garantizando integridad referencial a nivel de motor (no dependemos de que la aplicación valide esto).
id_empleado_repartidor es la única FK nullable del modelo, reflejando la participación opcional vista en el diagrama ER.

Restricciones (CHECK / UNIQUE)

CHECK (precio > 0), CHECK (stock >= 0), CHECK (cantidad > 0), CHECK (monto > 0): evitan valores absurdos a nivel de base, sin depender de validación en la app.
UNIQUE (email) en clientes y UNIQUE (dni) en empleados: evitan duplicados de identidad.
UNIQUE (id_pedido, id_producto) en detalle_pedido: fuerza que un producto no se repita como línea separada dentro de un mismo pedido.
CHECK (tipo_entrega = 'delivery' OR id_empleado_repartidor IS NULL): primera regla de negocio implementada a nivel de esquema — anticipa el punto 7 del checklist.

Índices

Uno por cada columna FK (Postgres no los crea automáticamente, a diferencia de las PK), porque son las columnas más consultadas en los JOIN.
idx_pedidos_estado y idx_pedidos_fecha: anticipan el punto de optimización de consultas — son las columnas más filtradas en reportes ("pedidos pendientes de hoy", "pedidos del mes").
Índices parciales WHERE activo = true en clientes, productos y empleados: solo indexan las filas vigentes, que son las que se consultan en el 99% de los casos — esto conecta directamente con el punto 9 (soft delete y su impacto en índices).


parte 5:
 la consulta imagenes 1 ,2 , 3 y 4



Consulta 1: Total gastado y cantidad de pedidos por cliente

Esta consulta combina clientes y pedidos mediante JOIN para obtener, por cada cliente, cuántos pedidos realizó, cuánto gastó en total y su ticket promedio.

sql
SELECT 
    c.nombre,
    c.apellido,
    COUNT(p.id_pedido) AS cantidad_pedidos,
    SUM(p.total) AS monto_total_gastado,
    AVG(p.total) AS ticket_promedio
FROM clientes c
JOIN pedidos p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY monto_total_gastado DESC;

[imagen 5 evidencia]

Resultado: Agustina Vega es la cliente con mayor gasto acumulado ($20.400 en 2 pedidos), mientras que Julieta Ibáñez solo registra 1 pedido por $4.700. Esto valida que el JOIN respeta la relación 1:N cliente-pedido y que las funciones de agregación calculan correctamente sobre los datos cargados.


GROUP BY + HAVING

Objetivo: ver qué productos se vendieron más de una vez (filtrando grupos, no filas individuales — para eso sirve HAVING y no WHERE).

sql
SELECT 
    pr.nombre AS producto,
    cat.nombre AS categoria,
    SUM(dp.cantidad) AS unidades_vendidas,
    SUM(dp.subtotal) AS ingresos_generados
FROM productos pr
JOIN categorias cat ON cat.id_categoria = pr.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = pr.id_producto
GROUP BY pr.id_producto, pr.nombre, cat.nombre
HAVING SUM(dp.cantidad) > 1
ORDER BY unidades_vendidas DESC;

Qué muestra:

Encadena dos JOIN (productos→categorías, productos→detalle_pedido).
GROUP BY agrupa por producto.
HAVING filtra después de agrupar (solo productos con más de 1 unidad vendida en total) — la diferencia clave con WHERE, que filtraría filas individuales antes de agrupar

(evidencia imagen 6)


Subconsulta

Objetivo: encontrar los clientes cuyo gasto total supera el promedio de gasto de todos los clientes (acá la subconsulta calcula ese promedio general, y la consulta externa lo usa como filtro).

sql
SELECT 
    c.nombre,
    c.apellido,
    SUM(p.total) AS gasto_total
FROM clientes c
JOIN pedidos p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre, c.apellido
HAVING SUM(p.total) > (
    SELECT AVG(total) 
    FROM pedidos
)
ORDER BY gasto_total DESC;

Qué muestra:

La subconsulta (SELECT AVG(total) FROM pedidos) se ejecuta primero y calcula un único valor: el promedio de todos los pedidos (no por cliente).
La consulta externa usa ese valor en el HAVING para filtrar solo los clientes que gastaron más que ese promedio general.
Es distinto de la consulta 1: ahí solo listábamos el gasto por cliente; acá comparamos contra un valor calculado dinámicamente, no un número fijo que vos escribas a mano — si mañana agregás más pedidos, el umbral se recalcula solo.

imagen 7 evidencia:


funciones de ventana

Objetivo: rankear a los clientes por gasto total, sin perder el detalle de cada pedido individual (a diferencia de GROUP BY, que colapsa las filas).

sql
SELECT 
    c.nombre,
    c.apellido,
    p.id_pedido,
    p.fecha_pedido,
    p.total,
    SUM(p.total) OVER (PARTITION BY c.id_cliente) AS gasto_total_cliente,
    RANK() OVER (ORDER BY p.total DESC) AS ranking_por_pedido,
    ROW_NUMBER() OVER (PARTITION BY c.id_cliente ORDER BY p.fecha_pedido) AS nro_pedido_del_cliente
FROM clientes c
JOIN pedidos p ON p.id_cliente = c.id_cliente
ORDER BY c.apellido, p.fecha_pedido;

Qué muestra (la diferencia clave con GROUP BY):

SUM(...) OVER (PARTITION BY c.id_cliente): suma el gasto total del cliente, pero sin colapsar las filas — cada pedido se sigue viendo individualmente, a diferencia de la consulta 1 donde perdíamos el detalle.
RANK() OVER (ORDER BY p.total DESC): le pone un número de ranking a cada pedido según su monto, considerando todos los pedidos de todos los clientes.
ROW_NUMBER() OVER (PARTITION BY c.id_cliente ORDER BY p.fecha_pedido): numera los pedidos de cada cliente en orden cronológico (su 1er pedido, 2do pedido, etc.).

evidencia imagen 8 y 9:

Vista: las 8 filas muestran repartidor = [NULL] exactamente en los pedidos con tipo_entrega = retiro_local (filas 2, 6, 8) — confirma que el LEFT JOIN y la regla de negocio opcional del repartidor funcionan bien.
Procedimiento: el CALL se ejecutó sin errores (agregó un pedido nuevo para el cliente 1: producto #2, 1 unidad).
Función: fn_ticket_promedio_cliente(1) devuelve 8.066,67 — y esto cuadra perfecto con el pedido que acabás de crear: antes el cliente 1 tenía pedidos por 12.000 y 6.000 (promedio 9.000), y ahora con el pedido nuevo que agregaste vía CALL (6.200) el promedio bajó a (12.000+6.000+6.200)/3 = 8.066,67. Esa coincidencia exacta demuestra que el trigger de cálculo de subtotal, el trigger de recálculo de total, y la función de promedio están todos sincronizados correctamente.

evidencias imagen 10,11,12y13
0


