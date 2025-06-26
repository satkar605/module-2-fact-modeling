-- DDL for user_devices_cumulated table
-- This table tracks each user's active days by browser_type.
-- The grain is one row per (user_id, browser_type).

CREATE TABLE user_devices_cumulated (
    user_id BIGINT,                -- Unique identifier for the user
    browser_type VARCHAR,          -- Browser name (e.g., Chrome, Firefox, etc.)
    device_activity_datelist DATE[], -- Array of unique dates when the user was active on this browser
    PRIMARY KEY (user_id, browser_type)
);

-- This schema is normalized: each user/browser_type pair gets its own row.
-- The device_activity_datelist column stores all active dates for that user/browser combination.
