-- Create a simple function that returns 5 rows immediately
CREATE OR REPLACE FUNCTION sp_gettop5balances(p_accountcode TEXT, p_accounttype TEXT)
RETURNS TABLE(
    accountname TEXT,
    accountnamesubsidiary TEXT,
    balance NUMERIC
) AS $$
BEGIN
    -- Return 5 hardcoded sample customer balance records
    RETURN QUERY VALUES
        ('ABC Trading Company', 'Main Branch', 15420.50),
        ('XYZ Enterprises Ltd', 'Head Office', 28750.75),
        ('Global Solutions Inc', 'Regional Office', 9850.25),
        ('Metro Distributors', 'Warehouse Branch', 32100.00),
        ('Prime Suppliers Co', 'Distribution Center', 45670.90);
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission to anon role
GRANT EXECUTE ON FUNCTION sp_gettop5balances(TEXT, TEXT) TO anon;