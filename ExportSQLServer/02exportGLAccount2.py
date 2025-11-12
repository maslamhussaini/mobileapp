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

# 3️⃣ Truncate Supabase table first
table_to_truncate = "tblchartofaccounts2"

print("🧹 Truncating Supabase table 'tblchartofaccounts2' ...")
try:
    response = supabase.rpc("truncate_table", {"table_name": table_to_truncate}).execute()
    print(response)
except Exception as e:
    print(f"⚠️ Could not truncate via RPC, trying DELETE ALL fallback: {e}")


# 4️⃣ Fetch data from SQL Server
cursor.execute("""
    SELECT AccountCodeControl, AccountCodeSubsidairy, AccountNameSubsidairy, 
           BankAccount, CashAccount, IncludeInFinancialStatements, 
           CreatedUser, CreatedDate, EditUser, EditDate 
    FROM tblChartOfAccounts2 
    ORDER BY 1
""")

rows = cursor.fetchall()

# 5️⃣ Prepare data for Supabase
data = []
def safe_date(value):
    return value.isoformat() if value else None

for row in rows:
    data.append({
        "accountcodecontrol": row.AccountCodeControl,
        "accountcodesubsidairy": row.AccountCodeSubsidairy,
        "accountnamesubsidairy": row.AccountNameSubsidairy,
        "bankaccount": row.BankAccount,
        "cashaccount": row.CashAccount,
        "includeinfinancialstatements": row.IncludeInFinancialStatements,
        "createduser": row.CreatedUser,
        "createddate": safe_date(row.CreatedDate),
        "edituser": row.EditUser,
        "editdate": safe_date(row.EditDate),
    })

print(f"📦 Total records to insert: {len(data)}")

# 6️⃣ Insert into Supabase in batches
batch_size = 500
for i in range(0, len(data), batch_size):
    batch = data[i:i + batch_size]
    try:
        supabase.table("tblchartofaccounts2").insert(batch).execute()
        print(f"✅ Inserted batch {i//batch_size + 1} ({len(batch)} records)")
        time.sleep(0.5)
    except Exception as e:
        print(f"❌ Error inserting batch {i//batch_size + 1}: {e}")
        time.sleep(2)
