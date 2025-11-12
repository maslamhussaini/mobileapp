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
table_to_truncate = "tblsuppliers"

print("🧹 Truncating Supabase table 'tblsuppliers' ...")
try:
    response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
    print(response)
except Exception as e:
    print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")

cursor.execute("""Select SupplierID_PK,SupplierName,ContactPerson,Designation,Address,CityCode,Phone,Fax,Active,GSTNumber,CreatedUser,CreatedDate,EditUser,EditDate From tblSuppliers Order by 1""")

rows = cursor.fetchall()

# 3️⃣ Prepare data
data = []
def safe_date(value):
    return value.isoformat() if value else None

for row in rows:
    data.append({
        "supplierid_pk" : row.SupplierID_PK, 
        "suppliername" : row.SupplierName, 
        "contactperson" : row.ContactPerson, 
        "designation" : row.Designation, 
        "address" : row.Address, 
        "citycode" : row.CityCode, 
        "phone" : row.Phone, 
        "fax" : row.Fax, 
        "active" : row.Active, 
        "gstnumber" : row.GSTNumber, 
        "createduser" : row.CreatedUser, 
        "createddate" : safe_date(row.CreatedDate), 
        "edituser" : row.EditUser, 
        "editdate" : safe_date(row.EditDate), 
    })
print(f"📦 Total records to insert: {len(data)}")

# 6️⃣ Insert into Supabase in batches
batch_size = 1500
for i in range(0, len(data), batch_size):
    batch = data[i:i + batch_size]
    try:
        response = supabase.table("tblsuppliers").insert(data).execute()
        print(f"✅ Inserted batch {i//batch_size + 1} ({len(batch)} records)")
        time.sleep(0.5)
    except Exception as e:
        print(f"❌ Error inserting batch {i//batch_size + 1}: {e}")
        time.sleep(2)


