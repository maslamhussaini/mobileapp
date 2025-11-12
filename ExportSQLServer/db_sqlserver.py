# db_sqlserver.py
import pyodbc

def get_sqlserver_connection():
    """Connect to the local SQL Server database and return the connection object."""
    try:
        conn = pyodbc.connect(
            "DRIVER={ODBC Driver 17 for SQL Server};"
            "SERVER=localhost;"
            "DATABASE=HussainOils2023;"
            "UID=RemoteUser;"
            "PWD=test12345;"
        )
        print("✅ Connected to SQL Server successfully.")
        return conn
    except Exception as e:
        print(f"❌ SQL Server connection failed: {e}")
        raise
