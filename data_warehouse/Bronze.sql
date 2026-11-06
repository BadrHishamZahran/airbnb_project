use AirbnbDWH;
go

-- 1. check dataset in BRONZE
select
    table_schema,
    table_name
from information_schema.tables
where table_type = 'BASE TABLE'
order by table_schema, table_name;
go

-- 2. check total rows
select
    count(*) as total_rows
from BRONZE.Airbnb;
go

-- 3. check duplicate listing snapshots
select
    listing_id,
    Scrape_Run_ID,
    Stay_Check_in,
    Stay_Check_out,
    count(*) as duplicate_count
from BRONZE.Airbnb
group by
    listing_id,
    Scrape_Run_ID,
    Stay_Check_in,
    Stay_Check_out
having count(*) > 1
order by duplicate_count desc;
go

-- 4. inspect price fields
select top (20)
    listing_id,
    Price,
    Price_Raw,
    Price_Currency,
    Price_Basis,
    Estimated_Price_Per_Night,
    Stay_Nights
from BRONZE.Airbnb
order by listing_id;
go

-- 5. check invalid stay durations
select
    listing_id,
    Stay_Check_in,
    Stay_Check_out,
    Stay_Nights,
    datediff(day, Stay_Check_in, Stay_Check_out)
        as Calculated_Nights
from BRONZE.Airbnb
where Stay_Check_out <= Stay_Check_in
   or Stay_Nights <> datediff(
        day,
        Stay_Check_in,
        Stay_Check_out
   );
go

-- 6. check text values that are empty or contain only spaces
select
    sum(case when ltrim(rtrim(Property_Name)) = ''
        then 1 else 0 end) as Empty_Property_Name,
    sum(case when ltrim(rtrim(City)) = ''
        then 1 else 0 end) as Empty_City,
    sum(case when ltrim(rtrim(Price_Currency)) = ''
        then 1 else 0 end) as Empty_Price_Currency
from BRONZE.Airbnb;
go


-- 7. check null values in stay columns

use AirbnbDWH;
go

select
    count(*) as Total_Rows,

    sum(case
        when Stay_Check_in is null then 1
        else 0
    end) as Missing_Check_in,

    sum(case
        when Stay_Check_out is null then 1
        else 0
    end) as Missing_Check_out,

    sum(case
        when Stay_Nights is null then 1
        else 0
    end) as Missing_Stay_Nights

from BRONZE.Airbnb;
go