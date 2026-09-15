/*
==================================================
Testing the Silver Load Stored Procedure
==================================================
Purpose:
	Executing the silver.load_silver stored procedure to run the full silver layer load
	(truncate + transform + insert across all CRM and ERP tables) and confirm it completes successfully.
*/

EXEC silver.load_silver;