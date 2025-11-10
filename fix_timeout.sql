-- Fix for Postgrest timeout issue in sp_displayledger function
-- This script adds SET LOCAL statement_timeout to prevent query cancellation

-- First, let's check if the function exists and get its current definition
SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    obj_description(p.oid, 'pg_proc') AS description
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'sp_displayledger';

-- If the function exists, drop it first (backup the definition before running this)
-- DROP FUNCTION IF EXISTS sp_displayledger(text, text, text);

-- Recreate the function with timeout setting
-- Replace the function body below with your actual sp_displayledger implementation

CREATE OR REPLACE FUNCTION sp_displayledger(
    glcode_param text,
    date1_param text,
    date2_param text
)
RETURNS TABLE (
    transdate date,
    vouchernumber text,
    narrationsgl text,
    narration text,
    debit numeric,
    credit numeric,
    runningbalance numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Set local statement timeout to 60 seconds to prevent cancellation
    SET LOCAL statement_timeout = '60s';

    -- Your existing function logic goes here
    -- This is a placeholder - replace with your actual query

    RETURN QUERY
    SELECT
        t.transdate,
        t.vouchernumber::text,
        t.narrationsgl,
        t.narration,
        t.debit,
        t.credit,
        t.runningbalance
    FROM your_transaction_table t
    WHERE t.glcode = glcode_param
    AND t.transdate BETWEEN date1_param::date AND date2_param::date
    ORDER BY t.transdate, t.vouchernumber;

END;
$$;

-- Grant execute permissions if needed
-- GRANT EXECUTE ON FUNCTION sp_displayledger(text, text, text) TO your_user;

-- Alternative: If you prefer to modify existing function without recreating
-- You can add the SET statement at the beginning of your existing function body

/*
If you want to modify the existing function instead of recreating it,
add this line at the very beginning of your function body:

SET LOCAL statement_timeout = '60s';

Example:
CREATE OR REPLACE FUNCTION sp_displayledger(glcode_param text, date1_param text, date2_param text)
RETURNS TABLE(...) AS $$
BEGIN
    SET LOCAL statement_timeout = '60s';  -- Add this line

    -- Rest of your existing code...
END;
$$ LANGUAGE plpgsql;
*/

-- Test the function (uncomment and modify parameters as needed)
/*
SELECT * FROM sp_displayledger('your_gl_code', '2023-01-01', '2025-12-31');
*/