# Week 2 Fact Data Modeling - Developer Log

This document tracks the thought process, design decisions, and implementation plan for the Week 2 homework on fact data modeling.

## Objective 1: Create the `user_devices_cumulated` Dimension Table

The primary goal is to create a dimension table that tracks every user's activity across their various devices and browser types. This table will serve as a foundational dimension for more complex user behavior analysis.

### Step 1: Analyze the Source Data

-   **`events` table:** This is our raw event log. The key columns for this task are `user_id`, `device_id`, and `event_time`. This table tells us *who* did something and *when*.
-   **`devices` table:** This is a dimension table that enriches the `events` data. The key columns are `device_id` and `browser_type`. This table tells us *what* was used to perform the action.
-   **The JOIN:** We will need to join `events` and `devices` on `device_id` to link a user's action to the browser they used.

### Step 2: Plan the DDL for `user_devices_cumulated`

The homework requires a `device_activity_datelist` to track active days by `browser_type`. There are two ways to model this:

1.  **Denormalized (e.g., using `JSONB` or `MAP`):** One row per user, with a complex data type holding all browser data. This can be harder to query with standard SQL.
2.  **Normalized (Relational Approach):** Multiple rows per user, with one row for each `browser_type` they've used. This is generally easier to work with in PostgreSQL.

**Decision:** We will use the **normalized approach** as it's cleaner and more standard for relational databases.

**Proposed Schema:**
```sql
CREATE TABLE user_devices_cumulated (
    user_id BIGINT,
    browser_type VARCHAR,
    dates_active ARRAY[DATE],
    -- The grain of this table is one row per user per browser type.
    PRIMARY KEY (user_id, browser_type)
);
```

### Step 3: Plan the Cumulative Load Query

To populate this table, we need a query that builds a complete history for each user/browser combination.

**Logic:**
1.  **JOIN** `events` and `devices`.
2.  **GROUP BY** `user_id` and `browser_type`.
3.  **CAST `event_time` to DATE** to get just the active dates, ignoring the time part.
4.  **Use `ARRAY_AGG(DISTINCT ...)`** to collect all unique dates for each group into an array.

This will be a **full, cumulative backfill**, not an incremental load.

### Step 4: Deduplication of Events Data

Before building any aggregates or dimensions, it's crucial to ensure our event data is clean and free of duplicates at the intended grain.

**Action Taken:**
- Wrote a query using `ROW_NUMBER() OVER (PARTITION BY user_id, device_id, host, event_time)` to identify duplicates.
- Retained only the first occurrence of each unique `(user_id, device_id, host, event_time)` combination.
- This deduplicated dataset will be used as the clean source for all downstream modeling.

**Why this matters:**  
Deduplication ensures that all counts, aggregations, and user/device activity lists are accurate and not inflated by duplicate log entries.

---

*Next up: Use this deduped data as the base for building the `user_devices_cumulated` table as planned in Step 3 above.*

## Objective 2: Generate the `datelist_int` Representation

*This will be the next step after the cumulative table is built.*

**Logic:**
- We'll need to transform the `ARRAY[DATE]` into a different format. An integer representation of a date list often involves bitmaps or other clever encoding for efficient storage and querying, but for this exercise, it might mean something simpler like the number of days since a base date. This requires more clarification, but we'll tackle it after building the first table.

---

## Objective 3: Build the `hosts_cumulated` Table

*This is a separate data model focused on host activity.*

**Plan:**
- This will follow a similar pattern: create a DDL, then write a query to populate it.
- The grain will be per `host`.
- We'll need to build a `host_activity_datelist` by aggregating dates from the `events` table.

---
*This log will be updated as each task is completed.*
