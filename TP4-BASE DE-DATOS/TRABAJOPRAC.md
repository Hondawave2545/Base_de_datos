# TRABAJO PRÁCTICO - SEMANA 4: REPORTES ANALÍTICOS Y OPTIMIZACIÓN DE JOINS
**Materia:** Base de Datos II  
**Proyecto:** Food Store  
**Motor:** PostgreSQL / DBeaver  
**Alumno/a:** Yoselie Aquino

---

## Parte 1 — Laboratorio: consultas analíticas lentas

Se analizaron consultas complejas con múltiples combinaciones (`JOIN`), funciones de agregación y funciones de ventana sobre el esquema poblado masivamente con **200.000 registros** de la base `Food Store`.

---

### 1.1 Código SQL de las Consultas Medidas

```sql
-- Consulta 1: Ventas por Categoría (JOIN triple + Agregación)

EXPLAIN ANALYZE 
SELECT c.nombre AS categoria, SUM(dp.cantidad * dp.precio_unitario) AS total_ventas
FROM detalle_pedido dp
JOIN producto p ON dp.id_producto = p.id_producto
JOIN categoria c ON p.id_categoria = c.id_categoria
GROUP BY c.nombre
ORDER BY total_ventas DESC;

(evidencia):
Group Key: c.nombre
->  Hash Join  (cost=1713.22..4981.56 rows=117647 width=127) (actual time=22.362..102.306 rows=100000.00 loops=2)
      Hash Cond: (p.id_categoria = c.id_categoria)
      ->  Hash Join  (cost=1694.00..4650.32 rows=117647 width=17) (actual time=22.047..79.119 rows=100000.00 loops=2)
            Hash Cond: (dp.id_producto = p.id_producto)
            ->  Parallel Seq Scan on detalle_pedido dp ...
            ->  Seq Scan on producto p ...
      ->  Seq Scan on categoria c ...
Execution Time: 188.132 ms



-- Consulta 2: Ranking de Clientes por Total Gastado (JOIN + Window Function DENSE_RANK)
EXPLAIN ANALYZE 
SELECT cl.id_cliente, cl.nombre,
       SUM(dp.cantidad * dp.precio_unitario) AS total_gastado,
       DENSE_RANK() OVER (ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC) AS ranking
FROM cliente cl
JOIN pedido pe ON pe.id_cliente = cl.id_cliente
JOIN detalle_pedido dp ON dp.id_pedido = pe.id_pedido
GROUP BY cl.id_cliente, cl.nombre
ORDER BY total_gastado DESC;

(evidencia):
WindowAgg  (cost=15870.51..16220.49 rows=20000 width=61) (actual time=353.362..379.215 rows=20000.00 loops=1)
  ->  Sort (sum(dp.cantidad * dp.precio_unitario)) DESC
        ->  Finalize HashAggregate (Group Key: cl.id_cliente)
              ->  Gather
                    ->  Partial HashAggregate
                          ->  Hash Join (pe.id_cliente = cl.id_cliente)
                                ->  Parallel Hash Join (dp.id_pedido = pe.id_pedido)
Execution Time: 384.041 ms


### 1.2 Interpretación de los planes

Consulta 1 (Ventas por Categoría):  
El optimizador eligió Hash Join tanto entre detalle_pedido y producto, como entre producto y categoria. Esto indica que se construyen tablas hash en memoria para unir grandes volúmenes de datos. El tiempo total fue 188 ms, aceptable pero con potencial de mejora si se crean índices en las claves de unión.

Consulta 2 (Ranking de Clientes):  
El plan muestra un Hash Join entre pedido y detalle_pedido, seguido de otro Hash Join con cliente. Luego se aplica un HashAggregate y finalmente un WindowAgg para calcular el ranking. El tiempo total fue 384 ms, más costoso debido a la agregación y la función de ventana sobre 20.000 clientes.

### 1.3 Optimización aplicada
Consulta 1: creación de índice en producto(id_categoria) y detalle_pedido(id_producto) para acelerar los joins.

Consulta 2: creación de índice en pedido(id_cliente) y reescritura con CTE para calcular primero el gasto total por cliente y luego aplicar la ventana.

### 1.4 Planes de ejecución (después de optimización)

#### Consulta 1 — Ventas por Categoría (optimizada)
```text
-- Output de EXPLAIN ANALYZE después de crear índices en producto.id_categoria y detalle_pedido.id_producto
Execution Time: 120.543 ms

### consuta 2 ranking
Execution Time: 280.321 ms
Join: Hash Join más eficiente gracias al índice en pedido.id_cliente



### 1.5Tabla comparativa

| Consulta   | Algoritmo antes | Tiempo antes | Cambio aplicado  | Tiempo después | Algoritmo después |

| Ventas por categoría  | Hash Join   | 188 ms | Índices en producto.id_categoria y detalle_pedido   id_producto |120 ms aprox.                                                             | Hash Join optimizado |
| Ranking de clientes   | Hash Join + WindowAgg | 384 ms  | Índice en pedido.id_cliente + reescritura con CTE | 280 ms aprox.  | Hash Join + WindowAgg optimizado |



## Parte 2 — Lectura crítica de planes de JOIN:

se tomo el plan real de la **consulta 2 (Ranking de clientes)** de la parte , con dos nodos de hash join , y se le paso a opencode unicamente el textodel plan (sin la consulta SQL ni contexto adicional),  pidiendo que lo explicara nodo por nodo.

---

### 2.1 Tipos de JOIN observados

- **Consulta 1 (Ventas por Categoría):**
  - Se observaron **Hash Join** entre `detalle_pedido` y `producto`, y entre `producto` y `categoria`.
  - El optimizador eligió esta estrategia porque las tablas son grandes y no hay restricciones de índices únicos que favorezcan un Nested Loop.

- **Consulta 2 (Ranking de Clientes):**
  - Se observaron **Hash Join** entre `pedido` y `detalle_pedido`, y otro con `cliente`.
  - Además, se aplicó un **HashAggregate** seguido de un **WindowAgg**, lo que incrementa el costo por la necesidad de ordenar y calcular funciones de ventana.

---

### 2.2 Ventajas y desventajas de cada estrategia

| Estrategia | Ventajas | Desventajas |
|------------|----------|-------------|
| **Hash Join** | Muy eficiente para grandes volúmenes de datos; aprovecha memoria para construir tablas hash. | Puede consumir mucha memoria; depende de que las claves de unión estén bien indexadas. |
| **Nested Loop** | Bueno para conjuntos pequeños o cuando hay índices que permiten búsquedas rápidas. | Escala mal con tablas grandes; repite búsquedas muchas veces. |
| **Merge Join** | Útil cuando ambas tablas están ordenadas por la clave de unión. | Requiere ordenamiento previo si no hay índices adecuados. |

---

### 2.3 Impacto de los índices en el optimizador

- La creación de índices en las claves de unión (`producto.id_categoria`, `detalle_pedido.id_producto`, `pedido.id_cliente`) permitió que el optimizador redujera el tiempo de ejecución en ambas consultas.
- En la consulta de clientes, el índice en `pedido.id_cliente` evitó que el Hash Join tuviera que escanear toda la tabla sin soporte, mejorando la eficiencia.

---

2.4 Ejercicio obligatorio: explicacion de un plan real po IA nodo por nodo:

Se tomó el plan real de la Consulta 2 (Ranking de Clientes), con dos nodos de Hash Join, y se le pasó a OpenCode únicamente el texto del plan (sin la consulta SQL ni contexto adicional), pidiéndole que lo explicara nodo por nodo.

promt utilizado:
Actuá como un experto en PostgreSQL. Te voy a pasar el texto de un plan de EXPLAIN ANALYZE. 
Explicámelo nodo por nodo, en lenguaje natural, sin usar más información que el texto que te doy. 
Para cada nodo indicá: qué operación hace, sobre qué tabla o resultado actúa, y en qué orden se ejecuta respecto a los demás nodos.

Plan:
WindowAgg  (cost=15870.51..16220.49 rows=20000 width=61) (actual time=353.362..379.215 rows=20000.00 loops=1)
  ->  Sort (sum(dp.cantidad * dp.precio_unitario)) DESC
        ->  Finalize HashAggregate (Group Key: cl.id_cliente)
              ->  Gather
                    ->  Partial HashAggregate
                          ->  Hash Join (pe.id_cliente = cl.id_cliente)
                                ->  Parallel Hash Join (dp.id_pedido = pe.id_pedido)
Execution Time: 384.041 ms


**Respuesta de OpenCode (resumen):** la IA explicó correctamente el orden de ejecución de abajo hacia arriba: Parallel Hash Join (dp-pe) → Hash Join (pe-cl) → Partial HashAggregate → Gather → Finalize HashAggregate → Sort → WindowAgg. Identificó bien que el trabajo paralelo ocurre entre los nodos 1 y 3, que el Gather reunifica los workers, y que el WindowAgg no necesita reordenar porque ya recibe los datos ordenados por el Sort previo.
 
**Tabla de contraste (obligatoria — Afirmación / ¿Correcta? / Evidencia):**
 
| Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real |
|---|---|---|
| "El grueso del tiempo de cálculo está en los dos joins hash (inicio de la cadena)" | **No** | El plan entregado no incluye `actual time` para ningún nodo de join ni de agregación — solo lo tiene el `WindowAgg` (353.362..379.215 ms) y el `Execution Time` total (384.041 ms). La IA asumió dónde se concentraba el costo sin tener esa evidencia en el texto que se le dio, violando la instrucción de no usar más información que el plan provisto. |
| "Construye una tabla hash (probablemente de pe)" | Parcialmente correcta | No afirmó con certeza algo que el plan no muestra (falta el `Hash Cond` completo con sub-nodos de escaneo para confirmar cuál tabla arma el hash). Un plan más completo permitiría verificarlo. |
| "El WindowAgg no necesita ordenar de nuevo porque ya recibe los datos ordenados por el Sort anterior" | **Sí** | Correcto: el `Sort` aparece como hijo directo del `WindowAgg` en el plan, así que la función de ventana ya recibe las filas ordenadas. |
 
**Conclusión de la Parte 2:** la explicación de OpenCode fue mayormente correcta en la estructura y el orden de ejecución de los nodos, y manejó con prudencia la incertidumbre sobre cuál tabla arma la tabla hash en cada Hash Join. Sin embargo, cometió un error típico de "alucinación con apariencia plausible": afirmó dónde se concentraba el tiempo de ejecución sin tener esa información en el plan entregado. Esto confirma la necesidad de contrastar toda salida de la IA contra el plan real antes de darla por válida, en vez de aceptarla por su redacción convincente.
 


## Parte 3 — Consultas resumen, rankings y subconsultas bajo especificación precisa

### 3.1 Consulta (a): Ranking con función de ventana

**Spec entregada a la IA:**
> "Generá una consulta SQL sobre Food Store (tablas: cliente, pedido, detalle_pedido) que devuelva para cada cliente su ID, nombre, el total gastado (suma de cantidad * precio_unitario) y su puesto en un ranking de mayor a menor gasto usando DENSE_RANK(). Considerá las columnas reales del esquema (`cliente`: id_cliente, nombre, email; sin borrado lógico). No uses SELECT *."

**Versión 1 — Con Función de Ventana (DENSE_RANK sobre JOIN + GROUP BY):**
```sql
SELECT cl.id_cliente, cl.nombre, cl.email,
       SUM(dp.cantidad * dp.precio_unitario) AS total_gastado,
       DENSE_RANK() OVER (ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC) AS puesto
FROM cliente cl
JOIN pedido pe ON pe.id_cliente = cl.id_cliente
JOIN detalle_pedido dp ON dp.id_pedido = pe.id_pedido
GROUP BY cl.id_cliente, cl.nombre, cl.email
ORDER BY puesto;



**Versión 2 — con GROUP BY (agregación + join) y subconsulta correlacionada para el ranking:**


WITH totales AS (
  SELECT cl.id_cliente, cl.nombre, cl.email,
         SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
  FROM cliente cl
  JOIN pedido pe ON pe.id_cliente = cl.id_cliente
  JOIN detalle_pedido dp ON dp.id_pedido = pe.id_pedido
  GROUP BY cl.id_cliente, cl.nombre, cl.email
)
SELECT t.id_cliente, t.nombre, t.email, t.total_gastado,
       1 + (
         SELECT COUNT(DISTINCT o.total_gastado)
         FROM totales o
         WHERE o.total_gastado > t.total_gastado
       ) AS puesto
FROM totales t
ORDER BY t.puesto, t.nombre;



### 3.2 Consulta (b): Subconsulta correlacionada

​Spec entregada a la IA:
​"Generá una consulta SQL sobre Food Store que devuelva el nombre de los productos vigentes (activo = TRUE en producto) y su cantidad total vendida, pero solo de aquellos productos cuya cantidad vendida sea mayor al promedio de cantidad vendida de su misma categoría (activo = TRUE en categoria). Usá el esquema real. No uses SELECT *."
´´´


**Versión 1 — con subconsulta correlacionada:**


SELECT v.nombre, v.cantidad_vendida
FROM (
  SELECT p.id_producto, p.id_categoria, p.nombre,
         SUM(dp.cantidad) AS cantidad_vendida
  FROM producto p
  JOIN categoria c ON c.id_categoria = p.id_categoria
  JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
  WHERE p.activo = TRUE AND c.activo = TRUE
  GROUP BY p.id_producto, p.id_categoria, p.nombre
) v
WHERE v.cantidad_vendida > (
  SELECT AVG(cat.cantidad_vendida)
  FROM (
    SELECT p2.id_categoria, SUM(dp2.cantidad) AS cantidad_vendida
    FROM producto p2
    JOIN categoria c2 ON c2.id_categoria = p2.id_categoria
    JOIN detalle_pedido dp2 ON dp2.id_producto = p2.id_producto
    WHERE p2.activo = TRUE AND c2.activo = TRUE
    GROUP BY p2.id_categoria, p2.id_producto
  ) cat
  WHERE cat.id_categoria = v.id_categoria
)
ORDER BY v.cantidad_vendida DESC;
```


**Versión 2 — con dos CTEs + JOIN en vez de subconsulta correlacionada:**

WITH ventas AS (
  SELECT p.id_producto, p.id_categoria, p.nombre,
         SUM(dp.cantidad) AS cantidad_vendida
  FROM producto p
  JOIN categoria c ON c.id_categoria = p.id_categoria
  JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
  WHERE p.activo = TRUE AND c.activo = TRUE
  GROUP BY p.id_producto, p.id_categoria, p.nombre
),
promedios AS (
  SELECT id_categoria, AVG(cantidad_vendida) AS promedio_categoria
  FROM ventas
  GROUP BY id_categoria
)
SELECT v.nombre, v.cantidad_vendida
FROM ventas v
JOIN promedios pr ON pr.id_categoria = v.id_categoria
WHERE v.cantidad_vendida > pr.promedio_categoria
ORDER BY v.cantidad_vendida DESC;
```



### 3.3 Verificación de equivalencia —

-- Sentido 1: Versión 1 EXCEPT Versión 2
(
  SELECT cl.id_cliente, cl.nombre, cl.email,
         SUM(dp.cantidad * dp.precio_unitario) AS total_gastado,
         DENSE_RANK() OVER (ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC) AS puesto
  FROM cliente cl
  JOIN pedido pe ON pe.id_cliente = cl.id_cliente
  JOIN detalle_pedido dp ON dp.id_pedido = pe.id_pedido
  GROUP BY cl.id_cliente, cl.nombre, cl.email
)
EXCEPT
(
  WITH totales AS (
    SELECT cl.id_cliente, cl.nombre, cl.email,
           SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente cl
    JOIN pedido pe ON pe.id_cliente = cl.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = pe.id_pedido
    GROUP BY cl.id_cliente, cl.nombre, cl.email
  )
  SELECT t.id_cliente, t.nombre, t.email, t.total_gastado,
         1 + (SELECT COUNT(DISTINCT o.total_gastado) FROM totales o WHERE o.total_gastado > t.total_gastado) AS puesto
  FROM totales t
);



**Verificación consulta (b) — Productos sobre el promedio de su categoría:**


-- Sentido 1: Versión 1 EXCEPT Versión 2
(
  SELECT v.nombre, v.cantidad_vendida
  FROM (
    SELECT p.id_producto, p.id_categoria, p.nombre, SUM(dp.cantidad) AS cantidad_vendida
    FROM producto p
    JOIN categoria c ON c.id_categoria = p.id_categoria
    JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
    WHERE p.activo = TRUE AND c.activo = TRUE
    GROUP BY p.id_producto, p.id_categoria, p.nombre
  ) v
  WHERE v.cantidad_vendida > (
    SELECT AVG(cat.cantidad_vendida)
    FROM (
      SELECT p2.id_categoria, SUM(dp2.cantidad) AS cantidad_vendida
      FROM producto p2
      JOIN categoria c2 ON c2.id_categoria = p2.id_categoria
      JOIN detalle_pedido dp2 ON dp2.id_producto = p2.id_producto
      WHERE p2.activo = TRUE AND c2.activo = TRUE
      GROUP BY p2.id_categoria, p2.id_producto
    ) cat
    WHERE cat.id_categoria = v.id_categoria
  )
)
EXCEPT
(
  WITH ventas AS (
    SELECT p.id_producto, p.id_categoria, p.nombre, SUM(dp.cantidad) AS cantidad_vendida
    FROM producto p
    JOIN categoria c ON c.id_categoria = p.id_categoria
    JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
    WHERE p.activo = TRUE AND c.activo = TRUE
    GROUP BY p.id_producto, p.id_categoria, p.nombre
  ),
  promedios AS (
    SELECT id_categoria, AVG(cantidad_vendida) AS promedio_categoria
    FROM ventas
    GROUP BY id_categoria
  )
  SELECT v.nombre, v.cantidad_vendida
  FROM ventas v
  JOIN promedios pr ON pr.id_categoria = v.id_categoria
  WHERE v.cantidad_vendida > pr.promedio_categoria
); 
---

## Parte 4 — Competencia de optimización entre equipos

Se tomó como consigna común la consulta analítica de **Ranking de Clientes sobre la base masiva con 200.000 registros**, la cual involucra tres tablas (`cliente`, `pedido`, `detalle_pedido`), agregación por cliente y cálculo de ranking mediante función de ventana.

### 4.1 Consulta Evaluada
```sql
EXPLAIN ANALYZE 
SELECT cl.id_cliente, cl.nombre,
       SUM(dp.cantidad * dp.precio_unitario) AS total_gastado,
       DENSE_RANK() OVER (ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC) AS ranking
FROM cliente cl
JOIN pedido pe ON pe.id_cliente = cl.id_cliente
JOIN detalle_pedido dp ON dp.id_pedido = pe.id_pedido
GROUP BY cl.id_cliente, cl.nombre
ORDER BY total_gastado DESC;


4.2resgistro de la copetencia:

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo después (ms) | Mejora (x) |
| :--- | :--- | :---: | :---: | :---: |
| **Mi Equipo** | Creación de índice B-Tree en FK `pedido(id_cliente)` + reescritura de agregación con CTE previo a la ventana | **384.04 ms** | **280.32 ms** | **1.37x** |

4.3 Propuestas de la IA que NO Funcionaron
​Índice B-Tree en detalle_pedido(cantidad): La IA sugirió crear un índice sobre la columna cantidad de la tabla detalle_pedido para acelerar la suma. Al ejecutar EXPLAIN ANALYZE, se evidenció que el planificador de PostgreSQL ignoró el índice y continuó realizando un Parallel Seq Scan. Esto se debe a que la consulta requiere procesar el volumen completo de registros de la tabla, por lo que la lectura secuencial resulta más eficiente para el motor que realizar búsquedas dispersas en el índice.
​Conclusiones generales y aprendizajes


​Evaluación de Planes de Ejecución: El uso de EXPLAIN ANALYZE demostró ser la herramienta determinante para diagnosticar cuellos de botella y validar si el motor de PostgreSQL modifica los algoritmos de combinación (Hash Join, Merge Join, Nested Loop) al aplicar nuevos índices.
​Análisis Crítico de Propuestas de IA: Se detectó que las herramientas de IA generaron inicialmente consultas asumiendo columnas de borrado lógico (eliminado = FALSE) y campos de identidad (apellido) que no existen en el esquema real de cliente, pedido y detalle_pedido. Se constató que solo producto y categoria poseen la bandera activo.
​Verificación Formal de Equivalencia: El uso del operador EXCEPT cruzado permitió confirmar la equivalencia matemática (0 filas de diferencia) entre las versiones con funciones de ventana (DENSE_RANK) y las reescrituras basadas en CTEs o subconsultas correlacionadas.


​Declaración de Uso de IA (DUIA)


## Declaración de Uso de IA (DUIA)

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
| :--- | :--- | :--- | :--- |
| **OpenCode / Kiro** | Proponer índices para Consulta 1 (Parte 1) | *"Plan real de EXPLAIN ANALYZE + pedido de índices justificados por el nodo de join"* | **Aceptado:** El índice en `producto.id_categoria` y `detalle_pedido.id_producto` redujo el tiempo de 188.13 ms a 120.54 ms. |
| **Gemini** | Reescritura de la Consulta 2 con CTE (Parte 1) | *"Reescribir el ranking usando CTE para separar cálculo de total y ranking"* | **Aceptado:** Mejoró la estructura del plan y redujo el tiempo de 384.04 ms a 280.32 ms. |
| **OpenCode** | Explicar plan nodo por nodo (Parte 2) | *"Explicá este plan de PostgreSQL nodo por nodo, en lenguaje natural, solo con el texto del plan"* | **Parcialmente descartado:** Afirmó estimaciones de costo sin validar los tiempos reales de ejecución ni las lecturas de memoria[span_0](start_span)[span_0](end_span). |
| **OpenCode / Gemini** | Generar SQL ranking con función de ventana (Parte 3a, v1) | *"Spec de ranking con DENSE_RANK sobre cliente, pedido y detalle_pedido, ajustado al esquema real sin borrado lógico en cliente"* | **Aceptado:** El SQL generado cumplió exactamente con las columnas reales del esquema. |
| **Gemini** | Generar SQL productos con CTE + join (Parte 3b, v2) | *"Generá una segunda versión con CTEs para filtrar productos con ventas superiores al promedio de su categoría (activo = TRUE)"* | **Aceptado:** Se verificó equivalencia formal devolviendo 0 filas en el `EXCEPT`. |
| **OpenCode** | Sugerencia de índice en `detalle_pedido(cantidad)` (Parte 4) | *"Proponé un índice para optimizar la suma de montos en detalle_pedido"* | **Descartado:** El optimizador de PostgreSQL no lo utilizó debido a la baja selectividad de la columna sobre los 200.000 registros[span_1](start_span)[span_1](end_span). |