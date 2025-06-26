-- -- Lab 2 begins with exploring the events table
-- SELECT * FROM events;

-- -- We want to cumulate this up and find, for different days, which users are active
-- -- First step: create the table we will be working with
-- -- DROP TABLE users_cumulated;
-- CREATE TABLE users_cumulated(
--     user_id TEXT,
--     -- The list of dates in the past where the user was active
--     dates_active DATE[],
--     -- The current date for the user (snapshot date)
--     date DATE,
--     PRIMARY KEY (user_id, date)
-- );

/*
/*
---------------------------------------------------------------------------------------
  Lab 2: Fact Table Modeling — Merging Yesterday's Snapshot with Today's Events
  Description:
    - Extracts yesterday's snapshot from users_cumulated (2022-12-31).
    - Aggregates today's (2023-01-01) event data from the raw events table.
    - Performs a FULL OUTER JOIN to combine both datasets.
    - Prepares data for updating the fact table, determining the correct snapshot date
      for each user.
    - Accumulates dates_active array for each user based on today's activity.
    - Note: user_id column was changed from BIGINT to TEXT for better flexibility.
---------------------------------------------------------------------------------------
*/
*/
INSERT INTO users_cumulated
WITH yesterday AS (
    -- Step 1: Select yesterday's snapshot from the cumulative fact table
    SELECT *
    FROM users_cumulated
    WHERE date = DATE '2023-01-30'
),

today AS (
    -- Step 2: Aggregate today's events
    SELECT 
        CAST(user_id AS TEXT) AS user_id,
        CAST(event_time AS TIMESTAMP)::DATE AS date_active,  -- parse event_time from TEXT to TIMESTAMP, then extract date
        COUNT(*) AS event_count
    FROM events
    WHERE 
        CAST(event_time AS TIMESTAMP)::DATE = DATE '2023-01-31'
        AND user_id IS NOT NULL  -- filter out NULL user_id to ensure clean join
    GROUP BY user_id, CAST(event_time AS TIMESTAMP)::DATE
)

-- Step 3: Merge yesterday's and today's data using FULL OUTER JOIN
SELECT 
    COALESCE(t.user_id, y.user_id) AS user_id,  -- resolve user_id from either side
    CASE 
        WHEN y.dates_active IS NULL THEN ARRAY[t.date_active]  -- new user: initialize array
        WHEN t.date_active IS NULL THEN y.dates_active         -- inactive user today: carry forward yesterday's array
        ELSE ARRAY[t.date_active] || y.dates_active            -- active returning user: prepend today's date
    END AS dates_active,
    COALESCE(t.date_active, y.date + INTERVAL '1 day') AS date  -- determine snapshot date
FROM today t
FULL OUTER JOIN yesterday y
ON t.user_id = y.user_id;

-- Manually cycling through each day (2023-01-01 to 2023-01-31) to simulate daily incremental loads.
-- In production, this would typically be automated via loops or scheduling tools, but manual execution builds deeper understanding.

-- Behavioral Segmentation using Bitmask Encoding (Full Scaffold)

-- Step 1: Extract snapshot for target date (2023-01-31)
WITH users AS (
    SELECT * 
    FROM users_cumulated
    WHERE date = DATE '2023-01-31'
),

-- Step 2: Generate calendar scaffold covering the past 32 days
series AS (
    SELECT * 
    FROM generate_series(
        DATE '2023-01-01', 
        DATE '2023-01-31', 
        INTERVAL '1 day'
    ) AS series_date
),

-- Step 3: Assign one-hot encoded bit positions based on daily activity
place_holder_ints AS (
    SELECT 
        CASE 
            WHEN dates_active @> ARRAY[series_date::DATE] 
            THEN CAST(POW(2, 32 - (date - series_date::DATE)) AS BIGINT)
            ELSE 0
        END AS placeholder_int_value,
        *
    FROM users
    CROSS JOIN series
)

-- Step 4: Aggregate to build full 32-day bitmask and compute behavioral flags
SELECT 
    user_id,

    -- Full 32-bit activity bitmask representation
    CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32)) AS full_activity_bitmask,

    -- Monthly active: was user active at any point in the 32-day window
    BIT_COUNT(
        CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))
    ) > 0 AS dim_is_monthly_active,

    -- Weekly active: check top 7 bits (last 7 days of activity)
    BIT_COUNT(
        CAST('11111110000000000000000000000000' AS BIT(32))
        &
        CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))
    ) > 0 AS dim_is_weekly_active,

    -- Daily active: check only the top bit (activity today)
    BIT_COUNT(
        CAST('10000000000000000000000000000000' AS BIT(32))
        &
        CAST(CAST(SUM(placeholder_int_value) AS BIGINT) AS BIT(32))
    ) > 0 AS dim_is_daily_active

FROM place_holder_ints
GROUP BY user_id;

