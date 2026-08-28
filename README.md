# sql_01_medallion_wh
Using SQL Server to build a data warehouse that includes an ETL process, data modelling, and analytics. 

Project sequence:
1. Requirements analysis
    - Analyse & understand the requirements
2. Design the data architecture
    - Choose the data management approach
    - Design data warehouse layers (data_layers)
    - Draw the data architecture (data_architecture)
3. Project initialisation
    - Define project naming conventions
    - Creating the database & schemas (01_init_database)
4. Building the bronze layer
    - Analysing the source systems
    - Creating empty tables using Data Definition Language (02_bronze_ddl)
    - Loading the data into the empty tables (03_bronze_load)
    - Setting up the bronze layer ingestion as a 'stored procedure' (03_bronze_load)
    - Testing the stored procedure (04_bronze_stored_proc_test)
    - Drawing data flow (data_flow)
4. Building the silver layer
    - Conducting various data validation tests and testing data transformation logic (05_bronze_checks)
    - Drawing data integration (data_integration)
    - Creating empty tables using Data Definition Language (06_silver_ddl)
    - Loading transformed bronze layer data into empty silver tables (07_silver_load)
    - Conducting various data validation tests on the transformed data (08_silver_checks)
       No further transformations required
    - 
      
