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
batch_size = 100
max_retries = 10  # Maximum number of retry attempts
retry_delay = 5   # Seconds to wait between retries

#print("🧹 Deleting old records from Supabase table 'tblgeneralledger' ...")

# 2️⃣ Retry RPC deletion until success
success = False
attempt = 1

table_to_truncate = "tblpurchases"

print("🧹 Truncating Supabase table 'tblPurchases' ...")
try:
    response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
    print(response)
except Exception as e:
    print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")

   
# 3️⃣ Query data
cursor.execute("""
     Select PurchaseID_PK,PurchaseDate,SupplierID_FK,Active,Reference,CreatedUser,CreatedDate,EditUser,EditDate  
     From tblPurchases Order by 1   """)

rows = cursor.fetchall()

# 4️⃣ Prepare data for Supabase
data = []
def safe_date(value):
    return value.isoformat() if value else None

for row in rows:
    data.append({
    "purchaseid_pk" : row.PurchaseID_PK, 
    "purchasedate" : safe_date(row.PurchaseDate), 
    "supplierid_fk" : row.SupplierID_FK, 
    "active" : row.Active, 
    "reference" : row.Reference,     
    "createduser"  : row.CreatedUser ,
    "createddate" : safe_date(row.CreatedDate) ,
    "edituser" : row.EditUser ,
    "editdate" : safe_date(row.EditDate)
    }) 


print(f"Total records to insert: {len(data)}")

    # 5️⃣ Insert in batches (to avoid Supabase payload limit)
print(f"📦 Total records to insert: {len(data)}")

    # 6️⃣ Insert into Supabase in batches
batch_size = 5000
for i in range(0, len(data), batch_size):
     batch = data[i:i + batch_size]
     try:
        supabase.table("tblpurchases").insert(batch).execute()
        print(f"✅ Inserted batch {i//batch_size + 1} ({len(batch)} records)")
        time.sleep(0.5)
     except Exception as e:
        print(f"❌ Error inserting batch {i//batch_size + 1}: {e}")
        time.sleep(2)

