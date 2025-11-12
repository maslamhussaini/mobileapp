from db_supabase import get_supabase_client
from db_sqlserver import get_sqlserver_connection
import datetime
import json
import time

# 1️⃣ Connect to Supabase
supabase = get_supabase_client()
# 2️⃣ Connect to local SQL Server
conn = get_sqlserver_connection()

cursor = conn.cursor()


table_to_truncate = "tblboatstatus"

print("🧹 Truncating Supabase table 'tblboatstatus' ...")
try:
    response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
    print(response)
except Exception as e:
    print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")

# 3️⃣ Query data
cursor.execute("""
    Select BoatStatusID_PK,BoatStatus,Active,CreatedUser,CreatedDate,EditUser,EditDate From tblBoatStatus Order by 1   
""")

rows = cursor.fetchall()

# 4️⃣ Prepare data for Supabase
data = []
def safe_date(value):
    return value.isoformat() if value else None

for row in rows:
    data.append({
"boatstatusid_pk" : row.BoatStatusID_PK, 
"boatstatus" : row.BoatStatus, 
"active" : row.Active, 
"createduser" : row.CreatedUser, 
"createddate" : safe_date(row.CreatedDate), 
"edituser" : row.EditUser, 
"editdate" : safe_date(row.EditDate)  })

print(f"Total records to insert: {len(data)}")

# 5️⃣ Insert in batches (to avoid Supabase payload limit)
batch_size = 500
for i in range(0, len(data), batch_size):
    batch = data[i:i + batch_size]
    try:
        response = supabase.table("tblboatstatus").insert(data).execute()
        print(f"✅ Inserted batch {i//batch_size + 1} ({len(batch)} records)")
    except Exception as e:
        print(f"❌ Error inserting batch {i//batch_size + 1}: {e}")
        time.sleep(2)
