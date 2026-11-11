# Verificación de equivalencia — Parte D

> **Estado:** COMPLETADO — 2026-11-11 ejecutado `05_usuario_anon.sql`.

---

## 1. Tabla usuario_anon — estructura

Creada por `05_usuario_anon.sql` con este diseño:

```sql
CREATE TABLE public.usuario_anon AS
SELECT
  id_usuario,
  'usuario_' || id_usuario || '@anon.local'  AS email,
  rol,
  date_trunc('month', fecha_alta)::date       AS mes_alta,
  activo
FROM public.usuario;
```

**Columnas excluidas de la anonimización:**
- `password_hash` — no se incluye en ningún caso.

**Criterio:** los valores de `email` son deterministas (dependen solo del `id_usuario`), lo que permite reproducir la tabla en cualquier momento desde la tabla original. Los emails reales no salen de la base.

---

## 2. Consulta A — sobre usuario_anon

```sql
SELECT rol, mes_alta, count(*) AS cantidad
FROM public.usuario_anon
GROUP BY rol, mes_alta
ORDER BY mes_alta, rol;
```

**Resultado real (2026-11-11):**

| rol | mes_alta | cantidad |
|---|---|---|
| admin_datos | 2026-11-01 | 1 |
| app_web | 2026-11-01 | 1 |
| reportes | 2026-11-01 | 1 |
| soporte | 2026-11-01 | 1 |

---

## 3. Consulta B — sobre usuario (tabla real)

Consulta especificada a Kiro con el prompt:
> "Dada esta consulta sobre `usuario_anon`, escribí la consulta equivalente sobre la tabla real `usuario`."

Respuesta de Kiro (interacción #8 en BITACORA.md):

```sql
SELECT
  rol,
  date_trunc('month', fecha_alta)::date AS mes_alta,
  count(*)                              AS cantidad
FROM public.usuario
GROUP BY rol, date_trunc('month', fecha_alta)::date
ORDER BY mes_alta, rol;
```

**Validación humana aplicada:** la consulta generada por Kiro es correcta. El `date_trunc('month', fecha_alta)::date` produce exactamente el mismo valor que el campo `mes_alta` de `usuario_anon`, porque ese campo se construyó con la misma expresión. No se requirió corrección.

**Resultado real (2026-11-11):**

| rol | mes_alta | cantidad |
|---|---|---|
| admin_datos | 2026-11-01 | 1 |
| app_web | 2026-11-01 | 1 |
| reportes | 2026-11-01 | 1 |
| soporte | 2026-11-01 | 1 |

---

## 4. Verificación de equivalencia (diferencia simétrica)

```sql
-- Resultado esperado: 0 filas
```

**Resultado real (2026-11-11):**

```
 direccion | rol | mes_alta | cantidad 
-----------+-----+----------+----------
(0 filas)
```

**Resultado esperado:** 0 filas — las dos consultas deben producir exactamente los mismos grupos y conteos, porque `usuario_anon` se construyó aplicando las mismas transformaciones que la Consulta B.

**Resultado obtenido:** ✅ 0 filas — **equivalencia confirmada**.

---

## 5. Información que no debe enviarse a la IA sin anonimizar

Food Store almacena dos categorías de datos que no deben enviarse a un asistente de IA sin pasar primero por un proceso de anonimización:

**Datos de alta sensibilidad:**
- `usuario.email` — dirección de correo electrónico de los operadores del sistema (dato personal directo).
- `usuario.password_hash` — aun siendo un hash, su exposición facilita ataques offline. No debe salir del servidor bajo ningún concepto.
- `clientes.email`, `clientes.telefono`, `clientes.direccion_entrega` — datos de contacto de clientes reales.
- `empleados.dni` — documento de identidad civil de alta sensibilidad.

**Procedimiento a seguir antes de usar con IA:**
Aplicar el mismo criterio que `usuario_anon`: reemplazar identificadores directos por valores sintéticos deterministas (`'usuario_' || id || '@anon.local'`), truncar fechas al mes, y nunca incluir credenciales ni documentos de identidad.

---

## 6. Pendientes completados

- [x] Ejecutar `05_usuario_anon.sql` en `foodstore_u5_test`.
- [x] Pegar los resultados reales de las Consultas A y B en las secciones 2 y 3.
- [x] Pegar el resultado de la diferencia simétrica en la sección 4.
- [x] Registrar en `BITACORA.md`, interacción #8.
