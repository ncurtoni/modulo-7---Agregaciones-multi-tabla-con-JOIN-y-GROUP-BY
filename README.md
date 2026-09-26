# Agregaciones multi-tabla para features de ML

Script SQL que transforma cuatro tablas relacionadas (`clientes`, `pedidos`,
`detalles_pedido`, `productos`) en una tabla de features por cliente,
lista para un pipeline de Machine Learning.

## Archivo

- `consultas_features.sql`: esquema, datos de prueba, y las 4 consultas
  del ejercicio, en un solo archivo ejecutable de punta a punta.

## Como ejecutarlo

Con DuckDB:

```bash
duckdb < consultas_features.sql
```

O con SQLite:

```bash
sqlite3 features.db < consultas_features.sql
```

## Que resuelve cada consulta

1. **LTV por cliente**: `LEFT JOIN` desde `clientes` para no perder a los
   clientes sin compras (en los datos de prueba, Carla), con `COALESCE`
   para que su gasto quede en 0 en vez de `NULL`.
2. **Gasto por categoria**: agregacion condicionada con `CASE WHEN` dentro
   de `SUM()`, generando `gasto_alimentos` y `gasto_tecnologia` en una sola
   pasada, sin subconsultas.
3. **Segmentacion de clientes activos**: filtra con `HAVING` a los clientes
   con mas de 3 pedidos **y** gasto promedio mayor a 50. Se usa
   `COUNT(DISTINCT pedido_id)` en vez de `COUNT(*)` para no inflar el
   conteo cuando un pedido tiene varios productos.
4. **Ranking final**: sobre el resultado ya segmentado, agrega
   `RANK() OVER (PARTITION BY ciudad ORDER BY gasto_total DESC)` para
   ordenar a los clientes dentro de su propia ciudad.

## Datos de prueba

Los datos incluidos estan pensados para poner a prueba cada punto:

- **Carla** no tiene ningun pedido (prueba el `LEFT JOIN` + `COALESCE`).
- **Diego** tiene mas de 3 pedidos pero un gasto promedio bajo (prueba que
  el `HAVING` exige ambas condiciones, no alcanza con cumplir una sola).
- Los clientes estan repartidos en dos ciudades (Buenos Aires y Cordoba)
  para que el ranking por ciudad tenga sentido.
