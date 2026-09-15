/*
===============================================================
Stored Procedure: Loading Cleaned Data into Silver Layer Tables
===============================================================
Purpose:
	Creating a stored procedure to clean and transform the raw bronze layer data before loading it into the corresponding silver layer tables.
	As with the bronze load procedure, TRUNCATE and INSERT is used (full load method), PRINT statements are added for readability, TRY...CATCH is added for error handling,
	and start/end time variables are used at the batch, source, and table level to track ETL duration.

	The following transformations are applied across the tables:
		- Derived columns = creating new columns based on calculations or transformations of existing ones.
		- Handling missing data (e.g., replacing NULLs with 0, or deriving a value from other columns).
		- Data normalisation & standardisation (e.g., mapping abbreviations and inconsistent casing to full, consistent values).
		- Type casting (e.g., converting integer-stored dates into proper DATE values).
		- Data enrichment (adding new, relevant data to enhance the dataset for analysis), e.g., deriving prd_end_dt with LEAD.

	For customers with duplicate entries, we want to keep only the most recent entry (by create_date).
	This is done using the ROW_NUMBER window function, which assigns a unique number to each row based on a defined order,
	allowing us to rank entries and filter down to the top-ranked (i.e., most recent) row per customer.

Steps taken:
	1. Declaring datetime variables to track duration at the batch, source (crm/erp), and table level.
	2. Wrapping the load logic in a TRY block, to be caught by a CATCH block should an error occur.
	3. crm_cust_info: ranking duplicate customer entries by create_date using ROW_NUMBER and keeping only the most recent, trimming whitespace from names, and standardising marital status and gender values.
	4. crm_prd_info: splitting prd_key into its cat_id and prd_key components, defaulting missing product costs to 0, mapping product line codes to full descriptions, casting dates to DATE, and deriving prd_end_dt using LEAD.
	5. crm_sales_details: converting the integer-stored order/ship/due dates into proper DATE values (nulling any invalid ones), and recalculating sales and price where the original values are missing or inconsistent.
	6. erp_cust_az12: stripping the 'NAS' prefix from customer ids, nulling out future birth dates, and standardising gender values.
	7. erp_loc_a101: removing hyphens from customer ids, and standardising country values into a consistent format.
	8. erp_px_cat_g1v2: standardising duplicate 'Yes' entries in the maintenance column.
	9. Printing progress and load duration for each table, each source group (CRM, ERP), and the total batch, as with the bronze load procedure.
	10. In the CATCH block, printing the error message, number, and state should the procedure fail.
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME;
	DECLARE @crm_start_time DATETIME, @crm_end_time DATETIME;
	DECLARE @erp_start_time DATETIME, @erp_end_time DATETIME;
	DECLARE @table_start_time DATETIME, @table_end_time DATETIME;

	SET @batch_start_time = GETDATE();
	BEGIN TRY
		PRINT '=============================================';
		PRINT 'Loading Silver Layer';
		PRINT '=============================================';

		---------------
		--CRM SOURCES--
		---------------
		PRINT '---------------------------------------------';
		PRINT 'Loading CRM Tables'
		PRINT '---------------------------------------------';
		SET @crm_start_time = GETDATE();

		-- 1
		SET @table_start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_cust_info'
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Inserting Data Into: silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info (
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date) 
		SELECT 
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname, -- here we trim the names to get rid of whitespaces
			TRIM(cst_lastname) AS cst_lastname,
			CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single' -- standardising these low cardinal values
				 WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				 ELSE 'n/a' -- dealing with NULL values
			END cst_marital_status,
			CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female' -- using UPPER() just in case entries are in lower case
				 WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				 ELSE 'n/a'
			END cst_gndr,
			cst_create_date
		FROM ( -- creating a subquery
			SELECT
			*,
			ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS recency_rank
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
		)t WHERE recency_rank = 1; -- the t creates an inline view/derived table (temporary table)
		-- by filtering so that recency rank = 1, you automatically exclude duplicates that have chronological create_dates
		SET @table_end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @table_start_time, @table_end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------------------------';

		-- 2
		SET @table_start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_prd_info'
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> Inserting Data Into: silver.crm_prd_info';
		INSERT INTO silver.crm_prd_info (
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt) 
		SELECT 
			prd_id,
			-- The category id from the category table has an underscore between the letters, whereas from the prd_key the cat_id has a hyphen
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id, -- the first 5 characters of the prd_key = category id
			SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key, -- these characters correspond with the sales_prd_key in sales_details table
			prd_nm,
			ISNULL(prd_cost, 0) AS prd_cost, -- turning any null values into 0's // important for later agg calculations
			CASE UPPER(TRIM(prd_line)) -- quick case for simple value mapping (we could've done the same for the cust_info gender/martial status mapping) / can't do with complex conditions
				 WHEN 'M' THEN 'Mountain'
				 WHEN 'R' THEN 'Road'
				 WHEN 'S' THEN 'Other sales'
				 WHEN 'T' THEN 'Touring'
				 ELSE 'n/a'
			END prd_line,
			CAST(prd_start_dt AS DATE) AS prd_start_dt, -- since we don't have time
			CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt
		FROM bronze.crm_prd_info;
		SET @table_end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @table_start_time, @table_end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------------------------';

		-- 3
		SET @table_start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_sales_details'
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> Inserting Data Into: silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details (
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)
		SELECT 
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			CASE 
				WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
			END AS sls_order_dt,
			CASE 
				WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
			END AS sls_ship_dt,
			CASE 
				WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
			END AS sls_due_dt,
			CASE 
				WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) 
					THEN sls_quantity * ABS(sls_price)
				ELSE sls_sales
			END AS sls_sales, -- Recalculate sales if original value is missing or incorrect
			sls_quantity,
			CASE 
				WHEN sls_price IS NULL OR sls_price <= 0 
					THEN sls_sales / NULLIF(sls_quantity, 0)
					ELSE sls_price  -- Derive price if original value is invalid
				END AS sls_price
		FROM bronze.crm_sales_details;
		SET @table_end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @table_start_time, @table_end_time) AS NVARCHAR) + ' seconds';

		SET @crm_end_time = GETDATE();
		PRINT '>> ------------------------------------------';
		PRINT '>> Total CRM Load Duration: ' + CAST(DATEDIFF(second, @crm_start_time, @crm_end_time) AS NVARCHAR) + ' seconds';

		---------------
		--ERP SOURCES--
		---------------
		PRINT '---------------------------------------------';
		PRINT 'Loading ERP Tables'
		PRINT '---------------------------------------------';
		SET @erp_start_time = GETDATE();

		-- 1
		SET @table_start_time = GETDATE();
		PRINT '>> Truncating Table: silver.erp_cust_az12'
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>> Inserting Data Into: silver.erp_cust_az12';
		INSERT INTO silver.erp_cust_az12 (
			cid,
			bdate,
			gen
		)
		SELECT
			CASE 
				WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
				ELSE cid
			END cid,
			CASE 
				WHEN bdate > GETDATE() THEN NULL
				ELSE bdate
			END bdate,
			CASE
				WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), ''))) IN ('F', 'FEMALE') THEN 'Female'
				WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), ''))) IN ('M', 'MALE') THEN 'Male'
				ELSE 'n/a'
			END gen
		FROM bronze.erp_cust_az12;
		SET @table_end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @table_start_time, @table_end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------------------------';

		-- 2
		SET @table_start_time = GETDATE();
		PRINT '>> Truncating Table: silver.erp_loc_a101'
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>> Inserting Data Into: silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101 (
			cid,
			cntry
		)
		SELECT
			REPLACE(cid, '-', '') cid,
			CASE
				WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('AUSTRALIA') THEN 'Australia'
				WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('CANADA') THEN 'Canada'
				WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('FRANCE') THEN 'France'
				WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('DE', 'GERMANY') THEN 'Germany'
				WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('UNITED KINGDOM') THEN 'United Kingdom'
				WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('US', 'USA', 'UNITED STATES') THEN 'United States'
				ELSE 'n/a'
			END cntry
		FROM bronze.erp_loc_a101;
		SET @table_end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @table_start_time, @table_end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------------------------';

		-- 3
		SET @table_start_time = GETDATE();
		PRINT '>> Truncating Table: silver.erp_px_cat_g1v2'
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
		INSERT INTO silver.erp_px_cat_g1v2 (
			id,
			cat,
			subcat,
			maintenance
		)
		SELECT
			id,
			cat,
			subcat,
			CASE WHEN UPPER(TRIM(REPLACE(maintenance, CHAR(13), ''))) = 'YES' THEN 'Yes'
				 ELSE maintenance
			END maintenance
		FROM bronze.erp_px_cat_g1v2;
		SET @table_end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @table_start_time, @table_end_time) AS NVARCHAR) + ' seconds';

		SET @erp_end_time = GETDATE();
		PRINT '>> ------------------------------------------';
		PRINT '>> Total ERP Load Duration: ' + CAST(DATEDIFF(second, @erp_start_time, @erp_end_time) AS NVARCHAR) + ' seconds';
		
	END TRY
	BEGIN CATCH
		PRINT '=============================================';
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
		PRINT 'Error Message: ' + ERROR_MESSAGE();
		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '=============================================';
	END CATCH

	SET @batch_end_time = GETDATE();
	PRINT '=============================================';
	PRINT '>> Total Batch Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
	PRINT '=============================================';
END