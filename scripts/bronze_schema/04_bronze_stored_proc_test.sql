/*
==================================================
Testing the Bronze Load Stored Procedure
==================================================
Purpose:
	Executing the bronze.load_bronze stored procedure to run the full bronze layer load
	(truncate + bulk insert across all CRM and ERP tables) and confirm it completes successfully.
*/

EXEC bronze.load_bronze;