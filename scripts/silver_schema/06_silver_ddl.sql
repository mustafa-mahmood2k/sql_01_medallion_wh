/*
======================================
Creating Silver Layer Tables using DDL
======================================
Purpose:
	Using Data Definition Language to create the structure of 6 empty silver layer tables, mirroring the bronze layer DDL script.
	Creating the silver ddl script is as simple as taking the bronze ddl script and using 'search and replace' to swap 'bronze' for 'silver'.

	Each silver table also includes a metadata column that does not originate from the source data:
		dwh_create_date
	These are added by the data engineer to keep track of data issues and to help identify any gaps in the data.
	DATETIME2 is used (as opposed to DATETIME) since it is more precise, and the default value of GETDATE() means it will automatically capture the time of execution on insert.

Steps taken:
	1. Conducting a conditional check to see if the 'silver.crm_cust_info' user-defined table ('U') exists within the database.
	   If it exists, the table is dropped from the database.
	2. An empty table is created, mirroring the equivalent bronze table's columns, with the dwh_create_date metadata column added.
	3. Repeating the above steps for the rest of the silver layer tables.

Note:
	ENSURE TO REDO THIS DDL SCRIPT IF MAKING CHANGES TO TABLE INFORMATION - E.G., AS WE DID FOR prd_info.
*/

USE first_medallion_wh;

---------------
--CRM SOURCES--
---------------
-- 1
IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;
CREATE TABLE silver.crm_cust_info (
    cst_id              INT,
    cst_key             NVARCHAR(50),
    cst_firstname       NVARCHAR(50),
    cst_lastname        NVARCHAR(50),
    cst_marital_status  NVARCHAR(50),
    cst_gndr            NVARCHAR(50),
    cst_create_date     DATE,
    dwh_create_date		DATETIME2 DEFAULT GETDATE() -- DATETIME2 is more precise than DATETIME, default value will automatically be the time of execution
);

-- 2
IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
CREATE TABLE silver.crm_prd_info (
    prd_id       INT,
    cat_id	     NVARCHAR(50),
    prd_key      NVARCHAR(50),
    prd_nm       NVARCHAR(50),
    prd_cost     INT,
    prd_line     NVARCHAR(50),
    prd_start_dt DATE,
    prd_end_dt   DATE,
    dwh_create_date		DATETIME2 DEFAULT GETDATE()
);

-- 3
IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
CREATE TABLE silver.crm_sales_details (
    sls_ord_num  NVARCHAR(50),
    sls_prd_key  NVARCHAR(50),
    sls_cust_id  INT,
    sls_order_dt DATE,
    sls_ship_dt  DATE,
    sls_due_dt   DATE,
    sls_sales    INT,
    sls_quantity INT,
    sls_price    INT,
    dwh_create_date		DATETIME2 DEFAULT GETDATE()
);

---------------
--ERP SOURCES--
---------------
-- 4
IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
CREATE TABLE silver.erp_loc_a101 (
    cid    NVARCHAR(50),
    cntry  NVARCHAR(50),
    dwh_create_date		DATETIME2 DEFAULT GETDATE()
);

-- 5
IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
CREATE TABLE silver.erp_cust_az12 (
    cid    NVARCHAR(50),
    bdate  DATE,
    gen    NVARCHAR(50),
    dwh_create_date		DATETIME2 DEFAULT GETDATE()
);

-- 6
IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
CREATE TABLE silver.erp_px_cat_g1v2 (
    id           NVARCHAR(50),
    cat          NVARCHAR(50),
    subcat       NVARCHAR(50),
    maintenance  NVARCHAR(50),
    dwh_create_date		DATETIME2 DEFAULT GETDATE()
);