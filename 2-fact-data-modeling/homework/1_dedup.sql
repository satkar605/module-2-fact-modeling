-- Deduplicate the game_details table to ensure there are no duplicate records at the desired grain.
-- The expected grain is one row per (game_id, team_id, player_id) combination.

-- Step 1: (Optional) Check for duplicates
-- SELECT game_id, team_id, player_id, COUNT(1)
-- FROM game_details
-- GROUP BY 1,2,3
-- HAVING COUNT(1) > 1;

-- Step 2: Deduplicate using ROW_NUMBER()
WITH deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY game_id, team_id, player_id
            ORDER BY game_id  -- or another column if you want deterministic choice
        ) AS row_num
    FROM game_details
)
SELECT *
FROM deduped
WHERE row_num = 1;

-- This query ensures only unique rows per (game_id, team_id, player_id) are retained.
-- Use this result as the clean source for downstream fact table modeling.
