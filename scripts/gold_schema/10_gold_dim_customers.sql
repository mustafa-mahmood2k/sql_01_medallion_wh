/*
=====================================================
Creating the gold.dim_customers Dimension View
=====================================================
Purpose:
	Building the gold layer customer dimension by combining the relevant silver layer tables into a single, business-friendly view.

	This is a Dimension table, not a Fact table, so rather than relying on the primary key from a source system, we generate our own
	surrogate key - a system-generated unique identifier assigned to each record, used purely to connect this table within the data model.
	There are multiple ways of generating one (e.g., DDL-based generation, or query-based using a window function, which is the approach used here).

Steps taken:
	1. Starting with silver.crm_cust_info (the table with the most complete customer information, treated as the 'master' table),
	   then left joining silver.erp_cust_az12 and silver.erp_loc_a101 to bring in birth date, gender, and country.
	   Checking for duplicate customer records after the joins, using a GROUP BY / HAVING COUNT(*) > 1 check.
	2. Identifying that gender information exists across two source columns (cst_gndr from crm, and gen from erp), and resolving the conflict
	   through data integration - prioritising the crm value (the master source) and falling back to the erp value via COALESCE where the crm value is not available.
	3. Creating the gold.dim_customers view: renaming columns to user-friendly names, applying the resolved gender logic, and generating
	   a surrogate key (customer_key) using ROW_NUMBER, ordered by cst_id.
*/

USE first_medallion_wh;

-- 1
-- Starting with the master table (most information), then left joining the other relevant tables to build the final dimension table
-- Conduct a duplicate check using GROUP BY
SELECT
cst_id,
COUNT(*) FROM (
	SELECT
	ci.cst_id,
	ci.cst_key,
	ci.cst_firstname,
	ci.cst_lastname,
	ci.cst_marital_status,
	ci.cst_gndr,
	ci.cst_create_date,
	ca.bdate,
	ca.gen,
	la.cntry
	FROM silver.crm_cust_info AS ci
	LEFT JOIN silver.erp_cust_az12 ca
	ON 		  ci.cst_key = ca.cid
	LEFT JOIN silver.erp_loc_a101 la
	ON 		  ci.cst_key = la.cid
)t GROUP BY cst_id
   HAVING COUNT(*) > 1; -- no duplicates

-- 2
   -- From the table, we can see two sources for gender information: cst_gndr and gen
   -- We fix using data integration
SELECT DISTINCT
   	ci.cst_gndr,
   	ca.gen,
	CASE
		WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
		ELSE COALESCE(ca.gen, 'n/a') -- returns the first non-NULL value listed as an arguement (i.e., if ca.gen is null, then it skips the first arg and uses 'n/a'
	END gndr
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 ca
ON 		  ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON 		  ci.cst_key = la.cid
ORDER BY 1, 2 -- ordering by first column then second column
-- the NULL that appears in the gen column appears after the JOIN because there are customers in the crm table that aren't in the erp table
-- there are also mis-matches, in which case we prioritise the crm data (crm is the Master)

-- 3
-- Creating user-friendly names for the gold columns
-- The following table is a Dimension, not a Fact
-- We can select the primary key for this table, instead of relying on the ones from the source system
-- We call this a surrogate key = system-generated unique identifier assigned to each record in a table / just used to connect data model
-- There are mutiple ways of generating one, e.g.: ddl-based generation or query based using window function (which we will use)
--Then we finally can create the object (= the gold level dimension table for customers)
CREATE VIEW gold.dim_customers AS
SELECT
	ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,
	ci.cst_id AS customer_id,
	ci.cst_key AS customer_number,
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name,
	la.cntry AS country,
	CASE
		WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
		ELSE COALESCE(ca.gen, 'n/a') -- returns the first non-NULL value listed as an arguement (i.e., if ca.gen is null, then it skips the first arg and uses 'n/a'
	END gender,
	ci.cst_marital_status AS marital_status,
	ca.bdate AS birth_date,
	ci.cst_create_date AS create_date
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 ca
ON 		  ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON 		  ci.cst_key = la.cid