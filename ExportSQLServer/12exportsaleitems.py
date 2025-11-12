from db_supabase import get_supabase_client
from db_sqlserver import get_sqlserver_connection
import time
import json
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
table_to_truncate = "tblsalesdetail"

print("🧹 Truncating Supabase table 'tblsalesdetail' ...")
try:
    response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
    print(response)
except Exception as e:
    print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")
    

# 3️⃣ Query data
cursor.execute("""
    Select top 100 percent SalesDetailID_PK,SalesID_FK,ItemID_FK,Price,Quantity,StoreID_FK From tblSalesDetail 
    inner join tblSales s on s.SalesID_PK = tblSalesDetail.SalesID_FK where s.SalesDate > (select MasterClosingDate from tblGlobalSettings)
    Order by 1   """)

rows = cursor.fetchall()

# 4️⃣ Prepare data for Supabase
data = []
def safe_date(value):
     return value.isoformat() if value else None

for row in rows:
    data.append({
"salesdetailid_pk" : row.SalesDetailID_PK, 
"salesid_fk" : row.SalesID_FK, 
"itemid_fk" : row.ItemID_FK, 
"price" : float(row.Price) if row.Price is not None else 0.0,
"quantity" : row.Quantity, 
"storeid_fk" : row.StoreID_FK,  })

print(f"📦 Total records to insert: {len(data)}")

batch_size = 5000
for i in range(0, len(data), batch_size):
    batch = data[i:i + batch_size]
    try:
        supabase.table("tblsalesdetail").insert(batch).execute()
        print(f"✅ Inserted batch {i//batch_size + 1} ({len(batch)} records)")
        time.sleep(0.5)
    except Exception as e:
        print(f"❌ Error inserting batch {i//batch_size + 1}: {e}")
        time.sleep(2)
        
        
        
supabase.table("tblsynctablelogs").insert({
        "tablename": "tblsalesdetail",
        "last_sync": last_sync_time.strftime("%Y-%m-%d %H:%M:%S"),
        "total_records_synced": len(rows),
        "status": "success"
    }).execute()
    
            