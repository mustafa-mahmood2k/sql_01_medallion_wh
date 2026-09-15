/*
==============================================================
Stored Procedure: Loading Source Data into Bronze Layer Tables
==============================================================
Purpose:
	Creating a stored procedure to load the raw source data (CRM and ERP csv files) into their corresponding bronze layer tables.
	Stored procedures are used to save frequently used sql code within the database, so this load process can be re-run on demand.

	Using bulk insert to load the data from the csv files in one go (as opposed to just insert, which does it line by line).
	TRUNCATE (removes all rows from a table, but does not delete the table itself) is used beforehand, since the design for this layer specifies a full load method (truncate and insert).

	PRINT statements are added throughout to improve readability of the load process in the console.
	TRY...CATCH is added for error handling/debugging - sql runs the TRY block, and if it fails, runs the CATCH block to handle the error.

	Tracking ETL duration to help identify bottlenecks, optimise performance, monitor trends, and detect issues.
	Start and end time variables are created for each level of duration (i.e., the whole batch, each source type, and each table).

Steps taken:
	1. Declaring datetime variables to track duration at the batch, source (crm/erp), and table level.
	2. Wrapping the load logic in a TRY block, to be caught by a CATCH block should an error occur.
	3. For each CRM table: truncating the existing table, then bulk inserting the corresponding csv file, printing progress and load duration along the way.
	4. Repeating the above step for each ERP table.
	5. Printing the total load duration for each source group (CRM, ERP), and the total batch duration once loading is complete.
	6. In the CATCH block, printing the error message, number, and state should the procedure fail.

Challenges -> solutions:

	1. SQL Error [4860] [S0001]: Cannot bulk load. The file "..." does not exist or you don't have file access rights.
	-> This error is occuring because sqlserver is running inside a linux container - which cannot see my local mac files.
	   Instead of 
	   '/Users/.../personal_projects/sql_01_medallion_warehouse/datasets/source_crm/cust_info.csv'
	   I had to stop and remove the docker container using:
	   ```
	   docker stop sqlserver2025
	   docker rm sqlserver2025
	   ```
	   Then, I re-ran the docker using:
	   ```
	   docker run -e "ACCEPT_EULA=Y" \
  	   -e 'MSSQL_SA_PASSWORD=...' \
       -p 1433:1433 \
       --name sqlserver2025 \
       -v sqlserver_data:/var/opt/mssql \
       -v /Users/.../personal_projects/sql_01_medallion_warehouse/datasets:/var/opt/mssql/datasets \
       -d mcr.microsoft.com/mssql/server:2025-latest
	   ```
	   which places my datasets inside the container.
	   I then used the file path for the datasets in the container in my SQL code.
	   PS: the bindmount is live, so it reflects any changes inside the local folder (e.g., mispelling source_erp and souce_erp and renaming it)
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
	DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME;
	DECLARE @crm_start_time DATETIME, @crm_end_time DATETIME;
	DECLARE @erp_start_time DATETIME, @erp_end_time DATETIME;
	DECLARE @table_start_time DATETIME, @table_end_time DATETIME;

	SET @batch_start_time = GETDATE();
	BEGIN TRY
		PRINT '=============================================';
		PRINT 'Loading Bronze Layer';
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
		PRINT '>> Truncating Table: bronze.crm_cust_info'
		TRUNCATE TABLE bronze.crm_cust_info;
		PRINT '>> Inserting Data Into: bronze.crm_cust_info'
		BULK INSERT bronze.crm_cust_info
		FROM '/var/opt/mssql/datasets/source_crm/cust_info.csv'
		WITH (
			FIRSTROW = 2, -- the 1st row in the csv file contains the column names
			FIELDTERMINATOR = ',', -- the delimiter/file separator between data values in this file is a comma
			TABLOCK -- improves performance by locking the entire table whilst loading it
		);
		SET @table_end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @table_start_time, @table_end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------------------------';
		-- Make sure to check if the data matches the column names
		-- Use COUNT(*) to check the number of rows in the table, and compare this with the number of lines in the csv file (considering the FIRSTROW = 2)
		-- SELECT * FROM bronze.crm_cust_info;

		-- 2
		SET @table_start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.crm_prd_info'
		TRUNCATE TABLE bronze.crm_prd_info;
		PRINT '>> Inserting Data Into: bronze.crm_prd_info'
		BULK INSERT bronze.crm_prd_info
		FROM '/var/opt/mssql/datasets/source_crm/prd_info.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @table_end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @table_start_time, @table_end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------------------------';

		-- 3
		SET @table_start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.crm_sales_details'
		TRUNCATE TABLE bronze.crm_sales_details;
		PRINT '>> Inserting Data Into: bronze.crm_sales_details'
		BULK INSERT bronze.crm_sales_details
		FROM '/var/opt/mssql/datasets/source_crm/sales_details.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
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

		-- 4
		SET @table_start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.erp_cust_az12'
		TRUNCATE TABLE bronze.erp_cust_az12;
		PRINT '>> Inserting Data Into: bronze.erp_cust_az12'
		BULK INSERT bronze.erp_cust_az12
		FROM '/var/opt/mssql/datasets/source_erp/CUST_AZ12.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @table_end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @table_start_time, @table_end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------------------------';

		-- 5
		SET @table_start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.erp_loc_a101'
		TRUNCATE TABLE bronze.erp_loc_a101;
		PRINT '>> Inserting Data Into: bronze.erp_loc_a101'
		BULK INSERT bronze.erp_loc_a101
		FROM '/var/opt/mssql/datasets/source_erp/LOC_A101.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @table_end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @table_start_time, @table_end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------------------------';

		-- 6
		SET @table_start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.erp_px_cat_g1v2'
		TRUNCATE TABLE bronze.erp_px_cat_g1v2;
		PRINT '>> Inserting Data Into: bronze.erp_px_cat_g1v2'
		BULK INSERT bronze.erp_px_cat_g1v2
		FROM '/var/opt/mssql/datasets/source_erp/PX_CAT_G1V2.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @table_end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @table_start_time, @table_end_time) AS NVARCHAR) + ' seconds';

		SET @erp_end_time = GETDATE();
		PRINT '>> ------------------------------------------';
		PRINT '>> Total ERP Load Duration: ' + CAST(DATEDIFF(second, @erp_start_time, @erp_end_time) AS NVARCHAR) + ' seconds';

	END TRY
	BEGIN CATCH
		PRINT '=============================================';
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER';
		PRINT 'Error Message: ' + ERROR_MESSAGE();
		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR); -- conflict between string and integer due to Data Type Precedence (sql tries to turn string to int)
		PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR); -- returns int code representing exact code location/condition that triggered error
		PRINT '=============================================';
	END CATCH

	SET @batch_end_time = GETDATE();
	PRINT '=============================================';
	PRINT '>> Total Batch Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
	PRINT '=============================================';
END