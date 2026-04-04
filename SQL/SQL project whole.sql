CREATE TABLE customers (
    customer_id TEXT,
    customer_unique_id TEXT,
    customer_zip_code_prefix INT,
    customer_city TEXT,
    customer_state TEXT
);

SELECT * FROM customers;

-- TOTAL CUSTOMERS
SELECT COUNT(DISTINCT customer_unique_id) AS total_customers
FROM customers;

-- CUSTOMERS BY STATE
SELECT customer_state, COUNT(*) AS total_customers
FROM customers
GROUP BY customer_state
ORDER BY total_customers DESC;

-- CUSTOMERS BY STATE(REMOVING DUPLICATE CUSTOMERS)
SELECT customer_state, COUNT(DISTINCT customer_unique_id) AS total_customers
FROM customers
GROUP BY customer_state
ORDER BY total_customers DESC;

-- NOW WORKING ON MULTIPLE TABLES

--CREATING ORDERS TABLE
CREATE TABLE orders(
		order_id TEXT,
		customer_id TEXT,
		order_status TEXT,
		order_purchase_timestamp TIMESTAMP,
		order_approved_at TIMESTAMP,
		order_delivered_carrier_date TIMESTAMP,
		order_delivered_customer_date TIMESTAMP,
		order_estimated_delivery_date TIMESTAMP
);

DROP TABLE orders;
CREATE TABLE orders (
    	order_id TEXT,
    	customer_id TEXT,
    	order_status TEXT,
    	order_purchase_timestamp TEXT,
    	order_approved_at TEXT,
    	order_delivered_carrier_date TEXT,
    	order_delivered_customer_date TEXT,
    	order_estimated_delivery_date TEXT
);

SELECT * FROM orders;

-- just to check the type of data
SELECT order_purchase_timestamp, 
       pg_typeof(order_purchase_timestamp)
FROM orders
LIMIT 5;

-- total order status by groups
SELECT 
    order_status,
    COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;


-- FIRST JOIN ( CUSTOMERS + ORDERS)
SELECT
		c.customer_id,
		c.customer_state,
		o.order_id,
		o.order_purchase_timestamp
FROM customers c
JOIN orders o
ON c.customer_id = o.customer_id;

-- customers by state (with orders)
SELECT
		c.customer_state,
		COUNT(o.order_id) AS total_orders
FROM customers c
JOIN orders o
ON c.customer_id = o.customer_id
GROUP BY c.customer_state
ORDER BY total_orders DESC;

-- Unique Customers vs Orders (JUST TO CHECK REPEAT ORDERS EXIST OR NOT)
SELECT 
	COUNT(DISTINCT c.customer_unique_id) AS total_customers,
	COUNT(o.order_id) AS total_orders
FROM customers c
JOIN orders o
ON c.customer_id = o.customer_id;

-- ORDERS PER CUSTOMER
SELECT
	c.customer_unique_id,
	COUNT(o.order_id) AS total_orders
FROM customers c
JOIN orders o
ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
ORDER BY total_orders DESC;

-- CREATE ORDER ITEMS TABLE
CREATE TABLE order_items (
    order_id TEXT,
    order_item_id INT,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TEXT,
    price FLOAT,
    freight_value FLOAT
);

SELECT * FROM order_items;

-- TOTAL REVENUE
SELECT SUM(price) AS total_revenue
FROM order_items;

-- JOIN OF (ORDERS + ORDER_ITEMS)
SELECT 
	o.order_id,
	oi.price
FROM orders o
JOIN order_items oi
ON o.order_id = oi.order_id;

-- REVENUE BY STATE ( COMBINING CUSTOMERS + ORDERS + ORDER_ITEMS)
SELECT
	c.customer_state,
	SUM(oi.price) AS revenue
FROM customers c
JOIN orders o
ON c.customer_id = o.customer_id
JOIN order_items oi
ON o.order_id = oi.order_id
GROUP BY c.customer_state
ORDER BY revenue DESC;

-- TOP CUSTOMERS (HIGH VALUE USERS)
SELECT
	c.customer_unique_id,
	SUM(oi.price) AS total_spent
FROM customers c
JOIN orders o 
ON c.customer_id = o.customer_id
JOIN order_items oi
ON o.order_id = oi.order_id
GROUP BY c.customer_unique_id
ORDER BY total_spent DESC;

-- RFM ANALYSIS(CUSTOMER SEGMENTATION)

--build RFM base table
SELECT
	c.customer_unique_id,
	MAX(o.order_purchase_timestamp) AS last_purchase, 
	COUNT(DISTINCT o.order_id) AS frequency,
	SUM(oi.price) AS monetary
FROM customers c
JOIN orders o
ON c.customer_id = o.customer_id
JOIN order_items oi
ON o.order_id = oi.order_id
GROUP BY c.customer_unique_id;

-- Add Recency (days since last order)
SELECT 
    customer_unique_id,
    (SELECT MAX(order_purchase_timestamp)::date FROM orders) 
    - last_purchase::date AS recency_days,
    frequency,
    monetary
FROM (
    SELECT 
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase, 
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    JOIN orders o 
    ON c.customer_id = o.customer_id
    JOIN order_items oi 
    ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
) 
ORDER BY recency_days ASC;

-- Simple Segmentation
SELECT *,
CASE 
	WHEN monetary > 4000 THEN 'High Value'
	WHEN monetary BETWEEN 1500 AND 4000 THEN 'Medium Value'
	ELSE 'Low Value'
END AS customer_segment
FROM (
	SELECT 
		c.customer_unique_id,
		COUNT(o.order_id) AS frequency,
		SUM(oi.price) AS monetary
	FROM customers c
	JOIN orders o
	ON c.customer_id = o.customer_id
	JOIN order_items oi
	ON o.order_id = oi.order_id
	GROUP BY c.customer_unique_id
)
ORDER BY monetary DESC;

-- total high value customers
SELECT 
COUNT(*)FILTER(WHERE customer_segment = 'High Value') AS total_high_value_customers
FROM (SELECT *,
CASE 
	WHEN monetary > 4000 THEN 'High Value'
	WHEN monetary BETWEEN 1500 AND 4000 THEN 'Medium Value'
	ELSE 'Low Value'
END AS customer_segment
FROM (
	SELECT 
		c.customer_unique_id,
		COUNT(o.order_id) AS frequency,
		SUM(oi.price) AS monetary
	FROM customers c
	JOIN orders o
	ON c.customer_id = o.customer_id
	JOIN order_items oi
	ON o.order_id = oi.order_id
	GROUP BY c.customer_unique_id
));

-- Total medium value customers
SELECT 
COUNT(*)FILTER(WHERE customer_segment = 'Medium Value') AS total_medium_value_customers
FROM (SELECT *,
CASE 
	WHEN monetary > 4000 THEN 'High Value'
	WHEN monetary BETWEEN 1500 AND 4000 THEN 'Medium Value'
	ELSE 'Low Value'
END AS customer_segment
FROM (
	SELECT 
		c.customer_unique_id,
		COUNT(o.order_id) AS frequency,
		SUM(oi.price) AS monetary
	FROM customers c
	JOIN orders o
	ON c.customer_id = o.customer_id
	JOIN order_items oi
	ON o.order_id = oi.order_id
	GROUP BY c.customer_unique_id
));

-- Total low value customers
SELECT 
COUNT(*)FILTER(WHERE customer_segment = 'Low Value') AS total_low_value_customers
FROM (SELECT *,
CASE 
	WHEN monetary > 4000 THEN 'High Value'
	WHEN monetary BETWEEN 1500 AND 4000 THEN 'Medium Value'
	ELSE 'Low Value'
END AS customer_segment
FROM (
	SELECT 
		c.customer_unique_id,
		COUNT(o.order_id) AS frequency,
		SUM(oi.price) AS monetary
	FROM customers c
	JOIN orders o
	ON c.customer_id = o.customer_id
	JOIN order_items oi
	ON o.order_id = oi.order_id
	GROUP BY c.customer_unique_id
));

-- TOTAL CUSTOMERS WHO NEVER ORDERED
SELECT COUNT(*) 
FROM customers c
LEFT JOIN orders o 
ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;

-- verifying if there is any customers who didnt purchase is same then every customer placed atleast 1 order
SELECT COUNT(DISTINCT customer_id) FROM customers;
SELECT COUNT(DISTINCT customer_id) FROM orders;

-- RISK ANALYSIS
-- CUSTOMER risk segmentation (extending rfm)
SELECT 
    customer_unique_id,
    frequency,
    monetary,
    -- recency
    (SELECT MAX(order_purchase_timestamp)::date FROM orders) 
    - last_purchase::date AS recency_days,
    -- risk
    CASE 
        WHEN (SELECT MAX(order_purchase_timestamp)::date FROM orders) 
             - last_purchase::date > 180 THEN 'High Risk'
        WHEN (SELECT MAX(order_purchase_timestamp)::date FROM orders) 
         	- last_purchase::date <= 180 
         	AND frequency <= 2 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_segment
FROM (
    -- your base query
    SELECT 
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    JOIN orders o 
    ON c.customer_id = o.customer_id
    JOIN order_items oi 
    ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
);

-- COUNT customers in each risk group
SELECT 
    risk_segment,
    COUNT(*) 
FROM (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary,
        --Recency
        (SELECT MAX(order_purchase_timestamp)::date FROM orders) 
        - MAX(o.order_purchase_timestamp)::date AS recency_days,
        --Risk segmentation
        CASE 
            WHEN (SELECT MAX(order_purchase_timestamp)::date FROM orders) 
                 - MAX(o.order_purchase_timestamp)::date > 180 
                THEN 'High Risk'
            WHEN (SELECT MAX(order_purchase_timestamp)::date FROM orders) 
         		- MAX(o.order_purchase_timestamp)::date <= 180 
         		AND COUNT(DISTINCT o.order_id) <= 2 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END AS risk_segment
    FROM customers c
    JOIN orders o 
    ON c.customer_id = o.customer_id
    JOIN order_items oi 
    ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
) 
GROUP BY risk_segment;

-- only loyal customers
SELECT *
FROM (SELECT 
    c.customer_unique_id,
	COUNT(DISTINCT o.order_id) AS frequency,
	SUM(oi.price) AS monetary,
	 -- Recency
    (SELECT MAX(order_purchase_timestamp)::date FROM orders) 
    - MAX(o.order_purchase_timestamp)::date AS recency_days,
	-- Risk Segmentation (simple logic)
    CASE 
       WHEN (SELECT MAX(order_purchase_timestamp)::date FROM orders) 
            - MAX(o.order_purchase_timestamp)::date > 180 
            THEN 'High Risk'
        WHEN (SELECT MAX(order_purchase_timestamp)::date FROM orders) 
         	- MAX(o.order_purchase_timestamp)::date <= 180 
         	AND COUNT(DISTINCT o.order_id) <= 2 THEN 'Medium Risk'
        ELSE 'Low Risk (loyal)'
    END AS risk_segment
FROM customers c
JOIN orders o 
ON c.customer_id = o.customer_id
JOIN order_items oi 
ON o.order_id = oi.order_id
GROUP BY c.customer_unique_id
) 
WHERE risk_segment = 'Low Risk (loyal)';

-- we are changing dates as dataset is too old , now we will use last dataset date - last purchase date (this is the latest datatset date)
SELECT 
    MAX(TO_TIMESTAMP(order_purchase_timestamp, 'YYYY-MM-DD HH24:MI:SS')) AS max_date
FROM orders;

