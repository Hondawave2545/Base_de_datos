# Informe de Concurrencia y Transacciones - Parte 2

**Dominio:** Food Store (cliente, categoria, producto, pedido, detalle_pedido)  
**Motor:** PostgreSQL / DBeaver  

Para este trabajo probé tres escenarios clásicos de concurrencia abriendo dos sesiones al mismo tiempo en DBeaver, para ver en la práctica cómo se comporta PostgreSQL frente a lecturas y escrituras simultáneas.
## Escenario 1: Lectura No Repetible (Non-Repeatable Read)

### Nivel de Aislamiento
`READ COMMITTED` (nivel por defecto).

### Pasos Ejecutados

**Sesión 1:**
```sql
BEGIN;
INSERT INTO producto (nombre, precio_lista, stock, id_categoria) 
VALUES ('Producto Fantasma Test', 500.00, 10, 1);
COMMIT;

Observaciones y Explicación
Similar al primer escenario, pero acá lo que cambió no fue un valor sino la cantidad de filas: la segunda vez que conté los productos de la categoría, apareció uno más de la nada. Ese "nuevo" producto lo había insertado y confirmado la Sesión 2 mientras mi transacción seguía abierta.
Esto es lo que se conoce como Lectura Fantasma: filas nuevas que "aparecen" en una consulta repetida porque otra transacción las insertó y confirmó en el medio. Bajo READ COMMITTED esto puede pasar sin problema; para evitarlo habría que usar un nivel de aislamiento más estricto, como REPEATABLE READ o SERIALIZABLE.