-- Fix for Postgrest timeout issue in get_customer_balance function
-- This script adds SET LOCAL statement_timeout to prevent query cancellation

-- First, let's check if the function exists and get its current definition
SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    obj_description(p.oid, 'pg_proc') AS description
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'get_customer_balance';

-- If the function exists, drop it first (backup the definition before running this)
-- DROP FUNCTION IF EXISTS get_customer_balance(text);

-- Recreate the function with timeout setting
-- Replace the function body below with your actual get_customer_balance implementation

CREATE OR REPLACE FUNCTION get_customer_balance(
    customer_name_param text
)
RETURNS TABLE (
    customername text,
    bill_amount_balance numeric,
    advance numeric,
    cheque_bounced numeric,
    pdc numeric,
    total numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Set local statement timeout to 300 seconds to prevent cancellation
    SET LOCAL statement_timeout = '300s';

    -- Your existing function logic goes here
    -- This is a placeholder - replace with your actual query

    RETURN QUERY
    SELECT
        c.customername::text,
        COALESCE(SUM(t.amount), 0) as bill_amount_balance,
        COALESCE(SUM(CASE WHEN t.type = 'advance' THEN t.amount ELSE 0 END), 0) as advance,
        COALESCE(SUM(CASE WHEN t.type = 'cheque_bounced' THEN t.amount ELSE 0 END), 0) as cheque_bounced,
        COALESCE(SUM(CASE WHEN t.type = 'pdc' THEN t.amount ELSE 0 END), 0) as pdc,
        COALESCE(SUM(t.amount), 0) as total
    FROM customers c
    LEFT JOIN transactions t ON c.id = t.customer_id
    WHERE c.customername = customer_name_param
    GROUP BY c.customername;

END;
$$;

-- Grant execute permissions if needed
-- GRANT EXECUTE ON FUNCTION get_customer_balance(text) TO your_user;

-- Alternative: If you prefer to modify existing function without recreating
-- You can add the SET statement at the beginning of your existing function body

/*
If you want to modify the existing function instead of recreating it,
add this line at the very beginning of your function body:

SET LOCAL statement_timeout = '60s';

Example:
CREATE OR REPLACE FUNCTION get_customer_balance(customer_name_param text)
RETURNS TABLE(...) AS $$
BEGIN
    SET LOCAL statement_timeout = '60s';  -- Add this line

    -- Rest of your existing code...
END;
$$ LANGUAGE plpgsql;
*/

-- Test the function (uncomment and modify parameters as needed)
/*
SELECT * FROM get_customer_balance('Customer Name Here');
*/