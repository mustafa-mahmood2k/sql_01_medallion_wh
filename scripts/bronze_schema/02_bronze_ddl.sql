/*
======================================
Creating Bronze Layer Tables using DDL
======================================
Purpose:
	Using Data Definition Language, the portion of SQL that creates/alters/deletes database objects, to create the structure 
	of 6 empty bronze layer tables based on the data sources that will be used to fill the tables.
	The intent of these tables is to facilitate the exact preservation of the raw source data.
	
Steps:
	1. Conducting a conditional check to see if the 'bronze.crm_cust_info' user-defined table ('U') exists within the database.
	   	If it exists, the table is dropped from the database.
	2. An empty table is created, with the user defining specifying the table name, column names (based on source data), and the column datatypes.
	3. Repeating the above steps for the rest of the bronze layer tables
 */

---------------
--CRM SOURCES--
---------------

	-- 1
    -- crm_cust_info --
	IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
	    DROP TABLE bronze.crm_cust_info;
	-- 2
	CREATE TABLE bronze.crm_cust_info (
	    cst_id              INT,
	    cst_key             NVARCHAR(50),
	    cst_firstname       NVARCHAR(50),
	    cst_lastname        NVARCHAR(50),
	    cst_marital_status  NVARCHAR(50),
	    cst_gndr            NVARCHAR(50),
	    cst_create_date     DATE
	);
	-- 3
	
	-- crm_prd_info --
	IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
	    DROP TABLE bronze.crm_prd_info;
	CREATE TABLE bronze.crm_prd_info (
	    prd_id       INT,
	    prd_key      NVARCHAR(50),
	    prd_nm       NVARCHAR(50),
	    prd_cost     INT,
	    prd_line     NVARCHAR(50),
	    prd_start_dt DATETIME,
	    prd_end_dt   DATETIME
	);
	
    -- crm_sales_details --
	IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
	    DROP TABLE bronze.crm_sales_details;
	CREATE TABLE bronze.crm_sales_details (
	    sls_ord_num  NVARCHAR(50),
	    sls_prd_key  NVARCHAR(50),
	    sls_cust_id  INT,
	    sls_order_dt INT,
	    sls_ship_dt  INT,
	    sls_due_dt   INT,
	    sls_sales    INT,
	    sls_quantity INT,
	    sls_price    INT
	);
	
---------------
--ERP SOURCES--
---------------

    -- erp_loc_a101 --
	IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL
	    DROP TABLE bronze.erp_loc_a101;
	CREATE TABLE bronze.erp_loc_a101 (
	    cid    NVARCHAR(50),
	    cntry  NVARCHAR(50)
	);
	
    -- erp_cust_a212 --
	IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL
	    DROP TABLE bronze.erp_cust_az12;
	CREATE TABLE bronze.erp_cust_az12 (
	    cid    NVARCHAR(50),
	    bdate  DATE,
	    gen    NVARCHAR(50)
	);

    -- erp_px_cat_g1v2 --
	IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL
	    DROP TABLE bronze.erp_px_cat_g1v2;
	CREATE TABLE bronze.erp_px_cat_g1v2 (
	    id           NVARCHAR(50),
	    cat          NVARCHAR(50),
	    subcat       NVARCHAR(50),
	    maintenance  NVARCHAR(50)
	);
