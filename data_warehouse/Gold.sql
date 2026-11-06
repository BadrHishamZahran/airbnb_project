/*
    Airbnb Data Warehouse
    File: Gold.sql

    Gold Layer: Star Schema

    Dimensions:
        Dim_Listing
        Dim_Location
        Dim_Search_Context
        Dim_Stay
        Dim_Scrape_Run
        Dim_Pricing

    Fact:
        Fact_Listing_Snapshot

    Excluded from Gold:
        Price_Raw
        Search_City
*/

use AirbnbDWH;
go

/* =========================================================
   1. CREATE DIMENSION TABLES
   ========================================================= */


/* 1.1 Dim_Listing */

if object_id('GOLD.Dim_Listing', 'U') is null
begin
    create table GOLD.Dim_Listing
    (
        Listing_Key int identity(1,1) primary key,
        listing_id bigint not null unique,
        Property_Name nvarchar(100) not null,
        Property_URL nvarchar(400) not null
    );
end;
go


/* 1.2 Dim_Location */

if object_id('GOLD.Dim_Location', 'U') is null
begin
    create table GOLD.Dim_Location
    (
        Location_Key int identity(1,1) primary key,
        City nvarchar(50) not null unique
    );
end;
go


/* 1.3 Dim_Search_Context
   Search_City has been excluded.
*/

if object_id('GOLD.Dim_Search_Context', 'U') is null
begin
    create table GOLD.Dim_Search_Context
    (
        Search_Context_Key int identity(1,1) primary key,
        Adults tinyint not null,
        Room_Type_Filter nvarchar(50) not null,
        Minimum_Bedrooms tinyint not null,

        constraint UQ_Dim_Search_Context
            unique (Adults, Room_Type_Filter, Minimum_Bedrooms)
    );
end;
go


/* 1.4 Dim_Stay */

if object_id('GOLD.Dim_Stay', 'U') is null
begin
    create table GOLD.Dim_Stay
    (
        Stay_Key int identity(1,1) primary key,
        Stay_Check_in date not null,
        Stay_Check_out date not null,
        Stay_Nights tinyint not null,

        constraint UQ_Dim_Stay
            unique (Stay_Check_in, Stay_Check_out, Stay_Nights)
    );
end;
go


/* 1.5 Dim_Scrape_Run */

if object_id('GOLD.Dim_Scrape_Run', 'U') is null
begin
    create table GOLD.Dim_Scrape_Run
    (
        Scrape_Run_Key int identity(1,1) primary key,
        Scrape_Run_ID nvarchar(50) not null unique,
        Scraped_At date not null,
        Scraped_At_DateTime datetime2 null
    );
end;
go


/* 1.6 Dim_Pricing
   Price_Raw has been excluded.
*/

if object_id('GOLD.Dim_Pricing', 'U') is null
begin
    create table GOLD.Dim_Pricing
    (
        Pricing_Key int identity(1,1) primary key,
        Price_Currency nvarchar(50) not null,
        Price_Basis nvarchar(50) not null,

        constraint UQ_Dim_Pricing
            unique (Price_Currency, Price_Basis)
    );
end;
go


/* =========================================================
   2. CREATE FACT TABLE
   ========================================================= */

if object_id('GOLD.Fact_Listing_Snapshot', 'U') is null
begin
    create table GOLD.Fact_Listing_Snapshot
    (
        Snapshot_Key bigint identity(1,1) primary key,

        Listing_Key int not null,
        Location_Key int not null,
        Search_Context_Key int not null,
        Stay_Key int not null,
        Scrape_Run_Key int not null,
        Pricing_Key int not null,

        Price smallint null,
        Estimated_Price_Per_Night float null,
        Rating float null,
        Number_of_Reviews smallint null,
        Superhost_Status bit null,
        Guest_Favorite_Status bit null,

        Data_Quality_Status nvarchar(30) null,

        constraint FK_Fact_Listing
            foreign key (Listing_Key)
            references GOLD.Dim_Listing(Listing_Key),

        constraint FK_Fact_Location
            foreign key (Location_Key)
            references GOLD.Dim_Location(Location_Key),

        constraint FK_Fact_Search_Context
            foreign key (Search_Context_Key)
            references GOLD.Dim_Search_Context(Search_Context_Key),

        constraint FK_Fact_Stay
            foreign key (Stay_Key)
            references GOLD.Dim_Stay(Stay_Key),

        constraint FK_Fact_Scrape_Run
            foreign key (Scrape_Run_Key)
            references GOLD.Dim_Scrape_Run(Scrape_Run_Key),

        constraint FK_Fact_Pricing
            foreign key (Pricing_Key)
            references GOLD.Dim_Pricing(Pricing_Key)
    );
end;
go


/* =========================================================
   3. LOAD DIMENSION TABLES FROM SILVER
   ========================================================= */


/* 3.1 Load Dim_Listing */

insert into GOLD.Dim_Listing
(
    listing_id,
    Property_Name,
    Property_URL
)
select
    s.listing_id,
    coalesce(max(s.Property_Name), N'(unknown)'),
    coalesce(max(s.Property_URL), N'(unknown)')
from SILVER.Airbnb as s
where s.listing_id is not null
group by s.listing_id
having not exists
(
    select 1
    from GOLD.Dim_Listing as d
    where d.listing_id = s.listing_id
);
go


/* 3.2 Load Dim_Location */

insert into GOLD.Dim_Location
(
    City
)
select distinct
    coalesce(nullif(ltrim(rtrim(s.City)), N''), N'(unknown)')
from SILVER.Airbnb as s
where not exists
(
    select 1
    from GOLD.Dim_Location as d
    where d.City =
        coalesce(nullif(ltrim(rtrim(s.City)), N''), N'(unknown)')
);
go


/* 3.3 Load Dim_Search_Context */

insert into GOLD.Dim_Search_Context
(
    Adults,
    Room_Type_Filter,
    Minimum_Bedrooms
)
select distinct
    coalesce(s.Adults, 0),
    coalesce(nullif(ltrim(rtrim(s.Room_Type_Filter)), N''), N'(unknown)'),
    coalesce(s.Minimum_Bedrooms, 0)
from SILVER.Airbnb as s
where not exists
(
    select 1
    from GOLD.Dim_Search_Context as d
    where d.Adults = coalesce(s.Adults, 0)
      and d.Room_Type_Filter =
          coalesce(nullif(ltrim(rtrim(s.Room_Type_Filter)), N''), N'(unknown)')
      and d.Minimum_Bedrooms = coalesce(s.Minimum_Bedrooms, 0)
);
go


/* 3.4 Load Dim_Stay */

insert into GOLD.Dim_Stay
(
    Stay_Check_in,
    Stay_Check_out,
    Stay_Nights
)
select distinct
    coalesce(s.Stay_Check_in, convert(date, '19000101')),
    coalesce(s.Stay_Check_out, convert(date, '19000101')),
    coalesce(s.Stay_Nights, 0)
from SILVER.Airbnb as s
where not exists
(
    select 1
    from GOLD.Dim_Stay as d
    where d.Stay_Check_in =
          coalesce(s.Stay_Check_in, convert(date, '19000101'))
      and d.Stay_Check_out =
          coalesce(s.Stay_Check_out, convert(date, '19000101'))
      and d.Stay_Nights = coalesce(s.Stay_Nights, 0)
);
go


/* 3.5 Load Dim_Scrape_Run */

insert into GOLD.Dim_Scrape_Run
(
    Scrape_Run_ID,
    Scraped_At,
    Scraped_At_DateTime
)
select
    x.Scrape_Run_ID,
    x.Scraped_At,
    max(x.Scraped_At_DateTime)
from
(
    select
        coalesce(
            nullif(ltrim(rtrim(s.Scrape_Run_ID)), N''),
            N'(unknown)'
        ) as Scrape_Run_ID,

        coalesce(s.Scraped_At, convert(date, '19000101')) as Scraped_At,

        s.Scraped_At_DateTime
    from SILVER.Airbnb as s
) as x
group by x.Scrape_Run_ID, x.Scraped_At
having not exists
(
    select 1
    from GOLD.Dim_Scrape_Run as d
    where d.Scrape_Run_ID = x.Scrape_Run_ID
);
go


/* 3.6 Load Dim_Pricing */

insert into GOLD.Dim_Pricing
(
    Price_Currency,
    Price_Basis
)
select distinct
    coalesce(nullif(ltrim(rtrim(s.Price_Currency)), N''), N'(unknown)'),
    coalesce(nullif(ltrim(rtrim(s.Price_Basis)), N''), N'(unknown)')
from SILVER.Airbnb as s
where not exists
(
    select 1
    from GOLD.Dim_Pricing as d
    where d.Price_Currency =
          coalesce(nullif(ltrim(rtrim(s.Price_Currency)), N''), N'(unknown)')
      and d.Price_Basis =
          coalesce(nullif(ltrim(rtrim(s.Price_Basis)), N''), N'(unknown)')
);
go


/* =========================================================
   4. LOAD FACT TABLE
   ========================================================= */

insert into GOLD.Fact_Listing_Snapshot
(
    Listing_Key,
    Location_Key,
    Search_Context_Key,
    Stay_Key,
    Scrape_Run_Key,
    Pricing_Key,
    Price,
    Estimated_Price_Per_Night,
    Rating,
    Number_of_Reviews,
    Superhost_Status,
    Guest_Favorite_Status,
    Data_Quality_Status
)
select
    dl.Listing_Key,
    dloc.Location_Key,
    dsc.Search_Context_Key,
    dst.Stay_Key,
    dsr.Scrape_Run_Key,
    dp.Pricing_Key,

    s.Price,
    s.Estimated_Price_Per_Night,
    s.Rating,
    s.Number_of_Reviews,
    s.Superhost_Status,
    s.Guest_Favorite_Status,
    s.Data_Quality_Status

from SILVER.Airbnb as s

inner join GOLD.Dim_Listing as dl
    on dl.listing_id = s.listing_id

inner join GOLD.Dim_Location as dloc
    on dloc.City =
       coalesce(nullif(ltrim(rtrim(s.City)), N''), N'(unknown)')

inner join GOLD.Dim_Search_Context as dsc
    on dsc.Adults = coalesce(s.Adults, 0)
   and dsc.Room_Type_Filter =
       coalesce(nullif(ltrim(rtrim(s.Room_Type_Filter)), N''), N'(unknown)')
   and dsc.Minimum_Bedrooms = coalesce(s.Minimum_Bedrooms, 0)

inner join GOLD.Dim_Stay as dst
    on dst.Stay_Check_in =
       coalesce(s.Stay_Check_in, convert(date, '19000101'))
   and dst.Stay_Check_out =
       coalesce(s.Stay_Check_out, convert(date, '19000101'))
   and dst.Stay_Nights = coalesce(s.Stay_Nights, 0)

inner join GOLD.Dim_Scrape_Run as dsr
    on dsr.Scrape_Run_ID =
       coalesce(
           nullif(ltrim(rtrim(s.Scrape_Run_ID)), N''),
           N'(unknown)'
       )

inner join GOLD.Dim_Pricing as dp
    on dp.Price_Currency =
       coalesce(nullif(ltrim(rtrim(s.Price_Currency)), N''), N'(unknown)')
   and dp.Price_Basis =
       coalesce(nullif(ltrim(rtrim(s.Price_Basis)), N''), N'(unknown)')

where not exists
(
    select 1
    from GOLD.Fact_Listing_Snapshot as f
    where f.Listing_Key = dl.Listing_Key
      and f.Location_Key = dloc.Location_Key
      and f.Search_Context_Key = dsc.Search_Context_Key
      and f.Stay_Key = dst.Stay_Key
      and f.Scrape_Run_Key = dsr.Scrape_Run_Key
      and f.Pricing_Key = dp.Pricing_Key
);
go


/* =========================================================
   5. VALIDATION
   ========================================================= */

select 'Dim_Listing' as Table_Name, count_big(*) as Row_Count
from GOLD.Dim_Listing

union all

select 'Dim_Location', count_big(*)
from GOLD.Dim_Location

union all

select 'Dim_Search_Context', count_big(*)
from GOLD.Dim_Search_Context

union all

select 'Dim_Stay', count_big(*)
from GOLD.Dim_Stay

union all

select 'Dim_Scrape_Run', count_big(*)
from GOLD.Dim_Scrape_Run

union all

select 'Dim_Pricing', count_big(*)
from GOLD.Dim_Pricing

union all

select 'Fact_Listing_Snapshot', count_big(*)
from GOLD.Fact_Listing_Snapshot;
go


/* Check for columns that should not exist in Gold */

select
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME
from INFORMATION_SCHEMA.COLUMNS
where TABLE_SCHEMA = 'GOLD'
  and COLUMN_NAME in ('Price_Raw', 'Search_City');
go


/* Row Count & Distinct Values Check */

select
    (select count(*) from SILVER.Airbnb) as Silver_Rows,
    (select count(*) from GOLD.Fact_Listing_Snapshot) as Gold_Fact_Rows,

    (select count(distinct Scrape_Run_ID)
     from SILVER.Airbnb) as Distinct_Scrape_Runs,

    (select count(distinct Stay_Check_in)
     from SILVER.Airbnb) as Distinct_Check_in_Dates,

    (select count(distinct Stay_Check_out)
     from SILVER.Airbnb) as Distinct_Check_out_Dates,

    (select count(distinct Price_Currency)
     from SILVER.Airbnb) as Distinct_Currencies,

    (select count(distinct Price_Basis)
     from SILVER.Airbnb) as Distinct_Price_Bases;
go
