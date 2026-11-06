use AirbnbDWH;
go

-- =============================================
-- Silver.sql
-- Silver layer: cleaning and validation
-- =============================================

-- development version:
-- this drops and recreates the silver table
-- do not use this reset pattern if you need to
-- preserve historical silver data

if object_id('SILVER.Airbnb', 'U') is not null
    drop table SILVER.Airbnb;
go

select
    listing_id,

    nullif(ltrim(rtrim(Property_Name)), '')
        as Property_Name,

    nullif(ltrim(rtrim(Property_URL)), '')
        as Property_URL,

    nullif(ltrim(rtrim(City)), '')
        as City,

    Price,

    nullif(ltrim(rtrim(Price_Currency)), '')
        as Price_Currency,

    nullif(ltrim(rtrim(Price_Basis)), '')
        as Price_Basis,

    Estimated_Price_Per_Night,
    Rating,
    Number_of_Reviews,
    Superhost_Status,
    Guest_Favorite_Status,

    Stay_Check_in,
    Stay_Check_out,
    Stay_Nights,
    Adults,

    nullif(ltrim(rtrim(Room_Type_Filter)), '')
        as Room_Type_Filter,

    Minimum_Bedrooms,
    Scraped_At,

    nullif(ltrim(rtrim(Scraped_At_Timestamp)), '')
        as Scraped_At_Timestamp,

    try_convert(
        datetime2,
        nullif(ltrim(rtrim(Scraped_At_Timestamp)), '')
    ) as Scraped_At_DateTime,

    nullif(ltrim(rtrim(Scrape_Run_ID)), '')
        as Scrape_Run_ID,

    case
        when Stay_Check_in is null
          or Stay_Check_out is null
          or Stay_Check_out <= Stay_Check_in
            then 'invalid_stay_dates'

        when Stay_Nights is null
          or Stay_Nights <> datediff(
                day,
                Stay_Check_in,
                Stay_Check_out
             )
            then 'stay_nights_mismatch'

        when Price_Raw < 0
          or Estimated_Price_Per_Night < 0
            then 'invalid_price'

        when Rating < 0 or Rating > 5
            then 'invalid_rating'

        when Number_of_Reviews < 0
            then 'invalid_review_count'

        else 'valid'
    end as Data_Quality_Status

into SILVER.Airbnb
from BRONZE.Airbnb;
go

-- verify silver results
select
    Data_Quality_Status,
    count(*) as row_count
from SILVER.Airbnb
group by Data_Quality_Status
order by Data_Quality_Status;
go

-- verify total rows were preserved
select
    (select count(*) from BRONZE.Airbnb)
        as Bronze_Rows,
    (select count(*) from SILVER.Airbnb)
        as Silver_Rows;
go

-- inspect cleaned data
select top (20) *
from SILVER.Airbnb;
go
