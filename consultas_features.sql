-- Ejercicio: Agregaciones multi-tabla para features de ML
-- Ejecutable en SQLite o DuckDB

-- ============================================================
-- Configuracion: esquema y datos de prueba
-- ============================================================
-- Datos pensados a proposito para poner a prueba cada punto: Carla no
-- tiene ningun pedido (prueba el LEFT JOIN), Diego cumple la cantidad
-- de pedidos pero no el gasto promedio (prueba que el HAVING combina
-- ambas condiciones con AND, no alcanza con cumplir una sola), y hay
-- clientes en dos ciudades distintas para que el ranking tenga sentido.

CREATE TABLE clientes (
    cliente_id INTEGER,
    nombre VARCHAR,
    ciudad VARCHAR
);

CREATE TABLE productos (
    producto_id INTEGER,
    nombre VARCHAR,
    categoria VARCHAR,
    precio DECIMAL
);

CREATE TABLE pedidos (
    pedido_id INTEGER,
    cliente_id INTEGER,
    fecha DATE
);

CREATE TABLE detalles_pedido (
    detalle_id INTEGER,
    pedido_id INTEGER,
    producto_id INTEGER,
    cantidad INTEGER
);

INSERT INTO clientes VALUES
    (1, 'Ana', 'Buenos Aires'),
    (2, 'Bruno', 'Cordoba'),
    (3, 'Carla', 'Buenos Aires'),  -- sin pedidos, a proposito
    (4, 'Diego', 'Cordoba'),
    (5, 'Elena', 'Buenos Aires'),
    (6, 'Fabian', 'Cordoba');

INSERT INTO productos VALUES
    (101, 'Notebook', 'Tecnologia', 1000),
    (102, 'Mouse', 'Tecnologia', 50),
    (103, 'Arroz', 'Alimentos', 10),
    (104, 'Fideos', 'Alimentos', 8),
    (105, 'Monitor', 'Tecnologia', 300);

INSERT INTO pedidos VALUES
    (1001, 1, '2025-01-05'), (1002, 1, '2025-01-10'), (1003, 1, '2025-02-01'), (1004, 1, '2025-02-15'),
    (2001, 2, '2025-01-08'), (2002, 2, '2025-01-20'),
    (3001, 4, '2025-01-05'), (3002, 4, '2025-01-12'), (3003, 4, '2025-02-01'), (3004, 4, '2025-02-10'),
    (4001, 5, '2025-01-03'), (4002, 5, '2025-01-15'), (4003, 5, '2025-02-01'), (4004, 5, '2025-02-10'), (4005, 5, '2025-02-20'),
    (5001, 6, '2025-01-04'), (5002, 6, '2025-01-18'), (5003, 6, '2025-02-02'), (5004, 6, '2025-02-14');

INSERT INTO detalles_pedido VALUES
    (1, 1001, 101, 1), (2, 1002, 103, 2), (3, 1003, 104, 3), (4, 1004, 105, 1),
    (5, 2001, 102, 1), (6, 2002, 103, 1),
    (7, 3001, 104, 1), (8, 3002, 103, 1), (9, 3003, 104, 1), (10, 3004, 103, 1),
    (11, 4001, 101, 1), (12, 4002, 105, 1), (13, 4003, 102, 2), (14, 4004, 103, 5), (15, 4005, 104, 5),
    (16, 5001, 101, 1), (17, 5002, 105, 1), (18, 5003, 102, 3), (19, 5004, 103, 2);


-- ============================================================
-- Punto 1: Valor del cliente (LTV) con LEFT JOIN
-- ============================================================
-- LEFT JOIN desde clientes: si un cliente no tiene pedidos, sigue
-- apareciendo en el resultado (Carla, en este dataset), con gasto_total
-- en 0 gracias al COALESCE, en vez de desaparecer o quedar en NULL.

SELECT
    c.cliente_id,
    c.nombre,
    COALESCE(SUM(d.cantidad * pr.precio), 0) AS gasto_total
FROM clientes c
LEFT JOIN pedidos p ON c.cliente_id = p.cliente_id
LEFT JOIN detalles_pedido d ON p.pedido_id = d.pedido_id
LEFT JOIN productos pr ON d.producto_id = pr.producto_id
GROUP BY c.cliente_id, c.nombre
ORDER BY c.cliente_id;


-- ============================================================
-- Punto 2: Gasto por categoria (agregacion condicionada)
-- ============================================================
-- Cada CASE WHEN filtra su propia categoria dentro del SUM. Una sola
-- pasada por los datos genera dos features distintas, sin subconsultas.

SELECT
    c.cliente_id,
    c.nombre,
    SUM(CASE WHEN pr.categoria = 'Alimentos' THEN d.cantidad * pr.precio ELSE 0 END) AS gasto_alimentos,
    SUM(CASE WHEN pr.categoria = 'Tecnologia' THEN d.cantidad * pr.precio ELSE 0 END) AS gasto_tecnologia
FROM clientes c
LEFT JOIN pedidos p ON c.cliente_id = p.cliente_id
LEFT JOIN detalles_pedido d ON p.pedido_id = d.pedido_id
LEFT JOIN productos pr ON d.producto_id = pr.producto_id
GROUP BY c.cliente_id, c.nombre
ORDER BY c.cliente_id;


-- ============================================================
-- Punto 3: Segmentacion de clientes activos (HAVING)
-- ============================================================
-- COUNT(DISTINCT p.pedido_id), no COUNT(*): al unir con detalles_pedido,
-- un pedido con 3 productos generaria 3 filas. Contar pedido_id distinto
-- evita inflar el conteo de compras por esa duplicacion del JOIN.

SELECT
    c.cliente_id,
    c.nombre,
    c.ciudad,
    COUNT(DISTINCT p.pedido_id) AS num_pedidos,
    COALESCE(SUM(d.cantidad * pr.precio), 0) AS gasto_total,
    COALESCE(SUM(d.cantidad * pr.precio), 0) / COUNT(DISTINCT p.pedido_id) AS gasto_promedio
FROM clientes c
LEFT JOIN pedidos p ON c.cliente_id = p.cliente_id
LEFT JOIN detalles_pedido d ON p.pedido_id = d.pedido_id
LEFT JOIN productos pr ON d.producto_id = pr.producto_id
GROUP BY c.cliente_id, c.nombre, c.ciudad
HAVING COUNT(DISTINCT p.pedido_id) > 3
   AND COALESCE(SUM(d.cantidad * pr.precio), 0) / COUNT(DISTINCT p.pedido_id) > 50
ORDER BY c.cliente_id;


-- ============================================================
-- Punto 4: Consulta final, con ranking por ciudad
-- ============================================================
-- Combina todo lo anterior y agrega una funcion de ventana. El RANK()
-- se calcula DESPUES de que el HAVING ya filtro los grupos (por eso el
-- ranking solo compite entre los clientes que pasaron la segmentacion),
-- particionado por ciudad para que cada una tenga su propio 1, 2, 3...

SELECT
    c.cliente_id,
    c.nombre,
    c.ciudad,
    COUNT(DISTINCT p.pedido_id) AS num_pedidos,
    COALESCE(SUM(d.cantidad * pr.precio), 0) AS gasto_total,
    SUM(CASE WHEN pr.categoria = 'Alimentos' THEN d.cantidad * pr.precio ELSE 0 END) AS gasto_alimentos,
    SUM(CASE WHEN pr.categoria = 'Tecnologia' THEN d.cantidad * pr.precio ELSE 0 END) AS gasto_tecnologia,
    RANK() OVER (PARTITION BY c.ciudad ORDER BY COALESCE(SUM(d.cantidad * pr.precio), 0) DESC) AS ranking_en_ciudad
FROM clientes c
LEFT JOIN pedidos p ON c.cliente_id = p.cliente_id
LEFT JOIN detalles_pedido d ON p.pedido_id = d.pedido_id
LEFT JOIN productos pr ON d.producto_id = pr.producto_id
GROUP BY c.cliente_id, c.nombre, c.ciudad
HAVING COUNT(DISTINCT p.pedido_id) > 3
   AND COALESCE(SUM(d.cantidad * pr.precio), 0) / COUNT(DISTINCT p.pedido_id) > 50
ORDER BY c.ciudad, ranking_en_ciudad;
