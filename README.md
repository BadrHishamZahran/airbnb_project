# airbnb_project
Airbnb Data Warehouse and EDA

# Airbnb European Cities: Scraping, Data Warehouse & Power BI Dashboard

An end-to-end data project: scrape Airbnb listings for 10 European cities with Selenium, load them into a SQL Server data warehouse using a Bronze / Silver / Gold (medallion) architecture, and explore the results in a Power BI dashboard.

## Table of Contents

- [Project Overview](#project-overview)
- [Dataset](#dataset)
- [Project Structure](#project-structure)
- [Tech Stack](#tech-stack)
- [Pipeline](#pipeline)
  - [1. Web Scraping](#1-web-scraping)
  - [2. Data Warehouse](#2-data-warehouse)
  - [3. Power BI Dashboard](#3-power-bi-dashboard)
- [Getting Started](#getting-started)
- [Data Notes & Limitations](#data-notes--limitations)

## Project Overview

The goal is to compare short-stay accommodation across popular European destinations: how much a trip costs, how guests rate their stays, and how host status (Superhost, Guest Favorite) relates to price and ratings.

All listings were scraped for the same search so prices are directly comparable:

| Search parameter | Value |
|---|---|
| Cities | Amsterdam, Athens, Barcelona, Berlin, Budapest, Lisbon, London, Paris, Rome, Vienna |
| Check-in / Check-out | 2027-02-01 / 2027-02-06 (5 nights) |
| Guests | 4 adults |
| Room type | Entire home/apt |
| Minimum bedrooms | 2 |
| Currency | EUR |

## Dataset

- **500 listings**, 50 per city, one row per unique listing (`listing_id`)
- **23 columns** covering identity, location, price, ratings, host status, search context and scrape metadata
- Single snapshot, scraped on 2026-10-28 (one `Scrape_Run_ID`)

| Group | Columns |
|---|---|
| Listing | `listing_id`, `Property Name`, `Property URL`, `City`, `Search City` |
| Price | `Price`, `Price Raw`, `Price Currency`, `Price Basis`, `Estimated Price Per Night` |
| Quality | `Rating`, `Number of Reviews`, `Superhost Status`, `Guest Favorite Status` |
| Stay / search context | `Stay Check-in`, `Stay Check-out`, `Stay Nights`, `Adults`, `Room Type Filter`, `Minimum Bedrooms` |
| Scrape metadata | `Scraped At`, `Scraped At Timestamp`, `Scrape Run ID` |

## Project Structure

```
Airbnb_Project/
├── data_warehouse/
│   ├── DDL.sql                      # Create database and BRONZE / SILVER / GOLD schemas
│   ├── Bronze.sql                   # Raw-data profiling and quality checks
│   ├── Silver.sql                   # Cleaning and validation
│   └── Gold.sql                     # Star schema (dimensions + fact) and validation
├── images/
│   ├── airbnb_icon.png
│   └── sidebar_icons/               # Dashboard navigation icons (png + svg)
├── metadata/
│   ├── images/                      # Debug screenshots from the scraper
│   └── webpages/                    # Debug HTML snapshot from the scraper
├── scraped_dataset/
│   └── Airbnb_Scraped_Dataset.csv   # Scraper output
├── Airbnb_Dashboard.pbix            # Power BI report
├── scrape_airbnb.ipynb              # Selenium scraper
├── README.md
└── requirements.txt
```

## Tech Stack

- **Python**: Selenium, pandas, webdriver-manager
- **SQL Server (T-SQL)**: data warehouse (`AirbnbDWH`)
- **Power BI**: reporting and visualization

## Pipeline

### 1. Web Scraping

`scrape_airbnb.ipynb` drives a headless Brave/Chrome browser with Selenium. For each city it reads the search result pages, opens every listing and extracts the fields above.

Key design decisions:

- **Stable identifier**: `listing_id` is parsed from the `/rooms/<id>` URL, since names are not unique and the same listing can appear with different query strings. It is stored as text because IDs can be 19 digits long.
- **Robust rating parsing**: text nodes are joined with spaces and the regexes reject digits that belong to a decimal, which avoids glued values such as `4.81719 reviews`.
- **Only complete listings are kept**: listings with no numeric rating (`New` / `N/A`) or no price are skipped, and already-seen listings are never reopened across pages or cities.
- **Price context is recorded**: the displayed price is the total for the selected stay, so `Price Basis = stay_total` and `Estimated Price Per Night = Price / Stay Nights`.
- **Resilience**: first-page retries, a failure streak limit per city, and debug screenshots/HTML saved under `metadata/`.

### 2. Data Warehouse

The CSV is loaded into SQL Server (`AirbnbDWH`) into `BRONZE.Airbnb`, then promoted through the layers. Run the scripts in this order:

| Order | Script | Purpose |
|---|---|---|
| 1 | `DDL.sql` | Creates the database and the `BRONZE`, `SILVER`, `GOLD` schemas |
| 2 | `Bronze.sql` | Profiles the raw table: row counts, duplicate snapshots, price fields, invalid stay durations, empty strings, null stay columns |
| 3 | `Silver.sql` | Trims text, converts empty strings to `NULL`, parses `Scraped_At_Timestamp` to `datetime2`, and assigns a `Data_Quality_Status` |
| 4 | `Gold.sql` | Builds and loads the star schema, then runs validation checks |

**Silver data quality statuses**: `valid`, `invalid_stay_dates`, `stay_nights_mismatch`, `invalid_price`, `invalid_rating`, `invalid_review_count`. All rows are preserved and flagged rather than dropped.

**Gold star schema**

```
Dim_Listing ──┐
Dim_Location ─┤
Dim_Search_Context ─┤
Dim_Stay ─────┼──► Fact_Listing_Snapshot
Dim_Scrape_Run ┤
Dim_Pricing ──┘
```

| Table | Grain / contents |
|---|---|
| `Dim_Listing` | One row per `listing_id` (name, URL) |
| `Dim_Location` | One row per city |
| `Dim_Search_Context` | Adults, room type filter, minimum bedrooms |
| `Dim_Stay` | Check-in, check-out, nights |
| `Dim_Scrape_Run` | Scrape run ID and timestamps |
| `Dim_Pricing` | Currency and price basis |
| `Fact_Listing_Snapshot` | One row per listing per scrape: price, estimated nightly price, rating, review count, Superhost and Guest Favorite flags, data quality status |

`Price_Raw` and `Search_City` are intentionally excluded from Gold. The Gold loads are written to be re-runnable (`not exists` guards), and the validation section confirms row counts and that excluded columns are absent.

### 3. Power BI Dashboard

`Airbnb_Dashboard.pbix` contains five pages:

1. **Executive Overview**
2. **Pricing & Affordability**
3. **Ratings & Guest Satisfaction**
4. **Host & Property Performance**
5. **Property Explorer**

## Getting Started

**Prerequisites**: Python 3.10+, Brave or Chrome, SQL Server (with SSMS or Azure Data Studio), Power BI Desktop.

```bash
# 1. Clone and set up the environment
git clone <your-repo-url>
cd Airbnb_Project
python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -r requirements.txt
```

1. **(Optional) Re-scrape**: open `scrape_airbnb.ipynb`, update `chrome_options.binary_location` to your browser path, adjust the search parameters (dates, guests, cities) and run all cells. Output is written to `scraped_dataset/Airbnb_Scraped_Dataset.csv`. A ready-made dataset is already included.
2. **Build the warehouse**: run `DDL.sql`, import the CSV into `BRONZE.Airbnb` (e.g. with the SSMS Import Flat File wizard), then run `Bronze.sql`, `Silver.sql` and `Gold.sql` in order.
3. **Open the dashboard**: open `Airbnb_Dashboard.pbix` in Power BI Desktop and point the data source to your `AirbnbDWH` server if needed.

## Data Notes & Limitations

- **Single snapshot**: all rows come from one scrape run, so this is a point-in-time comparison, not a price trend.
- **Prices are stay totals** for 5 nights and 4 guests. `Estimated Price Per Night` is simply `Price / 5`; it excludes any pricing nuance such as cleaning fees being spread differently.
- **Future dates**: the searched stay (Feb 2027) is in the future, so prices reflect current asking prices, not realized bookings.
- **Selection bias**: listings without a numeric rating (new or unrated) were excluded, and each city is limited to the first 50 qualifying search results.
- **Very low prices** (e.g. under €100 for a 5-night, 4-guest stay) may reflect per-night or partial prices shown by Airbnb and are worth reviewing as outliers.
- **Silver.sql is a development version**: it drops and recreates `SILVER.Airbnb` on each run; do not use that pattern if historical Silver data must be preserved.
- Web scraping may be subject to Airbnb's terms of service; this project is for educational purposes.
