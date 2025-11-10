-- Create the stored procedure/function in Supabase (PostgreSQL)
-- This function returns 5 sample rows for testing purposes

CREATE OR REPLACE FUNCTION sp_gettop5balances(p_accountcode TEXT, p_accounttype TEXT)
RETURNS TABLE(
    accountname TEXT,
    accountnamesubsidiary TEXT,
    balance NUMERIC
) AS $$
BEGIN
    -- Return 5 sample customer balance records
    RETURN QUERY
    SELECT
        'Customer ' || generate_series(1, 5)::TEXT as accountname,
        'Subsidiary ' || generate_series(1, 5)::TEXT as accountnamesubsidiary,
        (random() * 10000)::NUMERIC(10,2) as balance;
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT * FROM sp_gettop5balances('2', NULL);