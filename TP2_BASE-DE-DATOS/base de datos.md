# TRABAJO PRÁCTICO - SEMANA 3: OPTIMIZACIÓN
**Materia:** Base de Datos II  
**Proyecto:** Food Store  
**Alumno/a:** Yoselie Aquino

---

## Parte 1 — Poblar la base masivamente
Se ejecutó el script de carga masiva en PostgreSQL/DBeaver cumpliendo con todos los CHECKs y FKs.
* **Resultado de conteos finales (`SELECT` de verificación):**
  - `producto`: 50.000 filas
  - `cliente`: 20.000 filas
  - `pedido`: 200.000 filas
  - `detalle_pedido`: 200.000 filas

*   ![Evidencia parte1](foto.jpg)


---

## Parte 2 — Laboratorio: consultas lentas, EXPLAIN y optimización medida

### 2.2 Tabla de resultados de mediciones
![Evidencia parte2](foto2.jpg)

| Consulta | Plan Antes | Cambio Aplicado | Plan Después | Mejora |
| :--- | :--- | :--- | :--- | :---: |
| **1. Búsqueda por nombre** | Seq Scan (~12.5 ms, cost=0..1450) | `CREATE INDEX idx_producto_nombre_pattern ON producto (nombre text_pattern_ops);` | Bitmap Index Scan (~0.15 ms, cost=4.5..25) | **~80x** |
| **2. Ranking por categoría** | Seq Scan en `detalle_pedido` (~45.0 ms, cost=0..3850) | `CREATE INDEX idx_detalle_pedido_producto ON detalle_pedido (id_producto);` | Index Scan / HashAggregate (~18.2 ms, cost=12..1200) | **~2.5x** |
| **3. Pedidos por rango de fechas** | Seq Scan en `pedido` (~38.0 ms, cost=0..5200) | `CREATE INDEX idx_pedido_fecha_hora ON pedido (fecha_hora);` | Bitmap Index Scan (~1.8 ms, cost=8.5..320) | **~21x** |

**Justificación técnica de índices:**
1. `idx_producto_nombre_pattern`: Permite evaluar patrones de texto (`LIKE 'text%'`) transformando el `Seq Scan` en un `Bitmap Index Scan`.
2. `idx_detalle_pedido_producto`: Permite acelerar la búsqueda por clave foránea `id_producto` sin recorrer toda la tabla de detalles.
3. `idx_pedido_fecha_hora`: Permite al optimizador filtrar por rangos de tiempo utilizando la estructura de árbol B-Tree del índice.

---

## Parte 3 — Lectura crítica de planes interpretados por IA

| Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real |
| :--- | :---: | :--- |
| "El valor de `cost=1450` representa 1450 milisegundos de tiempo de ejecución." | **No** | El `cost` es una unidad arbitraria de I/O y CPU estimada por el planificador, no mide tiempo real en ms. |
| "Las operaciones del plan anidado se ejecutan de arriba hacia abajo." | **No** | Los planes de ejecución en PostgreSQL se procesan de adentro hacia afuera (de las hojas a la raíz del árbol). |
| "El índice se utilizó para filtrar los registros descartados." | **Sí** | Confirmado por el nodo `Index Scan` que reemplazó el filtro `Filter:` de lectura secuencial. |

---

## Parte 4 — Consultas resumen y subconsultas

### 4.1 Consulta de agregación
* **Verificación de equivalencia con `EXCEPT` cruzado:** Devuelve **0 filas** en ambos sentidos. Las dos versiones (JOIN + GROUP BY y Subconsulta correlacionada) son semánticamente equivalentes.

### 4.2 Consulta con subconsulta
* **Verificación de equivalencia con `EXCEPT` cruzado:** Devuelve **0 filas** en ambos sentidos. Ambas estructuras filtran correctamente a los clientes con consumo total superior a $50.000.

---

## Parte 5 — Competencia de optimización entre equipos

* **Consulta evaluada:** `SELECT nombre, precio_lista, stock FROM producto WHERE id_categoria = 3 AND precio_lista BETWEEN 1000 AND 3000 ORDER BY precio_lista;`
* **Estrategia aplicada:** Creación de un índice compuesto multicolumna sobre `(id_categoria, precio_lista)`.
* **Tiempo Antes:** ~10.2 ms
* **Tiempo Después:** ~0.4 ms
* **Mejora:** **25.5x**

---

## Declaración de Uso de IA (DUIA)

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / descartó — por qué |
| :--- | :--- | :--- | :--- |
| OpenCode | Generar script de carga masiva (Parte 1) | Spec de inserción de 200k pedidos y 50k productos. | **Se aceptó:** Mantuvo los CHECKs e integridad referencial. |
| OpenCode / Kiro | Proponer índices (Parte 2) | Propuestas de índices para `LIKE`, FKs y rangos de fecha. | **Se aceptó:** Redujo notablemente el costo y tiempo en EXPLAIN. |
| Gemini / Claude | Explicar plan de ejecución (Parte 3) | Explicación nodo por nodo del plan de consulta. | **Se corrigió:** Se identificaron errores conceptuales en la interpretación de `cost`. |
| ChatGPT | Generar SQL con spec precisa (Parte 4) | Specs de consultas 4.1 y 4.2. | **Se aceptó:** Se verificó equivalencia con `EXCEPT`. |