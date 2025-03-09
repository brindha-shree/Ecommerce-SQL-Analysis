CREATE DATABASE ecommerce;
USE ecommerce;

CREATE TABLE customers(
customer_id INT PRIMARY KEY,
customer_name VARCHAR(255),
email VARCHAR(255),
location VARCHAR(100))

#2.product table
CREATE TABLE products(
product_id INT PRIMARY KEY,
product_name VARCHAR(255),
category VARCHAR(100),
price DECIMAL(10,2));

#3.order table
CREATE TABLE orders(
order_id  INT PRIMARY KEY,
customer_id INT,
order_date  DATE,
order_status VARCHAR(50),
fOREIGN KEY(customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE);

#4.order_details
CREATE TABLE order_details(
order_detail_id  INT PRIMARY KEY,
order_id INT,
product_id INT,
quantity INT,
FOREIGN KEY(order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
FOREIGN KEY(product_id) REFERENCES products(product_id) ON DELETE CASCADE);

#payments 
CREATE TABLE payments(
payment_id INT PRIMARY KEY,
order_id INT,
payment_type VARCHAR(100),
amount DECIMAL(10,2),
FOREIGN KEY(order_id) REFERENCES orders(order_id)  ON DELETE CASCADE);


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers.csv' 
IGNORE INTO TABLE customers 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n' 
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/products.csv' 
INTO TABLE products 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n' 
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/orders.csv' 
IGNORE INTO TABLE orders 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n' 
IGNORE 1 ROWS;


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/order_details.csv' 
INTO TABLE order_details 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n' 
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/payments.csv' 
INTO TABLE payments 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n' 
IGNORE 1 ROWS;

SELECT * FROM customers LIMIT 10;
SELECT * FROM products LIMIT 10;
SELECT * FROM orders LIMIT 10;
SELECT * FROM order_details LIMIT 10;
SELECT * FROM payments LIMIT 10;

SELECT * FROM customers WHERE customer_name IS NULL OR email IS NULL;
SELECT * FROM products WHERE product_name IS NULL OR price IS NULL;
SELECT * FROM orders WHERE order_date IS NULL OR customer_id IS NULL;
SELECT * FROM order_details WHERE quantity IS NULL OR price IS NULL;
SELECT * FROM payments WHERE payment_status IS NULL;

UPDATE customers SET email = 'unknown@example.com' WHERE email IS NULL;
UPDATE products SET price = 0 WHERE price IS NULL;
UPDATE orders SET order_status = 'Pending' WHERE order_status IS NULL;
UPDATE order_details SET quantity = 1 WHERE quantity IS NULL;

DELETE FROM customers WHERE customer_name IS NULL AND email IS NULL;
DELETE FROM products WHERE price IS NULL;
DELETE FROM orders WHERE order_date IS NULL;
DELETE FROM order_details WHERE quantity IS NULL;
DELETE FROM payments WHERE amount IS NULL;


-- Find duplicate customers
SELECT customer_id, COUNT(*) 
FROM customers 
GROUP BY customer_id 
HAVING COUNT(*) > 1;

-- Find duplicate products
SELECT product_id, COUNT(*) 
FROM products 
GROUP BY product_id 
HAVING COUNT(*) > 1;

-- Find duplicate orders
SELECT order_id, COUNT(*) 
FROM orders 
GROUP BY order_id 
HAVING COUNT(*) > 1;

-- Find duplicate order details
SELECT order_detail_id, COUNT(*) 
FROM order_details 
GROUP BY order_detail_id 
HAVING COUNT(*) > 1;

-- Find duplicate payments
SELECT payment_id, COUNT(*) 
FROM payments 
GROUP BY payment_id 
HAVING COUNT(*) > 1;

WITH Percentiles AS (
    SELECT 
        price,
        NTILE(4) OVER (ORDER BY price) AS quartile
    FROM products
)
SELECT 
    MIN(CASE WHEN quartile = 1 THEN price END) AS Q1,
    MIN(CASE WHEN quartile = 3 THEN price END) AS Q3
FROM Percentiles;


WITH Percentiles AS (
    SELECT 
        price,
        NTILE(4) OVER (ORDER BY price) AS quartile
    FROM products
),
IQR_Calculations AS (
    SELECT 
        MIN(CASE WHEN quartile = 1 THEN price END) AS Q1,
        MIN(CASE WHEN quartile = 3 THEN price END) AS Q3
    FROM Percentiles
)
SELECT p.* FROM products p
JOIN IQR_Calculations iq
ON p.price < (iq.Q1 - 1.5 * (iq.Q3 - iq.Q1)) 
OR p.price > (iq.Q3 + 1.5 * (iq.Q3 - iq.Q1));



WITH ranked AS (
    SELECT price, 
           ROW_NUMBER() OVER (ORDER BY price) AS row_num,
           COUNT(*) OVER () AS total_rows
    FROM products
)
SELECT price
FROM ranked
WHERE row_num = FLOOR(total_rows * 0.25); 


#2
WITH ranked AS (
    SELECT price, 
           ROW_NUMBER() OVER (ORDER BY price) AS row_num,
           COUNT(*) OVER () AS total_rows
    FROM products
)
SELECT price
FROM ranked
WHERE row_num = FLOOR(total_rows * 0.75);


WITH ranked AS (
    SELECT price, 
           ROW_NUMBER() OVER (ORDER BY price) AS row_num,
           COUNT(*) OVER () AS total_rows
    FROM products
),
percentiles AS (
    SELECT 
        (SELECT price FROM ranked WHERE row_num = FLOOR(total_rows * 0.25)) AS Q1,
        (SELECT price FROM ranked WHERE row_num = FLOOR(total_rows * 0.75)) AS Q3
)
SELECT Q1, Q3, (Q3 - Q1) AS IQR FROM percentiles;


WITH ranked AS (
    SELECT price, 
           ROW_NUMBER() OVER (ORDER BY price) AS row_num,
           COUNT(*) OVER () AS total_rows
    FROM products
),
percentiles AS (
    SELECT 
        (SELECT price FROM ranked WHERE row_num = FLOOR(total_rows * 0.25)) AS Q1,
        (SELECT price FROM ranked WHERE row_num = FLOOR(total_rows * 0.75)) AS Q3
)
SELECT * FROM products 
WHERE price < (SELECT Q1 - 1.5 * (Q3 - Q1) FROM percentiles)
   OR price > (SELECT Q3 + 1.5 * (Q3 - Q1) FROM percentiles);
   
   
   WITH ranked AS (
    SELECT price, 
           ROW_NUMBER() OVER (ORDER BY price) AS row_num,
           COUNT(*) OVER () AS total_rows
    FROM products
),
percentiles AS (
    SELECT 
        (SELECT price FROM ranked WHERE row_num = FLOOR(total_rows * 0.25)) AS Q1,
        (SELECT price FROM ranked WHERE row_num = FLOOR(total_rows * 0.75)) AS Q3
),
median AS (
    SELECT price FROM ranked WHERE row_num = FLOOR(total_rows / 2)
)
UPDATE products
SET price = (SELECT price FROM median)
WHERE price < (SELECT Q1 - 1.5 * (Q3 - Q1) FROM percentiles)
   OR price > (SELECT Q3 + 1.5 * (Q3 - Q1) FROM percentiles);
   



WITH ranked AS (
    SELECT quantity, 
           ROW_NUMBER() OVER (ORDER BY quantity) AS row_num,
           COUNT(*) OVER () AS total_rows
    FROM order_details
),
percentiles AS (
    SELECT 
        (SELECT quantity FROM ranked WHERE row_num = FLOOR(total_rows * 0.25)) AS Q1,
        (SELECT quantity FROM ranked WHERE row_num = FLOOR(total_rows * 0.75)) AS Q3
)
SELECT * FROM order_details
WHERE quantity < (SELECT Q1 - 1.5 * (Q3 - Q1) FROM percentiles)
   OR quantity > (SELECT Q3 + 1.5 * (Q3 - Q1) FROM percentiles);
   
   
WITH ranked AS (
    SELECT quantity, 
           ROW_NUMBER() OVER (ORDER BY quantity) AS row_num,
           COUNT(*) OVER () AS total_rows
    FROM order_details
),
percentiles AS (
    SELECT 
        (SELECT quantity FROM ranked WHERE row_num = FLOOR(total_rows * 0.25)) AS Q1,
        (SELECT quantity FROM ranked WHERE row_num = FLOOR(total_rows * 0.75)) AS Q3
),
median AS (
    SELECT quantity FROM ranked WHERE row_num = FLOOR(total_rows / 2)
)
UPDATE order_details
SET quantity = (SELECT quantity FROM median)
WHERE quantity < (SELECT Q1 - 1.5 * (Q3 - Q1) FROM percentiles)
   OR quantity > (SELECT Q3 + 1.5 * (Q3 - Q1) FROM percentiles);



WITH ranked AS (
    SELECT amount, 
           ROW_NUMBER() OVER (ORDER BY amount) AS row_num,
           COUNT(*) OVER () AS total_rows
    FROM payments
),
percentiles AS (
    SELECT 
        (SELECT amount FROM ranked WHERE row_num = FLOOR(total_rows * 0.25)) AS Q1,
        (SELECT amount FROM ranked WHERE row_num = FLOOR(total_rows * 0.75)) AS Q3
)
SELECT * FROM payments
WHERE amount < (SELECT Q1 - 1.5 * (Q3 - Q1) FROM percentiles)
   OR amount > (SELECT Q3 + 1.5 * (Q3 - Q1) FROM percentiles);
   
   
   
   WITH ranked AS (
    SELECT amount, 
           ROW_NUMBER() OVER (ORDER BY amount) AS row_num,
           COUNT(*) OVER () AS total_rows
    FROM payments
),
percentiles AS (
    SELECT 
        (SELECT amount FROM ranked WHERE row_num = FLOOR(total_rows * 0.25)) AS Q1,
        (SELECT amount FROM ranked WHERE row_num = FLOOR(total_rows * 0.75)) AS Q3
),
median AS (
    SELECT amount FROM ranked WHERE row_num = FLOOR(total_rows / 2)
)
UPDATE payments
SET amount = (SELECT amount FROM median)
WHERE amount < (SELECT Q1 - 1.5 * (Q3 - Q1) FROM percentiles)
   OR amount > (SELECT Q3 + 1.5 * (Q3 - Q1) FROM percentiles);
   
   
   
   #analysis
   
# Top 10 Customers by Number of Orders
   SELECT c.customer_id, c.customer_name, COUNT(o.order_id) AS total_orders
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY total_orders DESC
LIMIT 10;


#Average Customer Spending
SELECT c.customer_id, c.customer_name, ROUND(AVG(p.amount), 2) AS avg_spending
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN payments p ON o.order_id = p.order_id
GROUP BY c.customer_id, c.customer_name
ORDER BY avg_spending DESC
LIMIT 10;

#4Product Performance Analysis
#4Best-Selling Products

SELECT p.product_name, SUM(od.quantity) AS total_sold
FROM products p
JOIN order_details od ON p.product_id = od.product_id
GROUP BY p.product_name
ORDER BY total_sold DESC
LIMIT 10;

#Least-Selling Products

SELECT p.product_name, SUM(od.quantity) AS total_sold
FROM products p
JOIN order_details od ON p.product_id = od.product_id
GROUP BY p.product_name
ORDER BY total_sold ASC
LIMIT 10;


#Monthly Order Trends

SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, COUNT(order_id) AS total_orders
FROM orders
GROUP BY month
ORDER BY month;


#Peak Sales Days (Which Weekday Has Highest Sales?)

SELECT DAYNAME(order_date) AS weekday, COUNT(order_id) AS total_orders
FROM orders
GROUP BY weekday
ORDER BY total_orders DESC;


#Total Revenue Over Time

SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, SUM(p.amount) AS total_revenue
FROM orders o
JOIN payments p ON o.order_id = p.order_id
GROUP BY month
ORDER BY month;


# Payment Analysis
# Most Used Payment types


SELECT payment_type, COUNT(payment_id) AS total_payments
FROM payments
GROUP BY payment_type
ORDER BY total_payments DESC;


#Finds the most popular payment methods.

#Average Order Value (AOV)

SELECT ROUND(AVG(amount), 2) AS avg_order_value
FROM payments;

#advanced

CREATE INDEX idx_customer_id ON customers(customer_id);
CREATE INDEX idx_product_id ON products(product_id);
CREATE INDEX idx_order_id ON orders(order_id);
CREATE INDEX idx_payment_id ON payments(payment_id);


WITH LatestOrders AS (  
    SELECT customer_id, order_id, order_date,  
           RANK() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rank_num  
    FROM orders  
)  
SELECT * FROM LatestOrders WHERE rank_num = 1;

EXPLAIN SELECT * FROM orders WHERE order_date > '2024-01-01';




























