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
table_to_truncate = "tblgeneralledger"

print("🧹 Truncating Supabase table 'transactions' ...")
try:
    response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
    print(response)
except Exception as e:
    print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")


#Where Convert(Date,TransactionDate) > (Select Convert(Date,MasterClosingDate)  from tblGlobalSettings) 
# 3️⃣ Query data
cursor.execute("""
        SELECT TransactionID_PK, AccountCode, Debit, Credit, NarrationsGL, VoucherNumber,
           TransactionDate, Reference, PDC, ChequeNumber, ChequeDate, BankID_FK,
           ChequeBounced, ChequeID_FK, ChequeBookDetailID_FK, MasterBank, Remarks,
           CreatedUser, CreatedDate, EditUser, EditDate, IgnoreInIS, BoatID_FK
        FROM tblGeneralLedger  Where TransactionDate > (select MasterClosingDate  from tblGlobalSettings)  
        
    """)

rows = cursor.fetchall()

# 4️⃣ Prepare data for Supabase
data = []
def safe_date(value):
    return value.isoformat() if value else None
    
for row in rows:
    data.append({
       "transactionid_pk": row.TransactionID_PK,
       "accountcode": row.AccountCode,
       "debit": float(row.Debit) if row.Debit is not None else 0,
       "credit": float(row.Credit) if row.Credit is not None else 0,
       "narrationsgl": row.NarrationsGL,
       "vouchernumber": row.VoucherNumber,
       "transactiondate": safe_date(row.TransactionDate),
       "reference": row.Reference,
       "pdc": row.PDC,
       "chequenumber": row.ChequeNumber,
       "chequedate": safe_date(row.ChequeDate),
       "bankid_fk": row.BankID_FK,
       "chequebounced": row.ChequeBounced,
       "chequeid_fk": row.ChequeID_FK,
       "chequebookdetailid_fk": row.ChequeBookDetailID_FK,
       "masterbank": row.MasterBank,
       "remarks": row.Remarks,
       "createduser": row.CreatedUser,
       "createddate": safe_date(row.CreatedDate),
       "edituser": row.EditUser,
       "editdate": safe_date(row.EditDate),
       "ignoreinis": row.IgnoreInIS,
       "boatid_fk": row.BoatID_FK
        })

print(f"📦 Total records to insert: {len(data)}")

    # 6️⃣ Insert into Supabase in batches
batch_size = 10000
start_time = time.time()

for i in range(0, len(data), batch_size):
    batch = data[i:i + batch_size]
    batch_start = time.time()
    try:
        supabase.table("tblgeneralledger").insert(batch).execute()
        batch_end = time.time()
        elapsed_batch = batch_end - batch_start
        total_elapsed = batch_end - start_time
        print(f"✅ Inserted batch {i//batch_size + 1} "
           f"({len(batch)} records) in {elapsed_batch:.2f}s | Total: {total_elapsed:.2f}s")
        time.sleep(0.5)
    except Exception as e:
        batch_end = time.time()
        elapsed_batch = batch_end - batch_start
        print(f"❌ Error inserting batch {i//batch_size + 1}: {e}")
        time.sleep(2)
        
total_time = time.time() - start_time
print(f"🏁 All batches completed in {total_time:.2f} seconds.")





supabase.table("tblsynctablelogs").insert({
        "tablename": "tblgeneralledger",
        "last_sync": last_sync_time.strftime("%Y-%m-%d %H:%M:%S"),
        "total_records_synced": len(rows),
        "status": "success"
    }).execute() 
            