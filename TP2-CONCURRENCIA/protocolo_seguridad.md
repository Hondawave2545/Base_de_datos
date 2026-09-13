# Protocolo de seguridad para Operaciones de Base de datos 
1. Copia de trabajo : Todas la pruebas y scripts  se ejecutan unicamente sobre una base de datos local de desarrollo, nunca sobre datos reales.
2. Transaccion: Todo script de escritura se prueba primero dentro de un bloque BEGIN; ... ROLLBACK; antes de confirmar con COMMIT;.
3. Respaldo: Antes de aplicar un cambio en la estructura de la base, se realiza una copia de respaldo para poder restaurar si algo falla.