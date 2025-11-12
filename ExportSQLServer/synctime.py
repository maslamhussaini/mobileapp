from db_supabase import get_supabase_client
from datetime import datetime, timezone
import pytz



import json  # ✅ Needed for pretty printing JSON responses

# 1️⃣ Connect to Supabase
supabase = get_supabase_client()

table_to_truncate = "tblsynclogs"

print("🧹 Truncating Supabase table 'tblsynclogs' ...")
try:
    response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
    print(response)
except Exception as e:
    print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")


# 2️⃣ Example metadata (replace or make dynamic)
user_id = "9dfcaaaa-bbbb-cccc-dddd-eeeeffffffff"  # Replace with real user ID (UUID)
table_name = "tblCustomers"                       # Example table name
pk_tz = pytz.timezone("Asia/Karachi")
# 3️⃣ Use timezone-aware UTC timestamp
last_sync_time = datetime.now(pk_tz)

print(last_sync_time.strftime("%Y-%m-%d %H:%M:%S"))

# 4️⃣ UPSERT record into tblSyncLogs
data = {       
    "last_sync": last_sync_time.strftime("%Y-%m-%d %H:%M:%S")
}
json_data = json.dumps(data)
try:
    res = supabase.table("tblsynclogs").upsert(data).execute()
    print("✅ Sync log updated successfully:")
    print(json.dumps(res.data, indent=2))
except Exception as e:
    print("❌ Error updating sync log:", e)
