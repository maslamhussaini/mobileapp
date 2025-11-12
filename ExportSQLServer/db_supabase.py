# db_supabase.py
from supabase import create_client, Client

def get_supabase_client() -> Client:
    """Connect to Supabase and return the client object."""
    url = "https://unannygymdwpuadscqjl.supabase.co"
    key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVuYW5ueWd5bWR3cHVhZHNjcWpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNzQyNDAsImV4cCI6MjA3Njg1MDI0MH0.6oGARbFfxPRLEeMhcAu8d1Q1GlJcue2BXXQE704uqGg"
    
    try:
        supabase = create_client(url, key)
        print("✅ Connected to Supabase successfully.")
        return supabase
    except Exception as e:
        print(f"❌ Supabase connection failed: {e}")
        raise
