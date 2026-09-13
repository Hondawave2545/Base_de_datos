# Declaración de Uso de IA (DUIA) - Parte 1

| Campo | Completar |
| **Herramienta** | OpenCode |
| **Spec o prompt utilizado** | Agregar restricciones CHECK para `precio_lista > 0` y `stock >= 0` en `producto`, `cantidad > 0` en `detalle_pedido`, y `nombre` no vacío en `categoria`. |
| **Qué generó** | Script SQL (`restricciones.sql`) con sentencias ALTER TABLE y restricciones CHECK para las 3 tablas. |
| **Qué se aceptó** | La estructura completa de los ALTER TABLE y la lógica de validación de valores positivos. |
| **Qué se modificó o descartó** | Se ajustó la regla en la tabla `categoria` agregando `TRIM()` para evitar guardar nombres que solo contengan espacios en blanco. |
| **Verificación realizada** | Se probaron consultas INSERT inválidas dentro de una transacción (`BEGIN; ... ROLLBACK;`) confirmando que el motor de PostgreSQL las rechazó correctamente. |