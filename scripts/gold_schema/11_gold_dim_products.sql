/*
=============================================
Creating the gold.dim_products Dimension View
=============================================
Purpose:
	Building the gold layer product dimension by combining silver.crm_prd_info with its matching category data from silver.erp_px_cat_g1v2.

	As per this project's requirements, this dimension should only contain current (active) products, not historical ones -
	so historical records are filtered out before the view is created.

	As with gold.dim_customers, a surrogate key (product_key) is generated using ROW_NUMBER, rather than relying on the source system's key.

Steps taken:
	1. Reviewing the full silver.crm_prd_info and silver.erp_px_cat_g1v2 tables to understand the data available for the dimension.
	2. Filtering out historical data, keeping only current records - identified as those where prd_end_dt is NULL.
	3. Checking the uniqueness of prd_key after the filter (since it will be used to join with sales data), and confirming no duplicates
	   remain once historical records for a given prd_key are excluded.
	4. Creating the gold.dim_products view: joining crm_prd_info to erp_px_cat_g1v2 on cat_id, renaming columns to user-friendly names,
	   applying the current-records-only filter, and generating a surrogate key (product_key) using ROW_NUMBER, ordered by start date then product key.
*/

-- 1
SELECT
*
FROM silver.crm_prd_info;

SELECT
*
FROM silver.erp_px_cat_g1v2;

-- 2
-- Filtering out historical data, keeping only current data as per this projects requirements
-- current data if prd_end_dt is null
SELECT
*
FROM silver.crm_prd_info
WHERE prd_end_dt IS NULL;

-- 3
-- Checking the uniqueness of the prd_key (since we will use it to join with sales data)
-- There are no duplicates; the multiple entries for a single prd_key are removed since we filter out NULL end_dt (which removes historical records, aka duplicates, for a given prd_key)
SELECT
prd_key,
COUNT(*) FROM (
SELECT
pi.prd_key
FROM silver.crm_prd_info AS pi
LEFT JOIN silver.erp_px_cat_g1v2 AS pc
ON 		  pi.cat_id = pc.id
WHERE prd_end_dt IS NULL
)t GROUP BY prd_key
HAVING COUNT(*) > 1;

-- 4
-- Creating the dimension
CREATE VIEW gold.dim_products AS
SELECT
ROW_NUMBER() OVER(ORDER BY pi.prd_start_dt, pi.prd_key) AS product_key,
pi.prd_id AS product_id,
pi.prd_key AS product_number,
pi.prd_nm AS product_name,
pi.cat_id AS category_id,
pc.cat AS category,
pc.subcat AS subcategory,
pc.maintenance,
pi.prd_cost AS product_cost,
pi.prd_line AS product_line,
pi.prd_start_dt AS start_date,
pi.prd_end_dt AS end_date
FROM silver.crm_prd_info AS pi
LEFT JOIN silver.erp_px_cat_g1v2 AS pc
ON 		  pi.cat_id = pc.id
WHERE prd_end_dt IS NULL;