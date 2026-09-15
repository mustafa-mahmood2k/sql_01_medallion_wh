/*
======================================
Creating the gold.fact_sales Fact View
======================================
Purpose:
	Building the gold layer sales fact table by combining silver.crm_sales_details with the gold.dim_products and gold.dim_customers dimensions.

	Since this table contains transactions (keys, dates, measures), it is a Fact table, not a Dimension.
	We want to use the surrogate keys from our dimension tables to connect this Fact to those Dimensions, instead of the source system's primary keys -
	so sls_prd_key and sls_cust_id are replaced with product_key and customer_key respectively.
	These are referred to as foreign keys in the schema data model diagram.

Steps taken:
	1. Joining silver.crm_sales_details to gold.dim_products (on sls_prd_key = product_number) to retrieve the product surrogate key.
	2. Joining to gold.dim_customers (on sls_cust_id = customer_id) to retrieve the customer surrogate key.
	3. Creating the gold.fact_sales view, renaming columns to user-friendly names, and using the retrieved surrogate keys as foreign keys back to the dimension tables.
*/

CREATE VIEW gold.fact_sales AS
SELECT
sd.sls_ord_num AS order_number,
-- 1
dp.product_key, -- sd.sls_prd_key
-- 2
dc.customer_key, -- sd.sls_cust_id,
sd.sls_order_dt AS order_date,
sd.sls_ship_dt AS shipping_date,
sd.sls_due_dt AS due_date,
sd.sls_sales AS sales_amount,
sd.sls_quantity AS quantity,
sd.sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products dp
ON sd.sls_prd_key = dp.product_number
LEFT JOIN gold.dim_customers dc
ON sd.sls_cust_id = dc.customer_id;