/*
=================================================
Quality Checks on Silver Layer Data
=================================================
Purpose:
	Running the same checks performed on the bronze data against the newly transformed silver data,
	to confirm the initial transformations resolved the issues found earlier, and to identify whether any further transformations are needed.

Steps taken:
	1. crm_cust_info: re-checking the primary key for nulls/duplicates, and confirming first/last names no longer contain unwanted spaces.
	2. crm_prd_info: reviewing the distinct product line values to confirm standardisation, re-checking for invalid date ranges, and reviewing the full table.
	3. crm_sales_details: re-checking that order date always precedes ship/due date, confirming sales = quantity * price is now consistent, and reviewing the full table.
	4. erp_cust_az12: confirming no future birth dates remain, reviewing the distinct gender values, and reviewing the full table.
	5. erp_loc_a101: reviewing the full table to confirm standardisation.
	6. erp_px_cat_g1v2: reviewing the full table to confirm standardisation.
*/

-- crm sources --
	-- 1
	SELECT
	cst_id,
	COUNT(*) AS count -- there should be a count = 1 for every primary key
	FROM silver.crm_cust_info
	GROUP BY cst_id
	HAVING COUNT(*) > 1 OR cst_id IS NULL; -- using COUNT(cst_id) won't return any rows where cst_id == NULL because it only counts rows with values
	-- NOTE! if there was only a single NULL value, the count would not be > 1 and so wouldn't show, hence we need to add an extra condition to account for it

	SELECT
		cst_firstname,
		cst_lastname
	FROM silver.crm_cust_info
	WHERE cst_firstname != TRIM(cst_firstname) OR cst_lastname != TRIM(cst_lastname);

	-- 2
	SELECT DISTINCT prd_line
	FROM silver.crm_prd_info

	SELECT *
	FROM silver.crm_prd_info
	WHERE prd_end_dt < prd_start_dt

	SELECT *
	FROM silver.crm_prd_info

	-- 3
	SELECT *
	FROM silver.crm_sales_details
	WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

	SELECT
	sls_sales,
	sls_quantity,
	sls_price
	FROM silver.crm_sales_details
	WHERE sls_sales != sls_quantity * sls_price
	OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
	OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0;

	SELECT * FROM silver.crm_sales_details

-- erp sources --

	-- 4
	SELECT DISTINCT bdate
	FROM silver.erp_cust_az12
	WHERE bdate > GETDATE();

	SELECT DISTINCT
	gen
	FROM silver.erp_cust_az12;

	SELECT *
	FROM silver.erp_cust_az12;

	-- 5
	SELECT *
	FROM silver.erp_loc_a101

	-- 6
	SELECT *
	FROM silver.erp_px_cat_g1v2