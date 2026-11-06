
-- =============================================
-- 01_ddl.sql
-- create database and schemas
-- =============================================

use master;
go

if db_id(N'AirbnbDWH') is null
    create database AirbnbDWH;
go

use AirbnbDWH;
go

-- create bronze schema
if schema_id(N'BRONZE') is null
    exec(N'create schema BRONZE');
go

-- create silver schema
if schema_id(N'SILVER') is null
    exec(N'create schema SILVER');
go

-- create gold schema
if schema_id(N'GOLD') is null
    exec(N'create schema GOLD');
go