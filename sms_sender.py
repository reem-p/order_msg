import pyodbc
import requests
import random
import os
import logging
from datetime import datetime
import sys

sys.stdout.reconfigure(encoding='utf-8')

# ==============================
# CONFIG
# ==============================
BATCH_SIZE = 50
SENDER_ID = "NCEDC_Pre.P"
API_URL = "http://172.60.1.78:8000/sms/bulk/"  

LOG_FILE = "sms_sender.log"
MAX_LOG_SIZE = 2 * 1024 * 1024  # 2MB

# ==============================
# LOGGING
# ==============================
if os.path.exists(LOG_FILE) and os.path.getsize(LOG_FILE) > MAX_LOG_SIZE:
    os.remove(LOG_FILE)

logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    encoding="utf-8"
)

# ==============================
# ENV
# ==============================
DB_SERVER = os.getenv("MSG_DB_SERVER")
DB_NAME   = os.getenv("MSG_DB_NAME")
DB_USER   = os.getenv("MSG_DB_USER")
DB_PASS   = os.getenv("MSG_DB_PASS")
API_KEY   = os.getenv("MSG_API_KEY")

if not all([DB_SERVER, DB_NAME, DB_USER, DB_PASS, API_KEY]):
    raise Exception("Missing environment variables")

DB_PASS = DB_PASS.strip()
DB_NAME = DB_NAME.strip()
API_KEY = API_KEY.strip()

# ==============================
# DB CONNECT
# ==============================
conn = pyodbc.connect(
    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
    f"SERVER={DB_SERVER};"
    f"DATABASE={DB_NAME};"
    f"UID={DB_USER};"
    f"PWD={DB_PASS};"
    f"TrustServerCertificate=yes;"
)

conn.setencoding(encoding='utf-16le')
conn.setdecoding(pyodbc.SQL_WCHAR, encoding='utf-16le')
cursor = conn.cursor()
conn.autocommit = False

batch_id = datetime.now().strftime("%d%m%Y_%H%M%S") + f"_{random.randint(1000, 9999)}"

# ==============================
# STEP 1: FETCH + LOCK BATCH
# ==============================
cursor.execute(f"""
WITH cte AS (
    SELECT TOP ({BATCH_SIZE}) *
    FROM MessageQueue WITH (ROWLOCK, READPAST, UPDLOCK)
    WHERE Q_Status = 0
    ORDER BY Q_Priority DESC, Q_Date ASC
)
UPDATE cte
SET Q_Status = 2
OUTPUT INSERTED.*;
""")
rows = cursor.fetchall()

if not rows:
    logging.info("No new messages to process.")
    conn.commit()
    conn.close()
    exit()

columns = [col[0] for col in cursor.description]
messages = [dict(zip(columns, row)) for row in rows]

# ==============================
# LOAD TEMPLATES
# ==============================
cursor.execute("""
SELECT mt_code, msg_template
FROM MessageTemplates
WHERE is_active = 1
""")
templates = {r.mt_code: r.msg_template for r in cursor.fetchall()}

# ==============================
# PREPARE MESSAGES
# ==============================
prepared = []
skipped_no_mobile = 0
skipped_inactive = 0

for msg in messages:
    qid = msg["Q_ID"]
    mt_code = msg["MT_CODE"]

    if not msg["Q_Cust_Mobile_No"] or len(msg["Q_Cust_Mobile_No"]) != 11:
        skipped_no_mobile += 1
        cursor.execute("UPDATE MessageQueue SET Q_Status = 4 WHERE Q_ID = ?", qid)
        logging.warning(f"Skipped Q_ID={qid}: invalid or missing mobile number.")
        continue

    if mt_code not in templates:
        skipped_inactive += 1
        cursor.execute("UPDATE MessageQueue SET Q_Status = 4 WHERE Q_ID = ?", qid)
        logging.warning(f"Skipped Q_ID={qid}: inactive or missing template MT_CODE={mt_code}.")
        continue

    template = templates[mt_code]
    final_msg = template
    otp = None

    if mt_code in (1, 2, 3, 4):
        final_msg = final_msg.replace("{msg_amt}", str(msg["Q_amt"] or ""))
        final_msg = final_msg.replace("{oh_no}", str(msg["Q_EntityKey_Serial"] or ""))
        final_msg = final_msg.replace("{oh_name}", str(msg["Q_Cust_Name"] or ""))
    elif mt_code == 5:
        otp = random.randint(1000, 9999)
        final_msg = final_msg.replace("{otp}", str(otp))

    prepared.append({
        "MobileNo": msg["Q_Cust_Mobile_No"],
        "MsgText": final_msg,
        "Q_ID": qid,
        "otp": otp,
        "raw": msg
    })

if not prepared:
    logging.info("No messages left after filtering invalid or inactive templates.")
    conn.commit()
    conn.close()
    exit()

# ==============================
# SEND API (BULK ONLY)
# ==============================
send_url = API_URL  # always bulk endpoint

payload = {
    "sender_id": SENDER_ID,
    "camp_name": f"batch_{batch_id}",
    "recipient": [{"MobileNo": m["MobileNo"], "MsgText": m["MsgText"]} for m in prepared]
}

headers = {
    "Content-Type": "application/json",
    "Authorization": f"ApiKey {API_KEY}"
}

response = None
response_json = {}

try:
    response = requests.post(send_url, headers=headers, json=payload, timeout=30)
    response.raise_for_status()

    try:
        response_json = response.json()
    except ValueError:
        logging.error(f"Invalid JSON response: {response.text}")

except requests.exceptions.HTTPError as e:
    logging.error(f"HTTP ERROR {response.status_code}: {response.text}")
except requests.exceptions.RequestException as e:
    logging.error(f"REQUEST ERROR: {str(e)}")

parsed = {
    "ref": response_json.get("refNo"),
    "code": response_json.get("errorCode"),
    "msg": response_json.get("errormessage") or response_json.get("errorMessage")
}

# ==============================
# LOG MESSAGE + UPDATE QUEUE
# ==============================
sent_count = 0
failed_count = 0

for m in prepared:
    msg = m["raw"]
    success = (
        response is not None and
        response.status_code == 200 and
        str(parsed.get("code")) == "0"
    )

    cursor.execute("""
    INSERT INTO MessageLog (
        MT_CODE, msg_Cust_Mobile_No, msg_Cust_Name,
        msg_Site, msg_EntityName, msg_EntityKey_Serial,
        msg_Entity_Curr_Branch, msg_EntityKey_No,
        msg_EntityKey_Year, msg_WindowName,
        msg_txt, msg_amt, msg_otp,
        msg_Response, msg_Refrance,
        msg_Error_Code, msg_Error_Message,
        msg_Sent_Date, Q_ID
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CAST(? AS NVARCHAR(MAX)), ?, ?, ?, ?, ?, ?, ?, ?)
    """,
    msg["MT_CODE"], msg["Q_Cust_Mobile_No"], msg["Q_Cust_Name"],
    msg["Q_Site"], msg["Q_EntityName"], msg["Q_EntityKey_Serial"],
    msg["Q_Entity_Curr_Branch"], msg["Q_EntityKey_No"],
    msg["Q_EntityKey_Year"], msg["Q_WindowName"],
    m["MsgText"], msg["Q_amt"], m["otp"],
    str(response_json), parsed["ref"], parsed["code"], parsed["msg"],
    datetime.now(), msg["Q_ID"]
    )

    cursor.execute(
        "UPDATE MessageQueue SET Q_Status = ? WHERE Q_ID = ?",
        1 if success else 4,
        msg["Q_ID"]
    )

    if success:
        sent_count += 1
    else:
        failed_count += 1

# ==============================
# LOG BATCH (only once at the end)
# ==============================
cursor.execute("""
INSERT INTO MessageBatchLog (
    batch_id, batch_date, total_count,
    sent_count, failed_count,
    skipped_no_mobile, skipped_inactive,
    error_message
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
""",
batch_id,
datetime.now(),
len(messages),
sent_count,
failed_count,
skipped_no_mobile,
skipped_inactive,
None
)

conn.commit()
conn.close()
logging.info(f"Batch {batch_id} finished: {sent_count} sent, {failed_count} failed, {skipped_no_mobile} skipped, {skipped_inactive} inactive.")
