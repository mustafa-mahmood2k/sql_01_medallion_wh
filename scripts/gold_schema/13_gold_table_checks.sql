/*
===================================
Quality Checks on Gold Layer Tables
===================================
Purpose:
	Running final data quality checks on the gold layer dimension and fact views, to confirm they are
	ready for reporting - reviewing each table's data, and verifying that every row in the fact table
	can successfully join back to both dimension tables (i.e., no orphaned foreign keys).

Steps taken:
	1. Reviewing the full gold.dim_customers table, and the distinct gender values, to confirm the dimension looks correct.
	2. Reviewing the full gold.dim_products table.
	3. Reviewing the full gold.fact_sales table.
	4. Left joining fact_sales to both dimension tables together, to check that rows can match against both at once.
	5. Left joining fact_sales to each dimension separately, checking for any rows where the join produces a NULL
	   (i.e., a fact row whose key doesn't exist in that dimension).

Note:
	The combined three-way join (step 4) did not execute as expected - flagged for further investigation.
	Splitting the check into two separate joins (step 5) was used as a workaround to isolate and confirm
	each dimension's join integrity individually.
*/

-- GOLD TABLE QUALITY CHECKS --

-- DIMENSION TABLES --

-- 1
-- Customers
SELECT
*
FROM gold.dim_customers;

SELECT DISTINCT
gender
FROM gold.dim_customers;

-- 2
-- Products
SELECT 
*
FROM gold.dim_products;

-- FACT TABLE -- 

-- 3
-- Sales
SELECT 
*
FROM gold.fact_sales;

-- 4
-- Fact table check by checking if all dimension tables can join to the fact table
SELECT
*
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key;

-- 5
SELECT
*
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
WHERE c.customer_key IS NULL;


SELECT
*
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
WHERE p.product_key IS NULL;