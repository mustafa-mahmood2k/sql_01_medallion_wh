/*
==========================================
Quality Checks on Bronze Layer Source Data
==========================================
Purpose:
	Running a series of checks against the bronze layer CRM and ERP tables to identify data quality issues
	that need to be resolved before the data can be transformed and loaded into the silver layer.

	Checks include:
		- Nulls or duplicates in the primary key - there should be none.
		- Unwanted spaces - we want zero entries for name != TRIM(name).
		- Consistency of values in low cardinality columns (columns containing a small number of unique values, e.g., gender or country or boolean).
		- Data standardisation & consistency (e.g., ensuring 'F' becomes 'Female', and ensuring non capital letter entries are captured).

Steps taken:
	1. crm_cust_info: checking the primary key for nulls/duplicates, checking first/last names for unwanted spaces, and reviewing the distinct values of the low cardinality gender and marital status columns.
	2. crm_prd_info: checking the primary key for nulls/duplicates, checking for negative/null product costs, reviewing distinct product line codes, and identifying invalid date ranges (end date earlier than start date).
	   Testing a solution using the LEAD window function to reconstruct correct end dates from overlapping date ranges.
	3. crm_sales_details: checking order dates (stored as integers) for invalid values, checking that order date always precedes ship/due date, and checking that sales = quantity * price.
	4. erp_cust_az12: checking key formatting against the matching crm key, checking birth dates for invalid/future values, and reviewing distinct gender values.
	   Investigating and resolving a hidden character issue that was breaking standardisation logic on the gender column (see Challenges -> Solutions).
	5. erp_loc_a101: checking key formatting against the matching crm key, and building standardisation logic to map country codes/variants to full country names.
	6. erp_px_cat_g1v2: checking category, subcategory, and maintenance columns for unwanted spaces, and building standardisation logic to resolve duplicate 'Yes' entries in the maintenance column.

Challenges -> Solutions:
	1. 	SELECT
			gen
			FROM bronze.erp_cust_az12
			WHERE gen = 'Male';
		This was not returning anything, even with TRIM(gen), so I could not apply CASE WHEN as it would not work properly.
	-> TRIM wasn't working because it only works on regular space characters (e.g., spacebar, or tab) but doesn't work on things such as new line \n or carriage return \r.
	   Baraa did not encounter this problem because he is using windows - so my mac seemed to have kept the \r which would have been auto dealt with in windows.
	   So the solution is simply to replace the \r character with an empty character.
*/

---------------
--CRM SOURCES--
---------------

-- 1
	SELECT
	cst_id,
	COUNT(*) AS count -- there should be a count = 1 for every primary key
	FROM bronze.crm_cust_info
	GROUP BY cst_id
	HAVING COUNT(*) > 1 OR cst_id IS NULL; -- using COUNT(cst_id) won't return any rows where cst_id == NULL because it only counts rows with values
	-- NOTE! if there was only a single NULL value, the count would not be > 1 and so wouldn't show, hence we need to add an extra condition to account for it
	
	SELECT 
		cst_firstname,
		cst_lastname
	FROM bronze.crm_cust_info
	WHERE cst_firstname != TRIM(cst_firstname) OR cst_lastname != TRIM(cst_lastname);
	
	-- low cardinality columns
	SELECT DISTINCT 
	cst_gndr
	FROM bronze.crm_cust_info;
	
	SELECT DISTINCT 
	cst_marital_status
	FROM bronze.crm_cust_info;
	
-- 2
	SELECT
	prd_id,
	COUNT(*)
	FROM bronze.crm_prd_info
	GROUP BY prd_id
	HAVING COUNT(*) > 1 OR prd_id is NULL;

    SELECT prd_cost
    FROM bronze.crm_prd_info
    WHERE prd_cost < 0 or prd_cost IS NULL; -- there are two nulls
    
    SELECT DISTINCT prd_line -- we want these abbreviations as full words (ask company experts about this)
    FROM bronze.crm_prd_info;
    
    -- checking invalid date orders
    SELECT *
    FROM bronze.crm_prd_info
    WHERE prd_end_dt < prd_start_dt; -- end date earlier than start date = illogical
    -- cannot simply switch the start and end dates as there are cases with date overlappings (which doesn't work when you consider different prices within those dates)
    -- instead, delete all end dates for these rows, then use the start date from the second earliest entry as the end date for the earlier entry, and so on...
    -- the lastest entry end date can be NULL (since that price is still active)
    -- SOLUTION TESTING BELOW
    
    SELECT 
    prd_id,
    prd_key,
    prd_nm,
    prd_start_dt,
    prd_end_dt,
    -- the following logic works! // -1 ensures the end date is one day before the following start date
    LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt ASC) - 1 AS new_prd_end_dt  -- lets you access values from the next row within a window
    FROM bronze.crm_prd_info
    WHERE prd_key IN ('AC-HE-HL-U509-R', 'AC-HE-HL-U509')
   -- WHERE REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') NOT IN (SELECT distinct id from bronze.erp_px_cat_g1v2) / check products not in cat table
   -- WHERE SUBSTRING(prd_key, 7, LEN(prd_key)) NOT IN (SELECT sls_prd_key FROM bronze.crm_sales_details) / products that don't have any orders
    
-- 3
    SELECT
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	sls_order_dt,
	sls_ship_dt, -- the dates are recorded as integers e.g., 20101229
	sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price
	FROM bronze.crm_sales_details;
	-- WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info)
	-- WHERE sls_cust_id NOT IN (SELECT prd_key FROM silver.crm_cust_info) / nothing returned so all good
	
	SELECT 
	sls_order_dt
	FROM bronze.crm_sales_details
	WHERE sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 -- we get a bunch of 0's, and there are shorter integers that don't represent dates
	OR sls_order_dt  > 20260901 OR sls_order_dt < 20000303; -- no outliers
	
	SELECT 	
	*
	FROM bronze.crm_sales_details
	WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt; -- no cleanup needed
	
	SELECT
	sls_sales,
	sls_quantity,
	sls_price
	FROM bronze.crm_sales_details
	WHERE sls_sales != sls_quantity * sls_price 
	OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
	OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0;
	
---------------
--ERP SOURCES--
---------------
	-- 1
	SELECT
	cid,
	bdate,
	gen
	FROM bronze.erp_cust_az12;
	
	SELECT DISTINCT
	SUBSTRING(cid, 1, 3)
	FROM bronze.erp_cust_az12
	WHERE LEN(cid) = 13;
	
	SELECT
	cid,
	CASE 
		WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
		ELSE cid
	END cid
	FROM bronze.erp_cust_az12
	WHERE CASE 
		WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
		ELSE cid
	END NOT IN (SELECT DISTINCT cst_key FROM silver.crm_cust_info); -- checking if data matches
	
	SELECT DISTINCT bdate
	FROM bronze.erp_cust_az12
	WHERE bdate < '1924-01-01' OR bdate > GETDATE(); -- lots of invalid dates (ones in the future)
	
SELECT DISTINCT 
    gen,
    LEN(gen) AS len
FROM bronze.erp_cust_az12; -- We can see the length of each value is at least one character more than its true value, so we need to next figure out what the extra problematic character is


SELECT DISTINCT
    gen,
    LEN(gen) AS len,
    UNICODE(SUBSTRING(gen, LEN(gen), 1)) AS last_char_unicode -- using unicode to check what the problematic character was  (13 = \r)
FROM bronze.erp_cust_az12
WHERE gen IS NOT NULL;

SELECT DISTINCT 
    gen AS gen_raw,
    CASE
        WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), ''))) IN ('F', 'FEMALE') THEN 'Female' -- char(13) represents a carriage return (= \r) which is similar to a new line (= \n)
        WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), ''))) IN ('M', 'MALE') THEN 'Male' -- this extra chracter is the reason TRIM wasn't working, because TRIM only works for regular space characters
        ELSE 'n/a'
    END AS gen_clean
FROM bronze.erp_cust_az12;

-- 2 

SELECT 
cid, -- We need to get rid of the '-' from the key
cntry
FROM bronze.erp_loc_a101;

SELECT
REPLACE(cid, '-', '') cid
FROM bronze.erp_loc_a101 WHERE REPLACE(cid, '-', '') NOT IN
(SELECT cst_key FROM silver.crm_cust_info); -- no unmatching data after transformation

SELECT DISTINCT 
cntry
FROM bronze.erp_loc_a101
ORDER BY cntry;

SELECT DISTINCT -- encountered same problematic \r character as erp_cust table
cntry,
CASE
	WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('Australia') THEN 'Australia'
	WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('Canada') THEN 'Canada'
	WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('France') THEN 'France'
	WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('DE', 'Germany') THEN 'Germany'
	WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('United Kindgom') THEN 'United Kingdom'
	WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('US', 'USA', 'United States') THEN 'United States'
	ELSE 'n/a'
END cntry
FROM bronze.erp_loc_a101;

-- 3
SELECT 
id, -- exactly matches 'prd_id' in crm_prd_info
cat,
subcat,
maintenance 
FROM bronze.erp_px_cat_g1v2;

SELECT
*
FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance); -- no unwanted spaces

SELECT DISTINCT
cat
FROM bronze.erp_px_cat_g1v2;

SELECT DISTINCT
subcat
FROM bronze.erp_px_cat_g1v2;

SELECT DISTINCT
maintenance
FROM bronze.erp_px_cat_g1v2; -- we have two distinct 'Yes'

SELECT DISTINCT
CASE WHEN UPPER(TRIM(REPLACE(maintenance, CHAR(13), ''))) = 'Yes' THEN 'Yes'
ELSE maintenance
END maintenance
FROM bronze.erp_px_cat_g1v2;