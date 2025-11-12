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
table_to_truncate = "tblusers"

print("🧹 Truncating Supabase table 'tblusers' ...")
try:
    response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
    print(response)
except Exception as e:
    print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")

cursor.execute("""
SELECT userid_pk, username, password, currentlyworking, active, createduser , createddate, edituser, editdate FROM tblusers Order by 1
""")

rows = cursor.fetchall()

# 3️⃣ Prepare data
data = []
def safe_date(value):
    return value.isoformat() if value else None
    
for row in rows:
    data.append({
        "userid_pk": row.userid_pk,
        "username": row.username,
        "password": row.password,
        "currentlyworking" : row.currentlyworking,
        "active": row.active,
        "createduser": row.createduser,
        "createddate": safe_date(row.createddate),
        "edituser": row.edituser,
        "editdate": safe_date(row.editdate)
    })
print(f"📦 Total records to insert: {len(data)}")

# 6️⃣ Insert into Supabase in batches
batch_size = 500
for i in range(0, len(data), batch_size):
    batch = data[i:i + batch_size]
    try:
        supabase.table("tblusers").insert(batch).execute()
        print(f"✅ Inserted batch {i//batch_size + 1} ({len(batch)} records)")
        time.sleep(0.5)
    except Exception as e:
        print(f"❌ Error inserting batch {i//batch_size + 1}: {e}")
        time.sleep(2)
