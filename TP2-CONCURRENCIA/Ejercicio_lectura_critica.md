
# Parte 3: El riesgo fundacional - Ejercicio de lectura crítica

En esta sección se analiza la diferencia entre la intención de un script generado por IA y su ejecución real en la base de datos, identificando fallas de alcance y manejo de valores nulos antes de aplicar cualquier cambio.

## Análisis y Corrección de Scripts

### Script 1: Deshabilitar funciones de películas retiradas

#### 1. Script original propuesto por IA
```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartel
UPDATE funcion
SET activa = FALSE;

2. Filas que afectaría realmente
Afectará a todas las filas de la tabla funcion sin excepción (el 100% de los registros).
3. Por qué no coincide con la consigna
Falta una cláusula WHERE que filtre las funciones asociadas a películas que ya no están en cartelera. Al no tener condición, desactiva por completo la cartelera del cine.
4. Versión corregida
UPDATE funcion
SET activa = FALSE
WHERE id_pelicula IN (
    SELECT id_pelicula 
    FROM pelicula 
    WHERE en_cartelera = FALSE
);

Script 2: Limpieza de categorías sin productos
1. Script original propuesto por IA
-- Generado para: limpiar las categorías sin productos asociados
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);

2. Filas que afectaría realmente
No afectará a ninguna fila (0 filas eliminadas) si existe al menos un valor NULL en la columna categoria_id de la tabla producto.
3. Por qué no coincide con la consigna
En SQL, la comparación NOT IN contra una subconsulta que devuelve al menos un NULL evalúa el resultado a UNKNOWN para todas las filas. Debido a esto, el motor no elimina nada y la operación falla silenciosamente.
4. Versión corregida (Opción recomendada con NOT EXISTS)
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1 
    FROM producto p 
    WHERE p.categoria_id = c.id
);

(Alternativa equivalente con NOT IN filtrando nulos: DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto WHERE categoria_id IS NOT NULL);).