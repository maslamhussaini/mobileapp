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
table_to_truncate = "tblstores"

print("🧹 Truncating Supabase table 'tblstores' ...")
try:
    response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
    print(response)
except Exception as e:
    print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")

# 3️⃣ Query data
cursor.execute("""
    Select StoreID_PK,StoreName,Address,PhoneNumber,StoreIncharge,IncrementPercent,Active,StorageCapacity,IncludeInReport,Rate,Amount,CreatedUser,CreatedDate,EditUser,EditDate From tblStores Order by 1  
""")

rows = cursor.fetchall()

# 4️⃣ Prepare data for Supabase
data = []
def safe_date(value):
   return value.isoformat() if value else None

for row in rows:
    data.append({
"storeid_pk" : row.StoreID_PK, 
"storename" : row.StoreName, 
"address" : row.Address, 
"phonenumber" : row.PhoneNumber, 
"storeincharge" : row.StoreIncharge, 
"incrementpercent" : row.IncrementPercent, 
"active" : row.Active, 
"storagecapacity" : row.StorageCapacity, 
"includeinreport" : row.IncludeInReport, 
"rate" : row.Rate, 
"amount" : row.Amount, 
"createduser" : row.CreatedUser, 
"createddate" : row.CreatedDate, 
"edituser" : row.EditUser, 
"editdate" : row.EditDate     })

print(f"📦 Total records to insert: {len(data)}")

# 6️⃣ Insert into Supabase in batches
batch_size = 1500
for i in range(0, len(data), batch_size):
    batch = data[i:i + batch_size]
    try:
        supabase.table("tblstores").insert(batch).execute()
        print(f"✅ Inserted batch {i//batch_size + 1} ({len(batch)} records)")
        time.sleep(0.5)
    except Exception as e:
        print(f"❌ Error inserting batch {i//batch_size + 1}: {e}")
        time.sleep(2)
