/* 
=====================================
Initialising the Database and Schemas
=====================================
Purpose
	Create an empty database called 'first_medallion_wh'.
	Create three schemas (bronze, silver, gold) that define the blueprint of the medallion warehouse database architecture.
 
Steps taken:
 	1. Conducting a conditional check to see if there already exists a database with that name in the system.
 		 If it does exist, the system sets it such that only one user can access that database at a time, 
		 then cancels all running transactions and closes open connections.
 		 The database is then dropped from the system.
 	2. An empty database is then created with the name 'first_medallion_wh'.
 	3. Selecting the specified database as the active working one.
 	4. Creating empty bronze, silver, and gold schemas.
 	
 WARNING:
 	Running the script will permanently delete any existing 'first_medallion_wh' database.
 	If you want to preserve previous iterations of this database, please create backup files. 
 */

USE master;

-- 1.
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'first_medallion_wh')
BEGIN
	ALTER DATABASE first_medallion_wh SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE first_medallion_wh;
END;

-- 2
CREATE DATABASE first_medallion_wh;

-- 3
USE first_medallion_wh;

-- 4
CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;
