from db_supabase import get_supabase_client
from db_sqlserver import get_sqlserver_connection
import json
import time
from datetime import datetime, timezone
import pytz


# 3️⃣ Use timezone-aware UTC timestamp
pk_tz = pytz.timezone("Asia/Karachi")
last_sync_time = datetime.now(pk_tz)

# 1️⃣ Connect to Supabase
supabase = get_supabase_client()
# 2️⃣ Connect to local SQL Server
conn = get_sqlserver_connection()
cursor = conn.cursor()
table_to_truncate = "tblsales"

print("🧹 Truncating Supabase table 'tblsales' ...")
try:
     response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
     print(response)
except Exception as e:
     print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")


   
# 3️⃣ Query data
cursor.execute("""
        Select SalesID_PK,SalesDate,CustomerID_FK,BoatID_FK,Active,AccountCode1,AccountCode1Amount,AccountCode2,AccountCode2Amount,BillPrefixID_FK,Reference,CreatedUser,CreatedDate,EditUser,EditDate,PrintBill  
        From tblSales Where salesdate > (select MasterClosingDate  from tblGlobalSettings)""")

rows = cursor.fetchall()

# 4️⃣ Prepare data for Supabase
data = []
def safe_date(value):
  return value.isoformat() if value else None


for row in rows:
    data.append({
        "salesid_pk" : row.SalesID_PK, 
        "salesdate" : safe_date(row.SalesDate), 
        "customerid_fk" : row.CustomerID_FK, 
        "boatid_fk" : row.BoatID_FK, 
        "active" : row.Active, 
        "accountcode1" : row.AccountCode1, 
        "accountcode1amount" : row.AccountCode1Amount, 
        "accountcode2" : row.AccountCode2, 
        "accountcode2amount" : row.AccountCode2Amount, 
        "billprefixid_fk" : row.BillPrefixID_FK, 
        "reference" : row.Reference, 
        "createduser" : row.CreatedUser, 
        "createddate" : safe_date(row.CreatedDate), 
        "edituser" : row.EditUser, 
        "editdate" : safe_date(row.EditDate), 
        "printbill" : row.PrintBill  })

print(f"Total records to insert: {len(data)}")

    # 5️⃣ Insert in batches (to avoid Supabase payload limit)
print(f"📦 Total records to insert: {len(data)}")

    # 6️⃣ Insert into Supabase in batches
batch_size = 5000
for i in range(0, len(data), batch_size):
    batch = data[i:i + batch_size]
    try:
        supabase.table("tblsales").insert(batch).execute()
        print(f"✅ Inserted batch {i//batch_size + 1} ({len(batch)} records)")
        time.sleep(0.5)
    except Exception as e:
        print(f"❌ Error inserting batch {i//batch_size + 1}: {e}")
        time.sleep(2)





supabase.table("tblsynctablelogs").insert({
        "tablename": "tblsales",
        "last_sync": last_sync_time.strftime("%Y-%m-%d %H:%M:%S"),
        "total_records_synced": len(rows),
        "status": "success"
    }).execute()
    
    