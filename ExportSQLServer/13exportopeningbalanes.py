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

table_to_truncate = "tblopeningbalances"

print("🧹 Truncating Supabase table 'tblopeningbalances' ...")
try:
    response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
    print(response)
except Exception as e:
    print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")

# 3️⃣ Query data
cursor.execute("""
    Select SalesDate,CustomerID_FK,SalesID_PK,CustomerName,BillTotal,SumOfCredit,Balance,BoatName,BoatID_PK,CreatedUser,CreatedDate,EditUser,EditDate From tblOpeningBalances Order by 1   """)

rows = cursor.fetchall()

# 4️⃣ Prepare data for Supabase
data = []
def safe_date(value):
   return value.isoformat() if value else None
    
for row in rows:
    data.append({
"salesdate" : safe_date(row.SalesDate), 
"customerid_fk" : row.CustomerID_FK, 
"salesid_pk" : row.SalesID_PK, 
"customername" : row.CustomerName, 
"billtotal" : row.BillTotal, 
"sumofcredit" : row.SumOfCredit, 
"balance" : row.Balance, 
"boatname" : row.BoatName, 
"boatid_pk" : row.BoatID_PK, 
"createduser" : row.CreatedUser, 
"createddate" : safe_date(row.CreatedDate), 
"edituser" : row.EditUser, 
"editdate" : safe_date(row.EditDate)  })

print(f"📦 Total records to insert: {len(data)}")

# 6️⃣ Insert into Supabase in batches
batch_size = 5000
for i in range(0, len(data), batch_size):
    batch = data[i:i + batch_size]
    try:
        supabase.table("tblopeningbalances").insert(batch).execute()
        print(f"✅ Inserted batch {i//batch_size + 1} ({len(batch)} records)")
        time.sleep(0.5)
    except Exception as e:
        print(f"❌ Error inserting batch {i//batch_size + 1}: {e}")
        time.sleep(2)
