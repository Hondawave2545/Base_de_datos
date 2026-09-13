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
SELECT precio FROM producto WHERE id = 1; 

Sesión 2:
BEGIN;
UPDATE producto SET precio = 1800.00 WHERE id = 1;
COMMIT;

Sesión 1 (segunda consulta dentro de la misma transacción):
SELECT precio FROM producto WHERE id = 1; 
COMMIT;

Observaciones y Explicación:
Repetí la misma consulta dos veces dentro de la misma transacción de la Sesión 1, y el resultado cambió: la primera vez vi el precio viejo y la segunda, el nuevo. Esto pasó porque en el medio la Sesión 2 modificó el registro y confirmó el cambio con COMMIT.
Esto tiene sentido con cómo funciona READ COMMITTED: cada consulta ve los datos que estén confirmados en ese momento, no una "foto" fija de toda la transacción. Por eso, si otra sesión actualiza y confirma algo en el medio, mi transacción lo va a ver aunque no haya terminado todavía. A esto se le llama Lectura No Repetible.
Escenario 2: Espera por Bloqueo (Lock Wait)
Pasos Ejecutados
Sesión 1:
BEGIN;
SELECT * FROM producto WHERE id = 1 FOR UPDATE;

Sesión 2:
BEGIN;
UPDATE producto SET precio = 2000.00 WHERE id = 1;
-- La consulta se queda bloqueada esperando que la Sesión 1 libere el recurso.

Sesión 1:
COMMIT; -- Al hacer COMMIT, se libera el bloqueo.

Observaciones y Explicación
Acá la diferencia se noto enseguida: apenas ejecuté el UPDATE en la Sesión 2, la consola se quedó "colgada" sin devolver nada, esperando. Recién cuando hice COMMIT en la Sesión 1, la Sesión 2 se destrabó y aplicó el cambio.
Esto pasa porque FOR UPDATE bloquea la fila de forma exclusiva. Mientras esa transacción no termine (con COMMIT o ROLLBACK), ninguna otra puede tocar esa misma fila; simplemente se queda esperando su turno.
Escenario 3: Lectura Fantasma (Phantom Read)
Nivel de Aislamiento
READ COMMITTED
Pasos Ejecutados
Sesión 1:
BEGIN;
SELECT COUNT(*) FROM producto WHERE categoria_id = 1;

Sesión 2:
BEGIN;
INSERT INTO producto (nombre, precio, categoria_id) VALUES ('Producto Nuevo', 500.00, 1);
COMMIT;

Sesión 1:
SELECT COUNT(*) FROM producto WHERE categoria_id = 1; 
COMMIT;

Observaciones y Explicación
Similar al primer escenario, pero acá lo que cambió no fue un valor sino la cantidad de filas: la segunda vez que conté los productos de la categoría, apareció uno más de la nada. Ese "nuevo" producto lo había insertado y confirmado la Sesión 2 mientras mi transacción seguía abierta.
Esto es lo que se conoce como Lectura Fantasma: filas nuevas que "aparecen" en una consulta repetida porque otra transacción las insertó y confirmó en el medio. Bajo READ COMMITTED esto puede pasar sin problema; para evitarlo habría que usar un nivel de aislamiento más estricto, como REPEATABLE READ o SERIALIZABLE.