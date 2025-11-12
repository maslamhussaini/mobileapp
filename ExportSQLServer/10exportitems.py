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

table_to_truncate = "tblitems"

print("🧹 Truncating Supabase table 'tblitems' ...")
try:
    response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
    print(response)
except Exception as e:
    print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")

# 3️⃣ Query data
cursor.execute("""
    Select ItemID_PK,ItemName,Price,Cost,Inventory,SalesAccountCode,PurchasesAccountCode,CoGSAccountCode,Increments,CreatedUser,CreatedDate,EditUser,EditDate,ShowInBills From tblItems Order by 1 
""")

rows = cursor.fetchall()

# 4️⃣ Prepare data for Supabase
data = []
def safe_date(value):
    return value.isoformat() if value else None


for row in rows:
    data.append({
        "itemid_pk" : row.ItemID_PK, 
"itemname" : row.ItemName, 
"price" : row.Price, 
"cost" : row.Cost, 
"inventory" : row.Inventory, 
"salesaccountcode" : row.SalesAccountCode, 
"purchasesaccountcode" : row.PurchasesAccountCode, 
"cogsaccountcode" : row.CoGSAccountCode, 
"increments" : row.Increments, 
"createduser" : row.CreatedUser, 
"createddate" : safe_date(row.CreatedDate), 
"edituser" : row.EditUser, 
"editdate" : safe_date(row.EditDate), 
"showinbills" : row.ShowInBills, 
    })

print(f"📦 Total records to insert: {len(data)}")

# 6️⃣ Insert into Supabase in batches
batch_size = 1500
for i in range(0, len(data), batch_size):
    batch = data[i:i + batch_size]
    try:
        supabase.table("tblitems").insert(batch).execute()
        print(f"✅ Inserted batch {i//batch_size + 1} ({len(batch)} records)")
        time.sleep(0.5)
    except Exception as e:
        print(f"❌ Error inserting batch {i//batch_size + 1}: {e}")
        time.sleep(2)
