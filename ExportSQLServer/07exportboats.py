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

table_to_truncate = "tblboats"

print("🧹 Truncating Supabase table 'tblboats' ...")
try:
    response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
    print(response)
except Exception as e:
    print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")


# 3️⃣ Query data
cursor.execute("""
    Select BoatID_PK,CustomerID_FK,BoatName,Model,Active,BoatOwner,Beopari,Nakhuda,CreatedUser,CreatedDate,EditUser,EditDate,IgnoreActivity,InactivityReason,BoatStatusID_FK,IsSelected From tblBoats Order by 1    
""")

rows = cursor.fetchall()

# 4️⃣ Prepare data for Supabase
data = []
for row in rows:
    def safe_date(value):
        return value.isoformat() if value else None

    data.append({
"boatid_pk" : row.BoatID_PK, 
"customerid_fk" : row.CustomerID_FK, 
"boatname" : row.BoatName, 
"model" : row.Model, 
"active" : row.Active, 
"boatowner" : row.BoatOwner, 
"beopari" : row.Beopari, 
"nakhuda" : row.Nakhuda, 
"createduser" : row.CreatedUser, 
"createddate" : safe_date(row.CreatedDate), 
"edituser" : row.EditUser, 
"editdate" : safe_date(row.EditDate), 
"ignoreactivity" : row.IgnoreActivity, 
"inactivityreason" : row.InactivityReason, 
"boatstatusid_fk" : row.BoatStatusID_FK })

print(f"Total records to insert: {len(data)}")

# 5️⃣ Insert in batches (to avoid Supabase payload limit)
print(f"📦 Total records to insert: {len(data)}")

# 6️⃣ Insert into Supabase in batches
batch_size = 1500
for i in range(0, len(data), batch_size):
    batch = data[i:i + batch_size]
    try:
        supabase.table("tblboats").insert(batch).execute()
        print(f"✅ Inserted batch {i//batch_size + 1} ({len(batch)} records)")
        time.sleep(0.5)
    except Exception as e:
        print(f"❌ Error inserting batch {i//batch_size + 1}: {e}")
        time.sleep(2)
