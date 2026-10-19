from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, EmailStr

import sqlite3
import hashlib
import os
import re
import secrets
import smtplib
import html
import json
import urllib.error
import urllib.request

from dotenv import load_dotenv

from datetime import datetime, timedelta
from email.message import EmailMessage
from email.policy import SMTP as SMTPPolicy

import cv2
import numpy as np

from openpyxl import Workbook, load_workbook

from detector import detect


# ============================================================
# FASTAPI APPLICATION
# ============================================================

app = FastAPI(
    title="Driver Safety AI Backend"
)


# ============================================================
# CORS CONFIGURATION
# ============================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# FILE PATH CONFIGURATION
# ============================================================

BASE_DIR = os.path.dirname(
    os.path.abspath(__file__)
)

# Load environment variables from the backend .env file.
ENV_FILE = os.path.join(
    BASE_DIR,
    ".env"
)
load_dotenv(ENV_FILE)

DATABASE = os.path.join(
    BASE_DIR,
    "driver_safety.db"
)

EXCEL_FILE = os.path.join(
    BASE_DIR,
    "registered_users.xlsx"
)


# ============================================================
# EMAIL CONFIGURATION
# ============================================================
#
# IMPORTANT:
# Set these values using environment variables.
#
# Gmail example:
#
# SMTP_EMAIL=yourgmail@gmail.com
# SMTP_APP_PASSWORD=your_16_digit_app_password
#
# RESET_LINK_BASE=http://192.168.1.38:8000
#
# Never put your normal Gmail password here.
# Use a Gmail App Password.
# ============================================================

SMTP_EMAIL = os.getenv(
    "SMTP_EMAIL",
    ""
).replace("\u00a0", "").strip()

SMTP_APP_PASSWORD = os.getenv(
    "SMTP_APP_PASSWORD",
    ""
)

SMTP_SERVER = os.getenv(
    "SMTP_SERVER",
    "smtp.gmail.com"
)

SMTP_PORT = int(
    os.getenv(
        "SMTP_PORT",
        "587"
    )
)

RESET_LINK_BASE = os.getenv(
    "RESET_LINK_BASE",
    "http://127.0.0.1:8000"
)

MAIN_ADMIN_EMAIL = os.getenv(
    "MAIN_ADMIN_EMAIL",
    ""
).strip().lower()


# ============================================================
# MSG91 SMS CONFIGURATION
# ============================================================
# Keep all MSG91 credentials/configuration in the backend .env file.
# Never hard-code the MSG91 authkey in source code.
#
# Required for the SMS endpoint:
#   MSG91_AUTHKEY=your_msg91_authkey
#   MSG91_FLOW_ID=your_msg91_flow_id
#   MSG91_SENDER_ID=your_msg91_sender_id
#
# The configured MSG91 Flow should define these variable names exactly:
#   VAR1 = alert rule name
#   VAR2 = severity
#   VAR3 = alert message
#   VAR4 = timestamp
#
# For India, the MSG91 Flow/template must use the approved DLT
# template and mapped Sender ID configured in your MSG91 account.
# ============================================================

MSG91_AUTHKEY = os.getenv(
    "MSG91_AUTHKEY",
    ""
).replace("\u00a0", "").strip()

MSG91_FLOW_ID = os.getenv(
    "MSG91_FLOW_ID",
    ""
).replace("\u00a0", "").strip()

MSG91_SENDER_ID = os.getenv(
    "MSG91_SENDER_ID",
    ""
).replace("\u00a0", "").strip()

MSG91_SMS_URL = os.getenv(
    "MSG91_SMS_URL",
    "https://control.msg91.com/api/v5/flow"
).replace("\u00a0", "").strip()


# ============================================================
# ADMIN CONFIGURATION
# ============================================================
#
# Only emails listed in  will be treated as admins.
#
# Example:
#
# =admin@gmail.com,companyadmin@gmail.com
#
# Normal users cannot make themselves admin from Flutter.
# ============================================================

ADMIN_APPROVAL_TOKEN_EXPIRY_MINUTES = 60



# ============================================================
# DATABASE CONNECTION
# ============================================================

def get_database_connection():

    connection = sqlite3.connect(
        DATABASE
    )

    connection.row_factory = sqlite3.Row

    return connection


# ============================================================
# DATABASE INITIALIZATION
# ============================================================

def initialize_database():

    connection = get_database_connection()

    cursor = connection.cursor()

    # --------------------------------------------------------
    # CREATE USERS TABLE
    # --------------------------------------------------------

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            phone TEXT,
            password_hash TEXT NOT NULL,
            driving_license TEXT,
            role TEXT DEFAULT 'user',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            reset_token_hash TEXT,
            reset_token_expires_at TIMESTAMP,
            reset_token_used INTEGER DEFAULT 0,
            admin_status TEXT DEFAULT 'approved',
            admin_approval_token_hash TEXT,
            admin_approval_expires_at TIMESTAMP,
            driver_id TEXT UNIQUE
        )
        """
    )

    # --------------------------------------------------------
    # CHECK EXISTING COLUMNS
    # --------------------------------------------------------

    cursor.execute(
        "PRAGMA table_info(users)"
    )

    existing_columns = [
        row["name"]
        for row in cursor.fetchall()
    ]

    # --------------------------------------------------------
    # ADD ADMIN APPROVAL / ACCOUNT ID COLUMNS IF MISSING
    # --------------------------------------------------------

    migration_columns = {
        "admin_status": "TEXT DEFAULT 'approved'",
        "admin_approval_token_hash": "TEXT",
        "admin_approval_expires_at": "TIMESTAMP",
        "driver_id": "TEXT",
    }

    for column_name, column_definition in migration_columns.items():
        if column_name not in existing_columns:
            cursor.execute(
                f"ALTER TABLE users ADD COLUMN {column_name} {column_definition}"
            )

    cursor.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_users_driver_id ON users(driver_id)"
    )

    # Existing accounts remain approved.
    cursor.execute(
        "UPDATE users SET admin_status = 'approved' WHERE admin_status IS NULL OR TRIM(admin_status) = ''"
    )

    # --------------------------------------------------------
    # ADD PHONE COLUMN IF MISSING
    # --------------------------------------------------------

    if "phone" not in existing_columns:

        cursor.execute(
            """
            ALTER TABLE users
            ADD COLUMN phone TEXT
            """
        )

    # --------------------------------------------------------
    # ADD DRIVING LICENSE COLUMN IF MISSING
    # --------------------------------------------------------

    if "driving_license" not in existing_columns:

        cursor.execute(
            """
            ALTER TABLE users
            ADD COLUMN driving_license TEXT
            """
        )

    # --------------------------------------------------------
    # ADD ROLE COLUMN IF MISSING
    # --------------------------------------------------------

    if "role" not in existing_columns:

        cursor.execute(
            """
            ALTER TABLE users
            ADD COLUMN role TEXT DEFAULT 'user'
            """
        )

    # --------------------------------------------------------
    # ADD RESET TOKEN HASH COLUMN IF MISSING
    # --------------------------------------------------------

    if "reset_token_hash" not in existing_columns:

        cursor.execute(
            """
            ALTER TABLE users
            ADD COLUMN reset_token_hash TEXT
            """
        )

    # --------------------------------------------------------
    # ADD RESET TOKEN EXPIRY COLUMN IF MISSING
    # --------------------------------------------------------

    if "reset_token_expires_at" not in existing_columns:

        cursor.execute(
            """
            ALTER TABLE users
            ADD COLUMN reset_token_expires_at TIMESTAMP
            """
        )

    # --------------------------------------------------------
    # ADD RESET TOKEN USED COLUMN IF MISSING
    # --------------------------------------------------------

    if "reset_token_used" not in existing_columns:

        cursor.execute(
            """
            ALTER TABLE users
            ADD COLUMN reset_token_used INTEGER DEFAULT 0
            """
        )

    # --------------------------------------------------------
    # CREATE LOGIN OTP TABLE
    # --------------------------------------------------------

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS login_otps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            otp_hash TEXT NOT NULL,
            expires_at TIMESTAMP NOT NULL,
            attempts INTEGER DEFAULT 0,
            used INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
        """
    )

    connection.commit()

    connection.close()


# ============================================================
# INITIALIZE DATABASE
# ============================================================

initialize_database()


# ============================================================
# PASSWORD HASHING
# ============================================================

def hash_password(password: str) -> str:

    salt = os.urandom(16)

    password_hash = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        100000,
    )

    return (
        salt.hex()
        + ":"
        + password_hash.hex()
    )


# ============================================================
# PASSWORD VERIFICATION
# ============================================================

def verify_password(
    password: str,
    stored_password: str,
) -> bool:

    try:

        salt_hex, stored_hash_hex = (
            stored_password.split(":")
        )

        salt = bytes.fromhex(
            salt_hex
        )

        stored_hash = bytes.fromhex(
            stored_hash_hex
        )

        password_hash = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            salt,
            100000,
        )

        return password_hash == stored_hash

    except Exception:

        return False


# ============================================================
# PASSWORD SPECIFICATION VALIDATION
# ============================================================

def validate_password(password: str):

    # --------------------------------------------------------
    # AT LEAST 8 CHARACTERS
    # --------------------------------------------------------

    if len(password) < 8:

        return (
            False,
            "Password must contain at least 8 characters."
        )

    # --------------------------------------------------------
    # UPPERCASE
    # --------------------------------------------------------

    if not re.search(
        r"[A-Z]",
        password
    ):

        return (
            False,
            "Password must contain at least one uppercase letter."
        )

    # --------------------------------------------------------
    # LOWERCASE
    # --------------------------------------------------------

    if not re.search(
        r"[a-z]",
        password
    ):

        return (
            False,
            "Password must contain at least one lowercase letter."
        )

    # --------------------------------------------------------
    # NUMBER
    # --------------------------------------------------------

    if not re.search(
        r"[0-9]",
        password
    ):

        return (
            False,
            "Password must contain at least one number."
        )

    # --------------------------------------------------------
    # SPECIAL CHARACTER
    # --------------------------------------------------------

    if not re.search(
        r"[^A-Za-z0-9]",
        password
    ):

        return (
            False,
            "Password must contain at least one special character."
        )

    return (
        True,
        "Password is valid."
    )


# ============================================================
# PHONE VALIDATION
# ============================================================

def validate_phone(phone: str):

    cleaned_phone = re.sub(
        r"[\s\-+()]",
        "",
        phone
    )

    if not re.fullmatch(
        r"[6-9][0-9]{9}",
        cleaned_phone
    ):

        return (
            False,
            "Please enter a valid 10-digit phone number."
        )

    return (
        True,
        cleaned_phone
    )



def normalize_otp_identifier(identifier: str):
    """Normalize a login identifier for OTP account lookup."""
    value = (identifier or "").replace("\u00a0", " ").strip()
    compact = re.sub(r"[\s\-+()]", "", value)

    # Accept 91XXXXXXXXXX / +91XXXXXXXXXX and normalize to 10 digits.
    if re.fullmatch(r"91[6-9][0-9]{9}", compact):
        return "phone", compact[-10:]

    # Accept a normal 10-digit Indian mobile number.
    if re.fullmatch(r"[6-9][0-9]{9}", compact):
        return "phone", compact

    # Keep email support for backward compatibility.
    if "@" in value:
        return "email", value.lower()

    # Otherwise treat the value as the Driver/User ID.
    return "driver_id", value


# ============================================================
# ACCOUNT ID HELPERS
# ============================================================

def clean_name_for_id(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9]", "", value).upper()


def split_registered_name(full_name: str):
    parts = [p for p in full_name.strip().split() if p]
    if not parts:
        return "USER", "USER"
    first_name = clean_name_for_id(parts[0]) or "USER"
    last_name = clean_name_for_id(parts[-1]) if len(parts) > 1 else first_name
    return first_name, last_name or first_name


def generate_account_id(connection, full_name: str, role: str) -> str:
    first_name, last_name = split_registered_name(full_name)
    prefix = "ADM" if role.lower() == "admin" else "USR"

    cursor = connection.cursor()
    cursor.execute("SELECT driver_id FROM users WHERE driver_id IS NOT NULL")
    existing_ids = {
        row["driver_id"].upper()
        for row in cursor.fetchall()
        if row["driver_id"]
    }

    cursor.execute(
        "SELECT id FROM users WHERE LOWER(full_name) LIKE ? OR LOWER(full_name) LIKE ?",
        (f"% {last_name.lower()}", f"{last_name.lower()} %"),
    )
    last_name_used = cursor.fetchone() is not None
    name_part = first_name if last_name_used else last_name

    while True:
        number = secrets.randbelow(900000) + 100000
        candidate = f"{prefix}{name_part}{number}"
        if candidate not in existing_ids:
            return candidate


# ============================================================
# REGISTER REQUEST MODEL
# ============================================================

class RegisterRequest(BaseModel):

    full_name: str

    email: EmailStr

    phone: str

    password: str

    driving_license: str | None = None

    account_type: str = "user"

    # Kept for compatibility with the current Flutter screen.
    # It is no longer used for admin authorization.
    admin_registration_code: str | None = None


# ============================================================
# LOGIN REQUEST MODEL
# ============================================================

class LoginRequest(BaseModel):

    identifier: str

    password: str


# ============================================================
# LOGIN OTP REQUEST MODELS
# ============================================================

class SendOTPRequest(BaseModel):

    identifier: str


class VerifyOTPRequest(BaseModel):

    identifier: str

    otp: str


# ============================================================
# FORGOT PASSWORD REQUEST MODEL
# ============================================================

class ForgotPasswordRequest(BaseModel):

    email: EmailStr


# ============================================================
# EXCEL FILE CREATION / SAVE ADMIN
# ============================================================

def sync_admins_to_excel():
    """
    Rebuild the Excel workbook from the SQL database.

    All registered accounts are exported: normal Users and Admins,
    including pending/rejected Admin records.
    Passwords and password hashes are NEVER exported.
    Rebuilding the workbook also repairs older Excel files whose
    columns were created with an outdated format.
    """

    try:
        connection = get_database_connection()
        cursor = connection.cursor()

        cursor.execute(
            """
            SELECT
                id,
                driver_id,
                full_name,
                email,
                phone,
                driving_license,
                role,
                admin_status,
                created_at
            FROM users
            ORDER BY id ASC
            """
        )

        users = cursor.fetchall()
        connection.close()

        workbook = Workbook()
        worksheet = workbook.active
        worksheet.title = "Registered Users"

        headers = [
            "DB ID",
            "Account ID",
            "Full Name",
            "Email",
            "Phone",
            "Driving Licence",
            "Role",
            "Admin Status",
            "Registered Date",
        ]

        worksheet.append(headers)

        for user in users:
            worksheet.append(
                [
                    user["id"],
                    user["driver_id"] or "",
                    user["full_name"] or "",
                    user["email"] or "",
                    user["phone"] or "",
                    user["driving_license"] or "",
                    user["role"] or "user",
                    user["admin_status"] or "approved",
                    user["created_at"] or "",
                ]
            )

        # Make the worksheet readable.
        column_widths = {
            "A": 10,
            "B": 20,
            "C": 25,
            "D": 32,
            "E": 18,
            "F": 22,
            "G": 12,
            "H": 16,
            "I": 18,
            "J": 22,
        }

        for column, width in column_widths.items():
            worksheet.column_dimensions[column].width = width

        worksheet.freeze_panes = "A2"
        worksheet.auto_filter.ref = worksheet.dimensions

        # Keep Account ID and Phone as text so Excel does not
        # accidentally convert/format them.
        for row in range(2, worksheet.max_row + 1):
            worksheet.cell(row=row, column=2).number_format = "@"
            worksheet.cell(row=row, column=5).number_format = "@"

        workbook.save(EXCEL_FILE)
        workbook.close()

        print(
            f"ADMIN EXCEL SYNC SUCCESS | "
            f"Registered accounts exported: {len(users)}"
        )

        return True

    except Exception as e:
        print("EXCEL SYNC ERROR:", str(e))
        return False


def save_user_to_excel(
    user_id,
    full_name,
    email,
    phone,
    driving_license,
    role,
    created_at,
):
    """Backward-compatible wrapper used by the Admin approval flow."""

    return sync_admins_to_excel()


def send_password_reset_email(
    recipient_email: str,
    full_name: str,
    reset_token: str,
):

    if not SMTP_EMAIL:

        print(
            "EMAIL ERROR: SMTP_EMAIL is not configured."
        )

        return False

    if not SMTP_APP_PASSWORD:

        print(
            "EMAIL ERROR: SMTP_APP_PASSWORD is not configured."
        )

        return False

    # --------------------------------------------------------
    # CREATE RESET LINK
    # --------------------------------------------------------

    reset_link = (
        f"{RESET_LINK_BASE}"
        f"/reset-password"
        f"?token={reset_token}"
    )

    # --------------------------------------------------------
    # NORMALIZE EMAIL VALUES
    # --------------------------------------------------------

    full_name = " ".join(
        full_name.replace("\u00a0", " ").split()
    )
    recipient_email = (
        recipient_email.replace("\u00a0", "").strip()
    )

    # --------------------------------------------------------
    # CREATE EMAIL
    # --------------------------------------------------------

    message = EmailMessage(policy=SMTPPolicy)

    message["Subject"] = (
        "Driver Safety AI - Password Reset"
    )

    message["From"] = SMTP_EMAIL.strip()

    message["To"] = recipient_email

    message.set_content(
        f"""
Hello {full_name},

We received a request to reset your Driver Safety AI password.

Click the link below to create a new password:

{reset_link}

This password reset link will expire in 30 minutes.

If you did not request a password reset, you can safely ignore this email.

For security reasons, we never send your existing password by email.

Regards,
Driver Safety AI Team
"""
    )

    # --------------------------------------------------------
    # SEND EMAIL THROUGH SMTP
    # --------------------------------------------------------

    try:

        with smtplib.SMTP(
            SMTP_SERVER,
            SMTP_PORT,
            timeout=20,
        ) as server:

            server.starttls()

            server.login(
                SMTP_EMAIL,
                SMTP_APP_PASSWORD,
            )

            server.send_message(
                message
            )

        print(
            f"PASSWORD RESET EMAIL SENT | "
            f"Email: {recipient_email}"
        )

        return True

    except Exception as e:

        print(
            "EMAIL SEND ERROR:",
            str(e)
        )

        return False


# ============================================================
# ADMIN APPROVAL EMAIL
# ============================================================

def send_email(message: EmailMessage) -> bool:
    if not SMTP_EMAIL or not SMTP_APP_PASSWORD:
        print("EMAIL ERROR: SMTP_EMAIL or SMTP_APP_PASSWORD is not configured.")
        return False

    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT, timeout=20) as server:
            server.starttls()
            server.login(SMTP_EMAIL, SMTP_APP_PASSWORD)
            server.send_message(message)
        return True
    except Exception as e:
        print("EMAIL SEND ERROR:", str(e))
        return False


def send_admin_approval_email(
    full_name: str,
    applicant_email: str,
    phone: str,
    approval_token: str,
) -> bool:
    if not MAIN_ADMIN_EMAIL:
        print("ADMIN APPROVAL EMAIL ERROR: MAIN_ADMIN_EMAIL is not configured.")
        return False

    review_link = f"{RESET_LINK_BASE}/admin-approval?token={approval_token}"

    message = EmailMessage()
    message["Subject"] = "Driver Safety AI - Admin Access Request"
    message["From"] = SMTP_EMAIL
    message["To"] = MAIN_ADMIN_EMAIL

    # Plain-text fallback.
    message.set_content(
        f"""Hello Main Admin,

A new user has requested Admin access for Driver Safety AI.

Name: {full_name}
Email: {applicant_email}
Phone: {phone}

Review and approve/reject this request:
{review_link}

This link is valid for {ADMIN_APPROVAL_TOKEN_EXPIRY_MINUTES} minutes and can be used only once.

Regards,
Driver Safety AI Team
"""
    )

    # HTML email: only ONE link is shown in the email.
    # The link opens a secure approval page containing Approve and Reject buttons.
    message.add_alternative(
        f"""
        <!DOCTYPE html>
        <html>
        <body style="margin:0;padding:0;background:#08111F;font-family:Arial,sans-serif;color:#ffffff;">
            <div style="max-width:620px;margin:30px auto;padding:32px;background:#1B2A41;border-radius:18px;">
                <h2 style="margin-top:0;color:#00E5FF;">Driver Safety AI - Admin Access Request</h2>

                <p style="color:#D6DEE8;line-height:1.6;">
                    Hello Main Admin,
                </p>

                <p style="color:#D6DEE8;line-height:1.6;">
                    A new user has requested Admin access for Driver Safety AI.
                </p>

                <div style="background:#10233D;padding:18px;border-radius:12px;margin:20px 0;">
                    <p style="margin:6px 0;"><strong>Name:</strong> {html.escape(full_name)}</p>
                    <p style="margin:6px 0;"><strong>Email:</strong> {html.escape(applicant_email)}</p>
                    <p style="margin:6px 0;"><strong>Phone:</strong> {html.escape(phone)}</p>
                </div>

                <p style="color:#D6DEE8;line-height:1.6;">
                    Click the button below to review this request. The next page will provide
                    separate <strong>Approve</strong> and <strong>Reject</strong> buttons.
                </p>

                <div style="text-align:center;margin:28px 0;">
                    <a href="{html.escape(review_link, quote=True)}"
                       style="display:inline-block;padding:14px 28px;background:#00C2FF;color:#07111F;text-decoration:none;border-radius:10px;font-weight:bold;">
                        Review Admin Request
                    </a>
                </div>

                <p style="font-size:12px;color:#9BA8B8;line-height:1.5;">
                    This link is valid for {ADMIN_APPROVAL_TOKEN_EXPIRY_MINUTES} minutes
                    and can be used only once.
                </p>

                <p style="color:#D6DEE8;">
                    Regards,<br>
                    Driver Safety AI Team
                </p>
            </div>
        </body>
        </html>
        """,
        subtype="html",
    )

    return send_email(message)


def send_admin_decision_email(
    recipient_email: str,
    full_name: str,
    approved: bool,
    driver_id: str | None = None,
) -> bool:
    message = EmailMessage()
    message["Subject"] = (
        "Driver Safety AI - Admin Access Approved"
        if approved
        else "Driver Safety AI - Admin Access Request Rejected"
    )
    message["From"] = SMTP_EMAIL
    message["To"] = recipient_email

    if approved:
        body = f"""Hello {full_name},

Your Admin access request has been approved by the Main Admin.

Your Admin ID: {driver_id}

You can now log in to Driver Safety AI using your registered email/phone and password.

Regards,
Driver Safety AI Team
"""
    else:
        body = f"""Hello {full_name},

Your Admin access request has been rejected by the Main Admin.

Your account has not been activated as an Admin.

Regards,
Driver Safety AI Team
"""

    message.set_content(body)
    return send_email(message)


def admin_approval_page(message: str, success: bool = True):
    title = "Admin Access Updated" if success else "Admin Approval Error"
    accent = "#00E5FF" if success else "#FF5C5C"
    return HTMLResponse(
        content=f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>{html.escape(title)}</title>
        </head>
        <body style="margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;font-family:Arial;background:linear-gradient(135deg,#08111F,#10233D);color:white;">
            <div style="width:90%;max-width:500px;padding:40px;text-align:center;background:#1B2A41;border-radius:20px;box-shadow:0 20px 50px rgba(0,0,0,.35);">
                <h1 style="color:{accent};">{html.escape(title)}</h1>
                <p style="color:#B7C2D0;line-height:1.7;">{html.escape(message)}</p>
            </div>
        </body>
        </html>
        """,
        status_code=200 if success else 400,
    )


@app.get("/admin-approval", response_class=HTMLResponse)
def admin_approval(token: str, action: str | None = None):
    # --------------------------------------------------------
    # VALIDATE TOKEN BEFORE SHOWING THE APPROVAL PAGE
    # --------------------------------------------------------

    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    connection = get_database_connection()

    try:
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT id, full_name, email, phone, role, admin_status,
                   admin_approval_expires_at
            FROM users
            WHERE admin_approval_token_hash = ?
            """,
            (token_hash,),
        )
        user = cursor.fetchone()

        if user is None:
            connection.close()
            return admin_approval_page(
                "This approval link is invalid or has already been used.",
                False,
            )

        if user["role"].lower() != "admin" or user["admin_status"] != "pending":
            connection.close()
            return admin_approval_page(
                "This admin request has already been processed.",
                False,
            )

        expiry = datetime.fromisoformat(user["admin_approval_expires_at"])

        if datetime.now() > expiry:
            connection.close()
            return admin_approval_page(
                "This admin approval link has expired. The applicant must submit a new request.",
                False,
            )

        # ----------------------------------------------------
        # NO ACTION YET:
        # SHOW ONE PAGE WITH APPROVE / REJECT BUTTONS
        # ----------------------------------------------------

        if action is None:
            approve_link = (
                f"/admin-approval?token={html.escape(token, quote=True)}&action=approve"
            )
            reject_link = (
                f"/admin-approval?token={html.escape(token, quote=True)}&action=reject"
            )

            connection.close()

            return HTMLResponse(
                content=f"""
                <!DOCTYPE html>
                <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Driver Safety AI - Admin Approval</title>
                </head>
                <body style="margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;font-family:Arial,sans-serif;background:linear-gradient(135deg,#08111F,#10233D);color:white;padding:20px;box-sizing:border-box;">
                    <div style="width:100%;max-width:560px;padding:34px;background:#1B2A41;border-radius:20px;box-shadow:0 20px 50px rgba(0,0,0,.35);box-sizing:border-box;">
                        <div style="text-align:center;">
                            <h1 style="color:#00E5FF;margin-top:0;">Admin Access Request</h1>
                            <p style="color:#B7C2D0;line-height:1.6;">
                                A user is requesting Admin access to Driver Safety AI.
                            </p>
                        </div>

                        <div style="background:#10233D;padding:20px;border-radius:14px;margin:24px 0;">
                            <p style="margin:8px 0;"><strong>Name:</strong> {html.escape(user["full_name"])}</p>
                            <p style="margin:8px 0;"><strong>Email:</strong> {html.escape(user["email"])}</p>
                            <p style="margin:8px 0;"><strong>Phone:</strong> {html.escape(user["phone"])}</p>
                        </div>

                        <p style="text-align:center;color:#D6DEE8;line-height:1.6;">
                            Please review the applicant and choose an action.
                        </p>

                        <div style="display:flex;gap:14px;justify-content:center;margin-top:28px;flex-wrap:wrap;">
                            <a href="{approve_link}"
                               style="display:inline-block;min-width:150px;text-align:center;padding:15px 24px;background:#22C55E;color:#07111F;text-decoration:none;border-radius:10px;font-weight:bold;box-sizing:border-box;">
                                ✓ Approve
                            </a>

                            <a href="{reject_link}"
                               style="display:inline-block;min-width:150px;text-align:center;padding:15px 24px;background:#FF5C5C;color:white;text-decoration:none;border-radius:10px;font-weight:bold;box-sizing:border-box;">
                                ✕ Reject
                            </a>
                        </div>

                        <p style="text-align:center;font-size:12px;color:#9BA8B8;margin-top:24px;">
                            This request expires in {ADMIN_APPROVAL_TOKEN_EXPIRY_MINUTES} minutes
                            and can be processed only once.
                        </p>
                    </div>
                </body>
                </html>
                """,
                status_code=200,
            )

        # ----------------------------------------------------
        # PROCESS APPROVE / REJECT
        # ----------------------------------------------------

        if action not in {"approve", "reject"}:
            connection.close()
            return admin_approval_page("Invalid approval action.", False)

        if action == "approve":
            driver_id = generate_account_id(
                connection=connection,
                full_name=user["full_name"],
                role="admin",
            )

            cursor.execute(
                """
                UPDATE users
                SET admin_status = 'approved',
                    driver_id = ?,
                    admin_approval_token_hash = NULL,
                    admin_approval_expires_at = NULL
                WHERE id = ?
                """,
                (driver_id, user["id"]),
            )
            connection.commit()

            # Rebuild the Admin Excel workbook from SQL so that
            # all columns stay aligned and existing old-format files
            # are automatically repaired.
            sync_admins_to_excel()

            connection.close()

            send_admin_decision_email(
                recipient_email=user["email"],
                full_name=user["full_name"],
                approved=True,
                driver_id=driver_id,
            )

            return admin_approval_page(
                f"Admin access approved for {user['full_name']}. Admin ID: {driver_id}",
                True,
            )

        cursor.execute(
            """
            UPDATE users
            SET admin_status = 'rejected',
                admin_approval_token_hash = NULL,
                admin_approval_expires_at = NULL
            WHERE id = ?
            """,
            (user["id"],),
        )
        connection.commit()
        connection.close()

        # Rebuild Excel so the rejected Admin status is also synchronized.
        sync_admins_to_excel()

        send_admin_decision_email(
            recipient_email=user["email"],
            full_name=user["full_name"],
            approved=False,
        )

        return admin_approval_page(
            f"Admin access rejected for {user['full_name']}.",
            True,
        )

    except Exception as e:
        try:
            connection.close()
        except Exception:
            pass

        print("ADMIN APPROVAL ERROR:", str(e))

        return admin_approval_page(
            "Unable to process the admin request.",
            False,
        )


# ============================================================
# ADMIN APPROVAL STATUS
# ============================================================

@app.get("/admin-approval-status")
def admin_approval_status(email: str):
    """
    Allows the registering Admin to check whether the Main Admin
    has approved or rejected the request.

    The Flutter registration screen polls this endpoint while the
    Approval Pending dialog is open.
    """

    email = email.strip().lower()

    if not email:
        return {
            "success": False,
            "message": "Email is required.",
        }

    connection = None

    try:
        connection = get_database_connection()
        cursor = connection.cursor()

        cursor.execute(
            """
            SELECT
                id,
                full_name,
                email,
                role,
                admin_status,
                driver_id
            FROM users
            WHERE LOWER(email) = ?
            LIMIT 1
            """,
            (email,),
        )

        user = cursor.fetchone()
        connection.close()

        if user is None:
            return {
                "success": False,
                "message": "Registration request not found.",
            }

        if user["role"].lower() != "admin":
            return {
                "success": True,
                "admin_status": "not_admin",
            }

        status = (
            user["admin_status"] or "pending"
        ).strip().lower()

        response = {
            "success": True,
            "admin_status": status,
            "full_name": user["full_name"],
        }

        if status == "approved":
            response["approved"] = True
            response["account_id"] = user["driver_id"]
            response["driver_id"] = user["driver_id"]

        elif status == "rejected":
            response["approved"] = False

        else:
            response["approved"] = False

        return response

    except Exception as e:

        if connection is not None:
            try:
                connection.close()
            except Exception:
                pass

        print(
            "ADMIN APPROVAL STATUS ERROR:",
            str(e),
        )

        return {
            "success": False,
            "message": "Unable to check approval status.",
        }


# ============================================================
# ADMIN USER MANAGEMENT APIs
# ============================================================

def verify_approved_admin(admin_account_id: str):
    """
    Verify that the supplied Account ID belongs to an approved Admin.

    The current project does not yet use JWT/session authentication,
    so the Flutter dashboard sends the logged-in Admin Account ID.
    The backend still verifies the ID against SQLite before returning
    any user-management data.
    """

    if not admin_account_id:
        return None

    connection = None

    try:
        connection = get_database_connection()
        cursor = connection.cursor()

        cursor.execute(
            """
            SELECT
                id,
                driver_id,
                full_name,
                email,
                phone,
                role,
                admin_status,
                created_at
            FROM users
            WHERE LOWER(driver_id) = LOWER(?)
              AND LOWER(role) = 'admin'
              AND LOWER(COALESCE(admin_status, 'approved')) = 'approved'
            LIMIT 1
            """,
            (admin_account_id.strip(),),
        )

        admin = cursor.fetchone()
        connection.close()

        return admin

    except Exception as e:
        if connection is not None:
            try:
                connection.close()
            except Exception:
                pass

        print("ADMIN AUTHORIZATION ERROR:", str(e))
        return None


@app.get("/admin/users")
def admin_get_users(
    admin_account_id: str = "",
):
    """
    Return registered accounts from SQLite for an approved Admin.

    Passwords/password hashes are intentionally never returned.
    """

    admin = verify_approved_admin(admin_account_id)

    if admin is None:
        return {
            "success": False,
            "message": "Admin authorization required.",
            "users": [],
        }

    connection = None

    try:
        connection = get_database_connection()
        cursor = connection.cursor()

        cursor.execute(
            """
            SELECT
                id,
                driver_id,
                full_name,
                email,
                phone,
                driving_license,
                role,
                admin_status,
                created_at
            FROM users
            ORDER BY id DESC
            """
        )

        rows = cursor.fetchall()
        connection.close()

        users = []

        for row in rows:
            users.append(
                {
                    "db_id": row["id"],
                    "account_id": row["driver_id"] or "",
                    "full_name": row["full_name"] or "",
                    "email": row["email"] or "",
                    "phone": row["phone"] or "",
                    "driving_license": row["driving_license"] or "",
                    "role": row["role"] or "user",
                    "admin_status": row["admin_status"] or "approved",
                    "registered_date": row["created_at"] or "",
                }
            )

        return {
            "success": True,
            "count": len(users),
            "users": users,
        }

    except Exception as e:
        if connection is not None:
            try:
                connection.close()
            except Exception:
                pass

        print("ADMIN USERS API ERROR:", str(e))

        return {
            "success": False,
            "message": "Unable to load registered users.",
            "users": [],
        }


@app.get("/admin/excel-users")
@app.get("/admin/excel-admins")
def admin_get_excel_admins(
    admin_account_id: str = "",
):
    """
    Return all registered account records currently stored in Excel.

    This reads the workbook generated by sync_admins_to_excel().
    Passwords/password hashes are never stored in or returned from Excel.
    """

    admin = verify_approved_admin(admin_account_id)

    if admin is None:
        return {
            "success": False,
            "message": "Admin authorization required.",
            "users": [],
            "admins": [],
        }

    try:
        # Always rebuild Excel from SQLite before reading it.
        # SQLite is the source of truth, so this also repairs any
        # older/misaligned workbook that may still be on disk.
        sync_admins_to_excel()

        if not os.path.exists(EXCEL_FILE):
            return {
                "success": True,
                "count": 0,
                "users": [],
                "admins": [],
            }

        workbook = load_workbook(
            EXCEL_FILE,
            read_only=True,
            data_only=True,
        )

        if "Registered Users" not in workbook.sheetnames:
            workbook.close()

            return {
                "success": True,
                "count": 0,
                "users": [],
                "admins": [],
            }

        worksheet = workbook["Registered Users"]

        rows = list(
            worksheet.iter_rows(
                values_only=True
            )
        )

        workbook.close()

        if not rows:
            return {
                "success": True,
                "count": 0,
                "users": [],
                "admins": [],
            }

        headers = [
            str(value).strip()
            if value is not None
            else ""
            for value in rows[0]
        ]

        users = []

        for row in rows[1:]:
            item = {}

            for index, header in enumerate(headers):
                if index < len(row):
                    item[header] = (
                        row[index]
                        if row[index] is not None
                        else ""
                    )

            users.append(
                {
                    "db_id": item.get("DB ID", ""),
                    "account_id": item.get("Account ID", ""),
                    "full_name": item.get("Full Name", ""),
                    "email": item.get("Email", ""),
                    "phone": item.get("Phone", ""),
                    "driving_license": item.get(
                        "Driving Licence",
                        "",
                    ),
                    "role": item.get("Role", "user"),
                    "admin_status": item.get(
                        "Admin Status",
                        "approved",
                    ),
                    "registered_date": item.get(
                        "Registered Date",
                        "",
                    ),
                }
            )

        return {
            "success": True,
            "count": len(users),
            "users": users,
            # Keep the old key for the current Flutter screen.
            "admins": users,
        }

    except Exception as e:
        print("ADMIN EXCEL API ERROR:", str(e))

        return {
            "success": False,
            "message": "Unable to read Admin Excel data.",
            "users": [],
            "admins": [],
        }


# ============================================================
# HOME / HEALTH CHECK
# ============================================================

@app.get("/")
def home():

    return {
        "message": "Driver Safety AI Backend Running",
        "status": "success"
    }


# ============================================================
# REGISTER API
# ============================================================

@app.post("/register")
def register_user(
    user: RegisterRequest
):

    connection = None

    try:

        # ----------------------------------------------------
        # CLEAN INPUT
        # ----------------------------------------------------

        full_name = (
            user.full_name.strip()
        )

        email = (
            user.email.strip().lower()
        )

        phone = (
            user.phone.strip()
        )

        password = user.password

        driving_license = (
            user.driving_license.strip()
            if user.driving_license
            else None
        )

        # ----------------------------------------------------
        # DETERMINE REQUESTED ACCOUNT TYPE
        # ----------------------------------------------------

        requested_account_type = (
            user.account_type.strip().lower()
            if user.account_type
            else "user"
        )

        if requested_account_type not in {"user", "admin"}:
            return {
                "success": False,
                "message": "Account type must be User or Admin."
            }

        role = requested_account_type
        admin_status = "pending" if role == "admin" else "approved"

        # ----------------------------------------------------
        # FULL NAME VALIDATION
        # ----------------------------------------------------

        if not full_name:

            return {
                "success": False,
                "message": "Full name is required."
            }

        # ----------------------------------------------------
        # PHONE VALIDATION
        # ----------------------------------------------------

        phone_valid, phone_result = (
            validate_phone(phone)
        )

        if not phone_valid:

            return {
                "success": False,
                "message": phone_result
            }

        phone = phone_result

        # ----------------------------------------------------
        # PASSWORD VALIDATION
        # ----------------------------------------------------

        password_valid, password_message = (
            validate_password(password)
        )

        if not password_valid:

            return {
                "success": False,
                "message": password_message
            }

        # ----------------------------------------------------
        # DATABASE CONNECTION
        # ----------------------------------------------------

        connection = (
            get_database_connection()
        )

        cursor = connection.cursor()

        # ----------------------------------------------------
        # CHECK EXISTING EMAIL
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT id
            FROM users
            WHERE LOWER(email) = LOWER(?)
            """,
            (email,)
        )

        existing_email = (
            cursor.fetchone()
        )

        if existing_email:

            connection.close()

            return {
                "success": False,
                "message":
                    "An account with this email already exists."
            }

        # ----------------------------------------------------
        # CHECK EXISTING PHONE
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT id
            FROM users
            WHERE phone = ?
            """,
            (phone,)
        )

        existing_phone = (
            cursor.fetchone()
        )

        if existing_phone:

            connection.close()

            return {
                "success": False,
                "message":
                    "An account with this phone number already exists."
            }

        # ----------------------------------------------------
        # HASH PASSWORD
        # ----------------------------------------------------

        password_hash = (
            hash_password(password)
        )

        # ----------------------------------------------------
        # SAVE USER TO SQLITE
        # ----------------------------------------------------

        cursor.execute(
            """
            INSERT INTO users (
                full_name,
                email,
                phone,
                password_hash,
                driving_license,
                role,
                admin_status
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                full_name,
                email,
                phone,
                password_hash,
                driving_license,
                role,
                admin_status,
            )
        )

        connection.commit()

        user_id = cursor.lastrowid

        # ----------------------------------------------------
        # GET CREATED TIME
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT created_at
            FROM users
            WHERE id = ?
            """,
            (user_id,)
        )

        created_row = cursor.fetchone()
        created_at = (
            created_row["created_at"]
            if created_row
            else datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        )

        # ----------------------------------------------------
        # NORMAL USER
        # ----------------------------------------------------

        if role == "user":
            driver_id = generate_account_id(
                connection=connection,
                full_name=full_name,
                role="user",
            )

            cursor.execute(
                "UPDATE users SET driver_id = ? WHERE id = ?",
                (driver_id, user_id),
            )
            connection.commit()

            # Keep Excel synchronized immediately after every normal
            # user registration.
            sync_admins_to_excel()

            connection.close()
            connection = None

            print(
                f"NEW USER REGISTERED | ID: {user_id} | "
                f"Account ID: {driver_id} | Email: {email}"
            )

            return {
                "success": True,
                "message": "Account created successfully.",
                "driver_id": driver_id,
                "account_id": driver_id,
                "user": {
                    "id": user_id,
                    "driver_id": driver_id,
                    "full_name": full_name,
                    "email": email,
                    "phone": phone,
                    "driving_license": driving_license,
                    "role": "user",
                    "admin_status": "approved",
                },
            }

        # ----------------------------------------------------
        # ADMIN: CREATE PENDING REQUEST
        # ----------------------------------------------------

        approval_token = secrets.token_urlsafe(32)
        approval_token_hash = hashlib.sha256(
            approval_token.encode("utf-8")
        ).hexdigest()
        approval_expiry = datetime.now() + timedelta(
            minutes=ADMIN_APPROVAL_TOKEN_EXPIRY_MINUTES
        )

        cursor.execute(
            """
            UPDATE users
            SET admin_approval_token_hash = ?,
                admin_approval_expires_at = ?
            WHERE id = ?
            """,
            (approval_token_hash, approval_expiry.isoformat(), user_id),
        )
        connection.commit()
        connection.close()
        connection = None

        email_sent = send_admin_approval_email(
            full_name=full_name,
            applicant_email=email,
            phone=phone,
            approval_token=approval_token,
        )

        if not email_sent:
            connection = get_database_connection()
            cursor = connection.cursor()
            cursor.execute("DELETE FROM users WHERE id = ?", (user_id,))
            connection.commit()
            connection.close()

            return {
                "success": False,
                "message": (
                    "Admin registration could not be submitted because "
                    "the approval email could not be sent. Please check email configuration."
                ),
            }

        # Keep Excel synchronized with the newly registered Admin request.
        # If the request is later approved/rejected, the approval flow
        # rebuilds the workbook again with the final status/account ID.
        sync_admins_to_excel()

        print(
            f"ADMIN REQUEST CREATED | DB ID: {user_id} | "
            f"Name: {full_name} | Email: {email} | Status: pending"
        )

        return {
            "success": True,
            "message": (
                "Admin registration submitted successfully. "
                "Your request is waiting for Main Admin approval."
            ),
            "pending_approval": True,
            "admin_status": "pending",
            "user": {
                "id": user_id,
                "full_name": full_name,
                "email": email,
                "phone": phone,
                "driving_license": driving_license,
                "role": "admin",
                "admin_status": "pending",
            },
        }

    except Exception as e:

        if connection is not None:

            connection.close()

        print(
            "REGISTER ERROR:",
            str(e)
        )

        return {
            "success": False,
            "message":
                "Registration failed.",
            "error":
                str(e)
        }


# ============================================================
# LOGIN API
# ============================================================

@app.post("/login")
def login_user(
    user: LoginRequest
):

    connection = None

    try:

        identifier = (
            user.identifier.strip()
        )

        password = user.password

        # ----------------------------------------------------
        # VALIDATE IDENTIFIER
        # ----------------------------------------------------

        if not identifier:

            return {
                "success": False,
                "message":
                    "Email or phone number is required."
            }

        # ----------------------------------------------------
        # VALIDATE PASSWORD
        # ----------------------------------------------------

        if not password:

            return {
                "success": False,
                "message":
                    "Password is required."
            }

        # ----------------------------------------------------
        # DATABASE CONNECTION
        # ----------------------------------------------------

        connection = (
            get_database_connection()
        )

        cursor = connection.cursor()

        # ----------------------------------------------------
        # FIND USER BY EMAIL OR PHONE
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT
                id,
                driver_id,
                full_name,
                email,
                phone,
                password_hash,
                driving_license,
                role,
                admin_status
            FROM users
            WHERE LOWER(email) = LOWER(?)
               OR phone = ?
               OR LOWER(driver_id) = LOWER(?)
            """,
            (
                identifier,
                identifier,
                identifier,
            )
        )

        existing_user = (
            cursor.fetchone()
        )

        connection.close()

        connection = None

        # ----------------------------------------------------
        # USER NOT FOUND
        # ----------------------------------------------------

        if existing_user is None:

            return {
                "success": False,
                "message":
                    "Invalid email/phone or password."
            }

        # ----------------------------------------------------
        # BLOCK PENDING / REJECTED ADMIN ACCOUNTS
        # ----------------------------------------------------

        if (
            existing_user["role"].lower() == "admin"
            and existing_user["admin_status"] != "approved"
        ):
            return {
                "success": False,
                "message": "Invalid login credentials."
            }

        # ----------------------------------------------------
        # VERIFY PASSWORD
        # ----------------------------------------------------

        password_valid = (
            verify_password(
                password,
                existing_user[
                    "password_hash"
                ],
            )
        )

        if not password_valid:

            return {
                "success": False,
                "message":
                    "Invalid email/phone or password."
            }

        # ----------------------------------------------------
        # LOGIN SUCCESS
        # ----------------------------------------------------

        print(
            f"USER LOGIN SUCCESS | "
            f"ID: {existing_user['id']} | "
            f"Name: {existing_user['full_name']} | "
            f"Email: {existing_user['email']} | "
            f"Phone: {existing_user['phone']} | "
            f"Role: {existing_user['role']}"
        )

        # ----------------------------------------------------
        # RETURN USER INFORMATION
        # ----------------------------------------------------

        return {
            "success": True,
            "message":
                "Login successful.",
            "driver_id": existing_user["driver_id"],
            "account_id": existing_user["driver_id"],
            "user": {
                "id":
                    existing_user["id"],
                "driver_id":
                    existing_user["driver_id"],
                "full_name":
                    existing_user["full_name"],
                "email":
                    existing_user["email"],
                "phone":
                    existing_user["phone"],
                "driving_license":
                    existing_user[
                        "driving_license"
                    ],
                "role":
                    existing_user["role"],
                "admin_status":
                    existing_user["admin_status"],
            }
        }

    except Exception as e:

        if connection is not None:

            connection.close()

        print(
            "LOGIN ERROR:",
            str(e)
        )

        return {
            "success": False,
            "message":
                "Login failed.",
            "error":
                str(e)
        }


# ============================================================
# LOGIN OTP EMAIL
# ============================================================

def send_login_otp_email(
    recipient_email: str,
    full_name: str,
    otp: str,
) -> bool:

    if not SMTP_EMAIL:
        print("OTP EMAIL ERROR: SMTP_EMAIL is not configured.")
        return False

    if not SMTP_APP_PASSWORD:
        print("OTP EMAIL ERROR: SMTP_APP_PASSWORD is not configured.")
        return False

    recipient_email = recipient_email.replace("\u00a0", "").strip()
    full_name = " ".join(full_name.replace("\u00a0", " ").split())

    message = EmailMessage(policy=SMTPPolicy)
    message["Subject"] = "Driver Safety AI - Login Verification Code"
    message["From"] = SMTP_EMAIL.strip()
    message["To"] = recipient_email

    message.set_content(
        f"""Hello {full_name},

Your Driver Safety AI login verification code is:

{otp}

This OTP is valid for 5 minutes and can be used only once.

For security reasons, do not share this OTP with anyone.

If you did not request this login verification code, you can safely ignore this email.

Regards,
Driver Safety AI Team
"""
    )

    try:
        with smtplib.SMTP(
            SMTP_SERVER,
            SMTP_PORT,
            timeout=20,
        ) as server:
            server.starttls()
            server.login(
                SMTP_EMAIL,
                SMTP_APP_PASSWORD,
            )
            server.send_message(message)

        print(
            f"LOGIN OTP EMAIL SENT | Email: {recipient_email}"
        )
        return True

    except Exception as e:
        print(
            "LOGIN OTP EMAIL ERROR:",
            str(e),
        )
        return False


# ============================================================
# SEND LOGIN OTP API
# ============================================================

@app.post("/send-otp")
def send_login_otp(
    request: SendOTPRequest,
):

    connection = None

    try:
        identifier = request.identifier.strip()

        if not identifier:
            return {
                "success": False,
                "message": "User ID or phone number is required.",
            }

        connection = get_database_connection()
        cursor = connection.cursor()

        identifier_type, lookup_value = normalize_otp_identifier(identifier)

        connection = get_database_connection()
        cursor = connection.cursor()

        if identifier_type == "phone":
            cursor.execute(
                """
                SELECT
                    id,
                    driver_id,
                    full_name,
                    email,
                    phone,
                    role,
                    admin_status
                FROM users
                WHERE phone = ?
                LIMIT 1
                """,
                (lookup_value,),
            )
        elif identifier_type == "email":
            cursor.execute(
                """
                SELECT
                    id,
                    driver_id,
                    full_name,
                    email,
                    phone,
                    role,
                    admin_status
                FROM users
                WHERE LOWER(email) = LOWER(?)
                LIMIT 1
                """,
                (lookup_value,),
            )
        else:
            cursor.execute(
                """
                SELECT
                    id,
                    driver_id,
                    full_name,
                    email,
                    phone,
                    role,
                    admin_status
                FROM users
                WHERE LOWER(driver_id) = LOWER(?)
                LIMIT 1
                """,
                (lookup_value,),
            )

        user = cursor.fetchone()

        if user is None:
            connection.close()
            connection = None
            return {
                "success": False,
                "message": "No account found with this User ID or phone number.",
            }

        if (
            (user["role"] or "user").lower() == "admin"
            and (user["admin_status"] or "approved") != "approved"
        ):
            connection.close()
            connection = None
            return {
                "success": False,
                "message": "This admin account is not approved.",
            }

        recipient_email = (user["email"] or "").strip()

        if not recipient_email:
            connection.close()
            connection = None
            return {
                "success": False,
                "message": "No registered email address is available for this account.",
            }

        # Invalidate any previous unused OTP for this account.
        cursor.execute(
            """
            UPDATE login_otps
            SET used = 1
            WHERE user_id = ?
              AND used = 0
            """,
            (user["id"],),
        )

        otp = str(secrets.randbelow(900000) + 100000)
        otp_hash = hashlib.sha256(otp.encode("utf-8")).hexdigest()
        expires_at = (
            datetime.now() + timedelta(minutes=5)
        ).isoformat()

        cursor.execute(
            """
            INSERT INTO login_otps (
                user_id,
                otp_hash,
                expires_at,
                attempts,
                used
            )
            VALUES (?, ?, ?, 0, 0)
            """,
            (
                user["id"],
                otp_hash,
                expires_at,
            ),
        )

        connection.commit()
        connection.close()
        connection = None

        email_sent = send_login_otp_email(
            recipient_email=recipient_email,
            full_name=user["full_name"],
            otp=otp,
        )

        if not email_sent:
            # Do not leave a valid OTP active if the email could not be sent.
            cleanup_connection = get_database_connection()
            cleanup_cursor = cleanup_connection.cursor()
            cleanup_cursor.execute(
                """
                UPDATE login_otps
                SET used = 1
                WHERE user_id = ?
                  AND used = 0
                """,
                (user["id"],),
            )
            cleanup_connection.commit()
            cleanup_connection.close()

            return {
                "success": False,
                "message": "Unable to send OTP email. Please try again.",
            }

        print(
            f"LOGIN OTP GENERATED | User ID: {user['id']} | "
            f"Email: {recipient_email}"
        )

        return {
            "success": True,
            "message": "OTP sent successfully to your registered email address.",
        }

    except Exception as e:
        if connection is not None:
            connection.close()

        print(
            "SEND OTP ERROR:",
            str(e),
        )

        return {
            "success": False,
            "message": "Unable to send OTP.",
            "error": str(e),
        }


# ============================================================
# VERIFY LOGIN OTP API
# ============================================================

@app.post("/verify-otp")
def verify_login_otp(
    request: VerifyOTPRequest,
):

    connection = None

    try:
        identifier = request.identifier.strip()
        otp = request.otp.strip()

        if not identifier:
            return {
                "success": False,
                "message": "User ID or phone number is required.",
            }

        if not otp:
            return {
                "success": False,
                "message": "OTP is required.",
            }

        if not otp.isdigit() or len(otp) != 6:
            return {
                "success": False,
                "message": "Enter a valid 6-digit OTP.",
            }

        connection = get_database_connection()
        cursor = connection.cursor()

        identifier_type, lookup_value = normalize_otp_identifier(identifier)

        connection = get_database_connection()
        cursor = connection.cursor()

        if identifier_type == "phone":
            cursor.execute(
                """
                SELECT
                    id,
                    driver_id,
                    full_name,
                    email,
                    phone,
                    driving_license,
                    role,
                    admin_status
                FROM users
                WHERE phone = ?
                LIMIT 1
                """,
                (lookup_value,),
            )
        elif identifier_type == "email":
            cursor.execute(
                """
                SELECT
                    id,
                    driver_id,
                    full_name,
                    email,
                    phone,
                    driving_license,
                    role,
                    admin_status
                FROM users
                WHERE LOWER(email) = LOWER(?)
                LIMIT 1
                """,
                (lookup_value,),
            )
        else:
            cursor.execute(
                """
                SELECT
                    id,
                    driver_id,
                    full_name,
                    email,
                    phone,
                    driving_license,
                    role,
                    admin_status
                FROM users
                WHERE LOWER(driver_id) = LOWER(?)
                LIMIT 1
                """,
                (lookup_value,),
            )

        user = cursor.fetchone()

        if user is None:
            connection.close()
            connection = None
            return {
                "success": False,
                "message": "Account not found.",
            }

        if (
            (user["role"] or "user").lower() == "admin"
            and (user["admin_status"] or "approved") != "approved"
        ):
            connection.close()
            connection = None
            return {
                "success": False,
                "message": "This admin account is not approved.",
            }

        cursor.execute(
            """
            SELECT
                id,
                otp_hash,
                expires_at,
                attempts,
                used
            FROM login_otps
            WHERE user_id = ?
              AND used = 0
            ORDER BY id DESC
            LIMIT 1
            """,
            (user["id"],),
        )

        otp_record = cursor.fetchone()

        if otp_record is None:
            connection.close()
            connection = None
            return {
                "success": False,
                "message": "No active OTP found. Please request a new OTP.",
            }

        if otp_record["attempts"] >= 5:
            cursor.execute(
                "UPDATE login_otps SET used = 1 WHERE id = ?",
                (otp_record["id"],),
            )
            connection.commit()
            connection.close()
            connection = None
            return {
                "success": False,
                "message": "Too many incorrect attempts. Please request a new OTP.",
            }

        try:
            expires_at = datetime.fromisoformat(
                otp_record["expires_at"]
            )
        except (TypeError, ValueError):
            cursor.execute(
                "UPDATE login_otps SET used = 1 WHERE id = ?",
                (otp_record["id"],),
            )
            connection.commit()
            connection.close()
            connection = None
            return {
                "success": False,
                "message": "OTP is invalid. Please request a new OTP.",
            }

        if datetime.now() > expires_at:
            cursor.execute(
                "UPDATE login_otps SET used = 1 WHERE id = ?",
                (otp_record["id"],),
            )
            connection.commit()
            connection.close()
            connection = None
            return {
                "success": False,
                "message": "OTP has expired. Please request a new OTP.",
            }

        entered_otp_hash = hashlib.sha256(
            otp.encode("utf-8")
        ).hexdigest()

        if entered_otp_hash != otp_record["otp_hash"]:
            cursor.execute(
                """
                UPDATE login_otps
                SET attempts = attempts + 1
                WHERE id = ?
                """,
                (otp_record["id"],),
            )
            connection.commit()

            attempts_used = otp_record["attempts"] + 1
            remaining_attempts = max(5 - attempts_used, 0)

            connection.close()
            connection = None

            return {
                "success": False,
                "message": (
                    "Invalid OTP. "
                    f"{remaining_attempts} attempts remaining."
                ),
            }

        # OTP is valid. Mark it as used before returning success.
        cursor.execute(
            "UPDATE login_otps SET used = 1 WHERE id = ?",
            (otp_record["id"],),
        )
        connection.commit()
        connection.close()
        connection = None

        print(
            f"OTP LOGIN SUCCESS | ID: {user['id']} | "
            f"Name: {user['full_name']} | "
            f"Email: {user['email']} | "
            f"Phone: {user['phone']} | "
            f"Role: {user['role']}"
        )

        return {
            "success": True,
            "message": "OTP verified successfully. Login successful.",
            "driver_id": user["driver_id"],
            "account_id": user["driver_id"],
            "user": {
                "id": user["id"],
                "driver_id": user["driver_id"],
                "full_name": user["full_name"],
                "email": user["email"],
                "phone": user["phone"],
                "driving_license": user["driving_license"],
                "role": user["role"],
                "admin_status": user["admin_status"],
            },
        }

    except Exception as e:
        if connection is not None:
            connection.close()

        print(
            "VERIFY OTP ERROR:",
            str(e),
        )

        return {
            "success": False,
            "message": "Unable to verify OTP.",
            "error": str(e),
        }


# ============================================================
# FORGOT PASSWORD API
# ============================================================

@app.post("/forgot-password")
def forgot_password(
    request: ForgotPasswordRequest
):

    connection = None

    try:

        email = (
            request.email.strip().lower()
        )

        # ----------------------------------------------------
        # DATABASE CONNECTION
        # ----------------------------------------------------

        connection = (
            get_database_connection()
        )

        cursor = connection.cursor()

        # ----------------------------------------------------
        # FIND USER
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT
                id,
                full_name,
                email
            FROM users
            WHERE LOWER(email) = LOWER(?)
            """,
            (email,)
        )

        user = cursor.fetchone()

        # ----------------------------------------------------
        # SECURITY:
        # DON'T REVEAL WHETHER EMAIL EXISTS
        # ----------------------------------------------------

        if user is None:

            connection.close()

            return {
                "success": True,
                "message":
                    "If an account exists with this email, "
                    "a password reset link has been sent."
            }

        # ----------------------------------------------------
        # GENERATE SECURE RANDOM TOKEN
        # ----------------------------------------------------

        reset_token = (
            secrets.token_urlsafe(32)
        )

        # ----------------------------------------------------
        # HASH TOKEN BEFORE DATABASE STORAGE
        # ----------------------------------------------------

        reset_token_hash = (
            hashlib.sha256(
                reset_token.encode(
                    "utf-8"
                )
            ).hexdigest()
        )

        # ----------------------------------------------------
        # TOKEN EXPIRY
        # 30 MINUTES
        # ----------------------------------------------------

        expiry_time = (
            datetime.now()
            + timedelta(minutes=30)
        )

        # ----------------------------------------------------
        # SAVE TOKEN
        # ----------------------------------------------------

        cursor.execute(
            """
            UPDATE users
            SET
                reset_token_hash = ?,
                reset_token_expires_at = ?,
                reset_token_used = 0
            WHERE id = ?
            """,
            (
                reset_token_hash,
                expiry_time.isoformat(),
                user["id"],
            )
        )

        connection.commit()

        connection.close()

        connection = None

        # ----------------------------------------------------
        # SEND EMAIL
        # ----------------------------------------------------

        email_sent = (
            send_password_reset_email(
                recipient_email=user["email"],
                full_name=user["full_name"],
                reset_token=reset_token,
            )
        )

        # ----------------------------------------------------
        # EMAIL FAILURE
        # ----------------------------------------------------

        if not email_sent:

            print(
                f"RESET EMAIL FAILED | "
                f"Email: {email}"
            )

            return {
                "success": False,
                "message":
                    "Unable to send reset link. "
                    "Please check email configuration."
            }

        # ----------------------------------------------------
        # SUCCESS
        # ----------------------------------------------------

        print(
            f"PASSWORD RESET REQUESTED | "
            f"User ID: {user['id']} | "
            f"Email: {user['email']} | "
            f"Expires: {expiry_time}"
        )

        return {
            "success": True,
            "message":
                "Password reset link sent successfully."
        }

    except Exception as e:

        if connection is not None:

            connection.close()

        print(
            "FORGOT PASSWORD ERROR:",
            str(e)
        )

        return {
            "success": False,
            "message":
                "Unable to process password reset request."
        }


# ============================================================
# RESET PASSWORD PAGE
# ============================================================

@app.get(
    "/reset-password",
    response_class=HTMLResponse
)
def reset_password_page(
    token: str
):

    try:

        # ----------------------------------------------------
        # HASH TOKEN
        # ----------------------------------------------------

        token_hash = (
            hashlib.sha256(
                token.encode("utf-8")
            ).hexdigest()
        )

        connection = (
            get_database_connection()
        )

        cursor = connection.cursor()

        # ----------------------------------------------------
        # FIND VALID TOKEN
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT
                id,
                full_name,
                reset_token_expires_at,
                reset_token_used
            FROM users
            WHERE reset_token_hash = ?
            """,
            (token_hash,)
        )

        user = cursor.fetchone()

        connection.close()

        # ----------------------------------------------------
        # INVALID TOKEN
        # ----------------------------------------------------

        if user is None:

            return HTMLResponse(
                content="""
                <html>
                    <head>
                        <title>Invalid Reset Link</title>
                    </head>
                    <body style="
                        font-family: Arial;
                        text-align: center;
                        padding: 60px;
                        background: #08111F;
                        color: white;
                    ">
                        <h1>Invalid Reset Link</h1>
                        <p>
                            This password reset link is invalid
                            or has already been used.
                        </p>
                    </body>
                </html>
                """,
                status_code=400,
            )

        # ----------------------------------------------------
        # CHECK USED
        # ----------------------------------------------------

        if user["reset_token_used"] == 1:

            return HTMLResponse(
                content="""
                <html>
                    <head>
                        <title>Reset Link Used</title>
                    </head>
                    <body style="
                        font-family: Arial;
                        text-align: center;
                        padding: 60px;
                        background: #08111F;
                        color: white;
                    ">
                        <h1>Reset Link Already Used</h1>
                        <p>
                            Please request a new password reset link.
                        </p>
                    </body>
                </html>
                """,
                status_code=400,
            )

        # ----------------------------------------------------
        # CHECK EXPIRY
        # ----------------------------------------------------

        expiry = datetime.fromisoformat(
            user["reset_token_expires_at"]
        )

        if datetime.now() > expiry:

            return HTMLResponse(
                content="""
                <html>
                    <head>
                        <title>Reset Link Expired</title>
                    </head>
                    <body style="
                        font-family: Arial;
                        text-align: center;
                        padding: 60px;
                        background: #08111F;
                        color: white;
                    ">
                        <h1>Reset Link Expired</h1>
                        <p>
                            This password reset link has expired.
                            Please request a new one.
                        </p>
                    </body>
                </html>
                """,
                status_code=400,
            )

        # ----------------------------------------------------
        # ESCAPE NAME
        # ----------------------------------------------------

        safe_name = html.escape(
            user["full_name"]
        )

        # ----------------------------------------------------
        # SHOW RESET FORM
        # ----------------------------------------------------

        return HTMLResponse(
            content=f"""
            <!DOCTYPE html>

            <html>

            <head>

                <title>
                    Driver Safety AI - Reset Password
                </title>

                <meta
                    name="viewport"
                    content="width=device-width,
                    initial-scale=1.0"
                >

                <style>

                    body {{
                        margin: 0;
                        padding: 0;

                        font-family:
                            Arial,
                            sans-serif;

                        background:
                            linear-gradient(
                                135deg,
                                #08111F,
                                #10233D
                            );

                        min-height: 100vh;

                        display: flex;

                        align-items: center;

                        justify-content: center;

                        color: white;
                    }}

                    .container {{
                        width: 90%;
                        max-width: 450px;

                        background:
                            #1B2A41;

                        padding: 35px;

                        border-radius: 20px;

                        box-shadow:
                            0 20px 50px
                            rgba(
                                0,
                                0,
                                0,
                                0.35
                            );
                    }}

                    h1 {{
                        text-align: center;

                        margin-bottom: 10px;
                    }}

                    .welcome {{
                        text-align: center;

                        color: #B7C2D0;

                        margin-bottom: 30px;
                    }}

                    label {{
                        display: block;

                        margin-top: 18px;

                        margin-bottom: 8px;

                        font-weight: bold;
                    }}

                    input {{
                        width: 100%;

                        box-sizing: border-box;

                        padding: 15px;

                        border-radius: 10px;

                        border:
                            1px solid
                            rgba(
                                255,
                                255,
                                255,
                                0.1
                            );

                        background: #293A54;

                        color: white;

                        font-size: 15px;

                        outline: none;
                    }}

                    input:focus {{
                        border-color:
                            #00E5FF;
                    }}

                    button {{
                        width: 100%;

                        margin-top: 28px;

                        padding: 15px;

                        border: none;

                        border-radius: 10px;

                        background:
                            #00E5FF;

                        color: black;

                        font-size: 16px;

                        font-weight: bold;

                        cursor: pointer;
                    }}

                    button:hover {{
                        background:
                            #00C2FF;
                    }}

                    .requirements {{
                        margin-top: 20px;

                        padding: 15px;

                        background:
                            #173650;

                        border-radius: 10px;

                        color: #B7C2D0;

                        font-size: 13px;

                        line-height: 1.7;
                    }}

                </style>

            </head>

            <body>

                <div class="container">

                    <h1>
                        Reset Password
                    </h1>

                    <div class="welcome">
                        Hello {safe_name}!<br>
                        Create your new password below.
                    </div>

                    <form
                        method="POST"
                        action="/reset-password"
                    >

                        <input
                            type="hidden"
                            name="token"
                            value="{html.escape(token)}"
                        >

                        <label>
                            New Password
                        </label>

                        <input
                            type="password"
                            name="password"
                            required
                            minlength="8"
                            placeholder="Enter new password"
                        >

                        <label>
                            Confirm Password
                        </label>

                        <input
                            type="password"
                            name="confirm_password"
                            required
                            minlength="8"
                            placeholder="Confirm new password"
                        >

                        <div class="requirements">

                            Password requirements:

                            <br>
                            ✓ At least 8 characters

                            <br>
                            ✓ At least one uppercase letter

                            <br>
                            ✓ At least one lowercase letter

                            <br>
                            ✓ At least one number

                            <br>
                            ✓ At least one special character

                        </div>

                        <button type="submit">
                            Reset Password
                        </button>

                    </form>

                </div>

            </body>

            </html>
            """
        )

    except Exception as e:

        print(
            "RESET PAGE ERROR:",
            str(e)
        )

        return HTMLResponse(
            content="""
            <h1>
                Unable to process reset link.
            </h1>
            """,
            status_code=500,
        )


# ============================================================
# RESET PASSWORD API / FORM
# ============================================================

@app.post(
    "/reset-password",
    response_class=HTMLResponse
)
def reset_password(
    token: str = Form(...),
    password: str = Form(...),
    confirm_password: str = Form(...),
):

    connection = None

    try:

        # ----------------------------------------------------
        # CHECK PASSWORD MATCH
        # ----------------------------------------------------

        if password != confirm_password:

            return HTMLResponse(
                content="""
                <html>

                <body style="
                    font-family: Arial;
                    text-align: center;
                    padding: 60px;
                    background: #08111F;
                    color: white;
                ">

                    <h1>
                        Passwords Do Not Match
                    </h1>

                    <p>
                        Please go back and enter
                        the same password.
                    </p>

                    <button
                        onclick="history.back()"
                    >
                        Go Back
                    </button>

                </body>

                </html>
                """,
                status_code=400,
            )

        # ----------------------------------------------------
        # VALIDATE PASSWORD
        # ----------------------------------------------------

        password_valid, password_message = (
            validate_password(password)
        )

        if not password_valid:

            safe_message = html.escape(
                password_message
            )

            return HTMLResponse(
                content=f"""
                <html>

                <body style="
                    font-family: Arial;
                    text-align: center;
                    padding: 60px;
                    background: #08111F;
                    color: white;
                ">

                    <h1>
                        Invalid Password
                    </h1>

                    <p>
                        {safe_message}
                    </p>

                    <button
                        onclick="history.back()"
                    >
                        Go Back
                    </button>

                </body>

                </html>
                """,
                status_code=400,
            )

        # ----------------------------------------------------
        # HASH TOKEN
        # ----------------------------------------------------

        token_hash = (
            hashlib.sha256(
                token.encode("utf-8")
            ).hexdigest()
        )

        # ----------------------------------------------------
        # DATABASE
        # ----------------------------------------------------

        connection = (
            get_database_connection()
        )

        cursor = connection.cursor()

        # ----------------------------------------------------
        # FIND USER
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT
                id,
                reset_token_expires_at,
                reset_token_used
            FROM users
            WHERE reset_token_hash = ?
            """,
            (token_hash,)
        )

        user = cursor.fetchone()

        # ----------------------------------------------------
        # TOKEN NOT FOUND
        # ----------------------------------------------------

        if user is None:

            connection.close()

            return HTMLResponse(
                content="""
                <html>

                <body style="
                    font-family: Arial;
                    text-align: center;
                    padding: 60px;
                    background: #08111F;
                    color: white;
                ">

                    <h1>
                        Invalid Reset Link
                    </h1>

                    <p>
                        Please request a new
                        password reset link.
                    </p>

                </body>

                </html>
                """,
                status_code=400,
            )

        # ----------------------------------------------------
        # CHECK USED
        # ----------------------------------------------------

        if user["reset_token_used"] == 1:

            connection.close()

            return HTMLResponse(
                content="""
                <html>

                <body style="
                    font-family: Arial;
                    text-align: center;
                    padding: 60px;
                    background: #08111F;
                    color: white;
                ">

                    <h1>
                        Reset Link Already Used
                    </h1>

                    <p>
                        Please request a new
                        password reset link.
                    </p>

                </body>

                </html>
                """,
                status_code=400,
            )

        # ----------------------------------------------------
        # CHECK EXPIRY
        # ----------------------------------------------------

        expiry = datetime.fromisoformat(
            user["reset_token_expires_at"]
        )

        if datetime.now() > expiry:

            connection.close()

            return HTMLResponse(
                content="""
                <html>

                <body style="
                    font-family: Arial;
                    text-align: center;
                    padding: 60px;
                    background: #08111F;
                    color: white;
                ">

                    <h1>
                        Reset Link Expired
                    </h1>

                    <p>
                        Please request a new
                        password reset link.
                    </p>

                </body>

                </html>
                """,
                status_code=400,
            )

        # ----------------------------------------------------
        # HASH NEW PASSWORD
        # ----------------------------------------------------

        new_password_hash = (
            hash_password(password)
        )

        # ----------------------------------------------------
        # UPDATE PASSWORD
        # ----------------------------------------------------

        cursor.execute(
            """
            UPDATE users
            SET
                password_hash = ?,
                reset_token_hash = NULL,
                reset_token_expires_at = NULL,
                reset_token_used = 1
            WHERE id = ?
            """,
            (
                new_password_hash,
                user["id"],
            )
        )

        connection.commit()

        connection.close()

        connection = None

        # ----------------------------------------------------
        # PASSWORD RESET SUCCESS
        # ----------------------------------------------------

        print(
            f"PASSWORD RESET SUCCESS | "
            f"User ID: {user['id']}"
        )

        return HTMLResponse(
            content="""
            <!DOCTYPE html>

            <html>

            <head>

                <title>
                    Password Reset Successful
                </title>

                <meta
                    name="viewport"
                    content="width=device-width,
                    initial-scale=1.0"
                >

            </head>

            <body style="
                margin: 0;
                padding: 0;

                min-height: 100vh;

                display: flex;

                align-items: center;

                justify-content: center;

                font-family: Arial;

                background:
                    linear-gradient(
                        135deg,
                        #08111F,
                        #10233D
                    );

                color: white;
            ">

                <div style="
                    width: 90%;
                    max-width: 450px;

                    padding: 40px;

                    text-align: center;

                    background: #1B2A41;

                    border-radius: 20px;

                    box-shadow:
                        0 20px 50px
                        rgba(
                            0,
                            0,
                            0,
                            0.35
                        );
                ">

                    <h1>
                        Password Reset Successful
                    </h1>

                    <p style="
                        color: #B7C2D0;
                        line-height: 1.6;
                    ">

                        Your password has been
                        successfully updated.

                    </p>

                    <p style="
                        color: #00E5FF;
                        font-weight: bold;
                    ">

                        You can now return to
                        Driver Safety AI and log in
                        with your new password.

                    </p>

                </div>

            </body>

            </html>
            """
        )

    except Exception as e:

        if connection is not None:

            connection.close()

        print(
            "RESET PASSWORD ERROR:",
            str(e)
        )

        return HTMLResponse(
            content="""
            <h1>
                Unable to reset password.
            </h1>
            """,
            status_code=500,
        )


# ============================================================
# DRIVER DETECTION API
# ============================================================

# ============================================================
# DRIVER ALERT SMS - MSG91
# ============================================================

class DriverAlertSmsRequest(BaseModel):

    account_id: str
    rule_name: str
    severity: str
    message: str
    timestamp: str | None = None


def send_msg91_driver_alert_sms(
    phone: str,
    rule_name: str,
    severity: str,
    alert_message: str,
    timestamp: str,
) -> tuple[bool, str]:
    """Send one Driver Safety AI alert SMS through the configured MSG91 Flow."""

    if not MSG91_AUTHKEY:
        return False, "MSG91_AUTHKEY is not configured."

    if not MSG91_FLOW_ID:
        return False, "MSG91_FLOW_ID is not configured."

    if not MSG91_SENDER_ID:
        return False, "MSG91_SENDER_ID is not configured."

    cleaned_phone = re.sub(r"[^0-9]", "", phone or "")

    # Registered Indian phone numbers are stored as 10 digits by
    # validate_phone(). MSG91 requires the mobile number in international
    # format for the Flow API, so add India's country code here.
    if not re.fullmatch(r"[6-9][0-9]{9}", cleaned_phone):
        return False, "Registered driver phone number is invalid."

    mobile_number = f"91{cleaned_phone}"

    payload = {
        "flow_id": MSG91_FLOW_ID,
        "sender": MSG91_SENDER_ID,
        "recipients": [
            {
                "mobiles": mobile_number,
                "VAR1": rule_name,
                "VAR2": severity,
                "VAR3": alert_message,
                "VAR4": timestamp or "Not available",
            }
        ],
    }

    request = urllib.request.Request(
        MSG91_SMS_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "accept": "application/json",
            "authkey": MSG91_AUTHKEY,
            "content-type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            response_body = response.read().decode("utf-8", errors="replace")
            status_code = response.status

        try:
            response_json = json.loads(response_body)
        except json.JSONDecodeError:
            response_json = {}

        response_type = str(response_json.get("type", "")).strip().lower()
        if status_code < 200 or status_code >= 300 or response_type == "error":
            error_message = (
                response_json.get("message")
                or response_body
                or "MSG91 rejected the SMS request."
            )
            return False, str(error_message)

        request_id = response_json.get("message") or response_json.get("request_id") or ""
        return True, str(request_id)

    except urllib.error.HTTPError as e:
        try:
            error_body = e.read().decode("utf-8", errors="replace")
            error_json = json.loads(error_body)
            error_message = error_json.get("message") or error_body
        except Exception:
            error_message = str(e)

        return False, str(error_message)

    except urllib.error.URLError as e:
        return False, f"MSG91 connection error: {e.reason}"

    except Exception as e:
        return False, f"MSG91 SMS error: {e}"


@app.post("/alerts/sms")
def send_driver_alert_sms(
    request: DriverAlertSmsRequest
):

    connection = None

    try:
        account_id = request.account_id.strip()

        if not account_id:
            return {
                "success": False,
                "message": "Account ID is required.",
            }

        # ----------------------------------------------------
        # FIND REGISTERED DRIVER
        # ----------------------------------------------------

        connection = get_database_connection()
        cursor = connection.cursor()

        cursor.execute(
            """
            SELECT
                full_name,
                phone,
                driver_id
            FROM users
            WHERE LOWER(driver_id) = LOWER(?)
            LIMIT 1
            """,
            (account_id,),
        )

        user = cursor.fetchone()
        connection.close()
        connection = None

        if user is None:
            return {
                "success": False,
                "message": "Registered driver account not found.",
            }

        recipient_phone = (user["phone"] or "").strip()

        if not recipient_phone:
            return {
                "success": False,
                "message": "Registered driver phone number is not available.",
            }

        full_name = user["full_name"] or "Driver"
        severity = request.severity.strip().upper() or "ALERT"
        rule_name = request.rule_name.strip() or "Driver Safety Alert"
        alert_message = request.message.strip() or "A driver safety alert was detected."
        timestamp = (request.timestamp or "").strip()

        # Normalize dynamic values before sending them to the provider.
        full_name = " ".join(full_name.replace("\u00a0", " ").split())
        severity = " ".join(severity.replace("\u00a0", " ").split())
        rule_name = " ".join(rule_name.replace("\u00a0", " ").split())
        alert_message = alert_message.replace("\u00a0", " ").strip()
        timestamp = timestamp.replace("\u00a0", " ").strip()
        account_id = account_id.replace("\u00a0", " ").strip()

        sms_sent, provider_result = send_msg91_driver_alert_sms(
            phone=recipient_phone,
            rule_name=rule_name,
            severity=severity,
            alert_message=alert_message,
            timestamp=timestamp,
        )

        if not sms_sent:
            print(
                "DRIVER ALERT SMS ERROR | "
                f"Account ID: {account_id} | "
                f"Severity: {severity} | "
                f"Rule: {rule_name} | "
                f"Reason: {provider_result}"
            )

            return {
                "success": False,
                "message": "Alert SMS could not be sent.",
                "error": provider_result,
            }

        print(
            "DRIVER ALERT SMS SENT | "
            f"Account ID: {account_id} | "
            f"Phone: ******{recipient_phone[-4:]} | "
            f"Severity: {severity} | "
            f"Rule: {rule_name} | "
            f"MSG91 Request ID: {provider_result}"
        )

        return {
            "success": True,
            "message": "Alert SMS submitted successfully.",
            "account_id": account_id,
            "phone": f"******{recipient_phone[-4:]}",
            "provider": "MSG91",
            "request_id": provider_result,
        }

    except Exception as e:

        if connection is not None:
            connection.close()

        print(
            "DRIVER ALERT SMS ERROR:",
            str(e),
        )

        return {
            "success": False,
            "message": "An error occurred while sending the alert SMS.",
        }


# ============================================================
# DRIVER ALERT EMAIL
# ============================================================

class DriverAlertEmailRequest(BaseModel):

    account_id: str
    rule_name: str
    severity: str
    message: str
    timestamp: str | None = None


@app.post("/alerts/email")
def send_driver_alert_email(
    request: DriverAlertEmailRequest
):

    connection = None

    try:

        account_id = request.account_id.strip()

        if not account_id:
            return {
                "success": False,
                "message": "Account ID is required.",
            }

        # ----------------------------------------------------
        # FIND REGISTERED DRIVER
        # ----------------------------------------------------

        connection = get_database_connection()
        cursor = connection.cursor()

        cursor.execute(
            """
            SELECT
                full_name,
                email,
                driver_id
            FROM users
            WHERE LOWER(driver_id) = LOWER(?)
            LIMIT 1
            """,
            (account_id,),
        )

        user = cursor.fetchone()
        connection.close()
        connection = None

        if user is None:
            return {
                "success": False,
                "message": "Registered driver account not found.",
            }

        recipient_email = (user["email"] or "").strip()

        if not recipient_email:
            return {
                "success": False,
                "message": "Registered driver email is not available.",
            }

        full_name = user["full_name"] or "Driver"
        severity = request.severity.strip().upper() or "ALERT"
        rule_name = request.rule_name.strip() or "Driver Safety Alert"
        alert_message = request.message.strip() or "A driver safety alert was detected."
        timestamp = (request.timestamp or "").strip()

        # Normalize dynamic email values so hidden Unicode whitespace
        # (for example, a non-breaking space) cannot break SMTP encoding.
        full_name = " ".join(full_name.replace("\u00a0", " ").split())
        severity = " ".join(severity.replace("\u00a0", " ").split())
        rule_name = " ".join(rule_name.replace("\u00a0", " ").split())
        alert_message = alert_message.replace("\u00a0", " ")
        timestamp = timestamp.replace("\u00a0", " ")
        account_id = account_id.replace("\u00a0", " ").strip()
        recipient_email = recipient_email.replace("\u00a0", "").strip()

        message = EmailMessage(policy=SMTPPolicy)
        message["Subject"] = (
            f"Driver Safety AI - {severity} Alert - {rule_name}"
        )
        message["From"] = SMTP_EMAIL.strip()
        message["To"] = recipient_email

        message.set_content(
            f"""Hello {full_name},

Driver Safety AI detected a safety alert during your ride.

Alert: {rule_name}
Severity: {severity}
Message: {alert_message}
Time: {timestamp or "Not available"}
Account ID: {account_id}

Please take the appropriate safety action immediately.

Regards,
Driver Safety AI Team
"""
        )

        email_sent = send_email(message)

        if not email_sent:
            return {
                "success": False,
                "message": "Alert email could not be sent.",
            }

        print(
            "DRIVER ALERT EMAIL SENT | "
            f"Account ID: {account_id} | "
            f"Email: {recipient_email} | "
            f"Severity: {severity} | "
            f"Rule: {rule_name}"
        )

        return {
            "success": True,
            "message": "Alert email sent successfully.",
            "account_id": account_id,
            "email": recipient_email,
        }

    except Exception as e:

        if connection is not None:
            connection.close()

        print(
            "DRIVER ALERT EMAIL ERROR:",
            str(e),
        )

        return {
            "success": False,
            "message": "An error occurred while sending the alert email.",
        }



# ============================================================
# EMERGENCY CONTACT EMAIL
# ============================================================

class EmergencyAlertEmailRequest(BaseModel):

    account_id: str
    status: str
    timestamp: str | None = None
    latitude: str | None = None
    longitude: str | None = None
    accuracy: str | None = None
    google_maps_link: str | None = None
    alert_message: str | None = None


@app.post("/emergency-alert/email")
def send_emergency_alert_email(
    request: EmergencyAlertEmailRequest
):

    connection = None

    try:

        account_id = request.account_id.strip()

        if not account_id:
            return {
                "success": False,
                "message": "Account ID is required.",
            }

        # ----------------------------------------------------
        # FIND DRIVER + SAVED EMERGENCY CONTACT
        # ----------------------------------------------------

        connection = get_database_connection()
        cursor = connection.cursor()

        cursor.execute(
            """
            SELECT
                u.id,
                u.full_name,
                u.driver_id,
                p.vehicle_number,
                p.vehicle_type,
                p.emergency_contact_name,
                p.emergency_contact_email
            FROM users u
            LEFT JOIN driver_profiles p
                ON u.id = p.user_id
            WHERE LOWER(u.driver_id) = LOWER(?)
            LIMIT 1
            """,
            (account_id,),
        )

        driver = cursor.fetchone()

        connection.close()
        connection = None

        if driver is None:
            return {
                "success": False,
                "message": "Driver account not found.",
            }

        driver_name = (
            driver["full_name"] or "Driver"
        ).strip()

        driver_id = (
            driver["driver_id"] or account_id
        ).strip()

        vehicle_number = (
            driver["vehicle_number"] or "Not available"
        ).strip()

        vehicle_type = (
            driver["vehicle_type"] or "Not available"
        ).strip()

        emergency_contact_name = (
            driver["emergency_contact_name"] or ""
        ).strip()

        emergency_contact_email = (
            driver["emergency_contact_email"] or ""
        ).strip()

        if not emergency_contact_email:
            return {
                "success": False,
                "message": "Emergency contact email is not available.",
            }

        # ----------------------------------------------------
        # PREPARE ALERT INFORMATION
        # ----------------------------------------------------

        status = (
            request.status or "EMERGENCY"
        ).strip().upper()

        timestamp = (
            request.timestamp or "Not available"
        ).strip()

        latitude = (
            request.latitude or "Not available"
        ).strip()

        longitude = (
            request.longitude or "Not available"
        ).strip()

        accuracy = (
            request.accuracy or "Not available"
        ).strip()

        google_maps_link = (
            request.google_maps_link or "Not available"
        ).strip()

        alert_message = (
            request.alert_message
            or "An emergency condition has been detected for the driver."
        ).strip()

        # ----------------------------------------------------
        # NORMALIZE EMAIL VALUES
        # ----------------------------------------------------

        driver_name = " ".join(
            driver_name.replace("\u00a0", " ").split()
        )

        driver_id = " ".join(
            driver_id.replace("\u00a0", " ").split()
        )

        vehicle_number = " ".join(
            vehicle_number.replace("\u00a0", " ").split()
        )

        vehicle_type = " ".join(
            vehicle_type.replace("\u00a0", " ").split()
        )

        emergency_contact_name = " ".join(
            emergency_contact_name.replace("\u00a0", " ").split()
        )

        emergency_contact_email = (
            emergency_contact_email
            .replace("\u00a0", "")
            .strip()
        )

        status = " ".join(
            status.replace("\u00a0", " ").split()
        )

        timestamp = (
            timestamp.replace("\u00a0", " ").strip()
        )

        latitude = (
            latitude.replace("\u00a0", " ").strip()
        )

        longitude = (
            longitude.replace("\u00a0", " ").strip()
        )

        accuracy = (
            accuracy.replace("\u00a0", " ").strip()
        )

        google_maps_link = (
            google_maps_link.replace("\u00a0", " ").strip()
        )

        alert_message = (
            alert_message.replace("\u00a0", " ").strip()
        )

        # ----------------------------------------------------
        # CREATE EMERGENCY EMAIL
        # ----------------------------------------------------

        message = EmailMessage(
            policy=SMTPPolicy
        )

        message["Subject"] = (
            "🚨 DRIVER SAFETY AI - EMERGENCY ALERT"
        )

        message["From"] = SMTP_EMAIL.strip()
        message["To"] = emergency_contact_email

        message.set_content(
            f"""DRIVER SAFETY AI
EMERGENCY ALERT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

An emergency condition has been detected
for the driver.

DRIVER INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Driver Name : {driver_name}
Account ID  : {driver_id}
Vehicle No. : {vehicle_number}
Vehicle Type: {vehicle_type}

EMERGENCY STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status      : {status}
Detected At : {timestamp}

CURRENT LOCATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Latitude    : {latitude}
Longitude   : {longitude}
Accuracy    : {accuracy} meters

Google Maps Location:
{google_maps_link}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{alert_message}

Please check the driver's condition
and provide assistance immediately.

This alert was generated automatically
by Driver Safety AI.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Driver Safety AI
Automated Emergency Alert System
"""
        )

        # ----------------------------------------------------
        # SEND EMAIL THROUGH EXISTING SMTP HELPER
        # ----------------------------------------------------

        email_sent = send_email(message)

        if not email_sent:
            return {
                "success": False,
                "message": "Emergency email could not be sent.",
            }

        print(
            "EMERGENCY EMAIL SENT | "
            f"Account ID: {driver_id} | "
            f"Email: {emergency_contact_email} | "
            f"Status: {status}"
        )

        return {
            "success": True,
            "message": "Emergency alert email sent successfully.",
            "account_id": driver_id,
            "status": status,
        }

    except Exception as e:

        if connection is not None:
            connection.close()

        print(
            "EMERGENCY EMAIL ERROR:",
            str(e),
        )

        return {
            "success": False,
            "message": (
                "An error occurred while sending "
                "the emergency email."
            ),
        }

@app.post("/detect")
async def detect_driver(
    file: UploadFile = File(...)
):

    try:

        # ----------------------------------------------------
        # READ IMAGE
        # ----------------------------------------------------

        image_bytes = await file.read()

        if not image_bytes:

            return {
                "error":
                    "Empty image received"
            }

        # ----------------------------------------------------
        # CONVERT IMAGE BYTES -> NUMPY ARRAY
        # ----------------------------------------------------

        np_array = np.frombuffer(
            image_bytes,
            np.uint8
        )

        # ----------------------------------------------------
        # DECODE IMAGE
        # ----------------------------------------------------

        frame = cv2.imdecode(
            np_array,
            cv2.IMREAD_COLOR
        )

        if frame is None:

            return {
                "error":
                    "Unable to decode image"
            }

        # ----------------------------------------------------
        # RUN AI DETECTION
        # ----------------------------------------------------

        result = detect(frame)

        # ----------------------------------------------------
        # RETURN DETECTOR RESULT WITHOUT OVERRIDING AI OUTPUT
        # ----------------------------------------------------
        # The detector is the single source of truth for
        # face, eye, fatigue, head-position, and alert state.
        # The API layer must not convert a temporary face-loss
        # event into an independent fatigue/danger decision.
        # Alert escalation will be handled by the alert engine.

        # ----------------------------------------------------
        # PRINT API RESPONSE
        # ----------------------------------------------------

        print(
            "API RESPONSE:",
            result
        )

        # ----------------------------------------------------
        # RETURN RESULT TO FLUTTER
        # ----------------------------------------------------

        return result

    except Exception as e:

        print(
            "DETECTION ERROR:",
            str(e)
        )

        return {
            "error": str(e)
        }


# DRIVER SAFETY AI - EXTENDED PROFILE / FEEDBACK / SUPPORT /
# ADMIN EXPORT / RIDE REPORT FUNCTIONALITY
# ============================================================
# This section is additive. Existing routes and functionality above
# are intentionally preserved.

from fastapi.responses import FileResponse, StreamingResponse
from io import BytesIO

# PDF support is optional at import time so the backend can still start
# and all existing non-PDF features continue to work if reportlab is not
# installed yet. PDF endpoints return a clear dependency message until
# reportlab is installed in the backend virtual environment.
try:
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfgen import canvas
    from reportlab.lib.units import mm
    REPORTLAB_AVAILABLE = True
except ImportError:
    A4 = None
    canvas = None
    mm = None
    REPORTLAB_AVAILABLE = False


# ============================================================
# EXTENDED DATABASE INITIALIZATION
# ============================================================

def initialize_extended_database():
    connection = get_database_connection()
    cursor = connection.cursor()

    # Optional vehicle/emergency information. Driver name/email remain
    # sourced from the users table so they cannot become duplicated data.
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS driver_profiles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL UNIQUE,
            vehicle_number TEXT,
            vehicle_type TEXT,
            vehicle_model TEXT,
            vehicle_other_info TEXT,
            emergency_contact_name TEXT,
            emergency_contact_phone TEXT,
            emergency_contact_email TEXT,
            emergency_contact_relationship TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
        """
    )

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS rides (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ride_id TEXT NOT NULL UNIQUE,
            user_id INTEGER NOT NULL,
            start_time TEXT,
            end_time TEXT,
            start_location TEXT,
            end_location TEXT,
            distance_km REAL,
            duration_minutes REAL,
            route_info TEXT,
            gps_info TEXT,
            safety_events TEXT,
            alerts TEXT,
            ride_summary TEXT,
            report_email TEXT,
            report_sent INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
        """
    )

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS ratings_feedback (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            ride_id TEXT,
            rating INTEGER NOT NULL,
            feedback TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
        """
    )

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS support_tickets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ticket_id TEXT NOT NULL UNIQUE,
            user_id INTEGER NOT NULL,
            subject TEXT NOT NULL,
            status TEXT DEFAULT 'Open',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
        """
    )

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS support_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ticket_id TEXT NOT NULL,
            sender_type TEXT NOT NULL,
            sender_account_id TEXT,
            message TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (ticket_id) REFERENCES support_tickets(ticket_id) ON DELETE CASCADE
        )
        """
    )

    cursor.execute(
        "CREATE INDEX IF NOT EXISTS idx_rides_user_id ON rides(user_id)"
    )
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS idx_feedback_user_id ON ratings_feedback(user_id)"
    )
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS idx_support_user_id ON support_tickets(user_id)"
    )
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS idx_support_messages_ticket ON support_messages(ticket_id)"
    )

    connection.commit()
    connection.close()


initialize_extended_database()


# ============================================================
# EXTENDED REQUEST MODELS
# ============================================================

class DriverProfileRequest(BaseModel):
    account_id: str
    vehicle_number: str | None = None
    vehicle_type: str | None = None
    vehicle_model: str | None = None
    vehicle_other_info: str | None = None
    emergency_contact_name: str | None = None
    emergency_contact_phone: str | None = None
    emergency_contact_email: EmailStr | None = None
    emergency_contact_relationship: str | None = None


class RatingFeedbackRequest(BaseModel):
    account_id: str
    rating: int
    feedback: str | None = None
    ride_id: str | None = None


class SupportTicketRequest(BaseModel):
    account_id: str
    subject: str
    message: str


class SupportReplyRequest(BaseModel):
    admin_account_id: str
    ticket_id: str
    message: str
    status: str = "Replied"


class SupportUserReplyRequest(BaseModel):
    account_id: str
    ticket_id: str
    message: str


class AdminEditUserRequest(BaseModel):
    admin_account_id: str
    target_account_id: str
    full_name: str | None = None
    email: EmailStr | None = None
    phone: str | None = None
    driving_license: str | None = None
    role: str | None = None
    admin_status: str | None = None


class RideCompletionRequest(BaseModel):
    account_id: str
    ride_id: str | None = None
    start_time: str | None = None
    end_time: str | None = None
    start_location: str | None = None
    end_location: str | None = None
    distance_km: float | None = None
    duration_minutes: float | None = None
    route_info: str | None = None
    gps_info: str | None = None
    safety_events: str | None = None
    alerts: str | None = None
    ride_summary: str | None = None


# ============================================================
# EXTENDED HELPERS
# ============================================================

def _clean_extended_text(value):
    if value is None:
        return ""
    return " ".join(
        str(value).replace("\u00a0", " ").split()
    ).strip()


def _find_user_by_account_id(connection, account_id):
    cursor = connection.cursor()
    cursor.execute(
        """
        SELECT id, driver_id, full_name, email, phone,
               driving_license, role, admin_status, created_at
        FROM users
        WHERE LOWER(driver_id) = LOWER(?)
        LIMIT 1
        """,
        (_clean_extended_text(account_id),),
    )
    return cursor.fetchone()


def _generate_unique_ticket_id(connection):
    while True:
        ticket_id = "SUP-" + secrets.token_hex(4).upper()
        cursor = connection.cursor()
        cursor.execute(
            "SELECT 1 FROM support_tickets WHERE ticket_id = ? LIMIT 1",
            (ticket_id,),
        )
        if cursor.fetchone() is None:
            return ticket_id


def _generate_unique_ride_id(connection):
    while True:
        ride_id = "RIDE-" + secrets.token_hex(5).upper()
        cursor = connection.cursor()
        cursor.execute(
            "SELECT 1 FROM rides WHERE ride_id = ? LIMIT 1",
            (ride_id,),
        )
        if cursor.fetchone() is None:
            return ride_id


def _admin_required(admin_account_id):
    return verify_approved_admin(
        _clean_extended_text(admin_account_id)
    )


def _ensure_reportlab():
    if not REPORTLAB_AVAILABLE:
        raise RuntimeError(
            "PDF support requires reportlab. Install it with: python -m pip install reportlab"
        )


def _safe_pdf_value(value):
    value = _clean_extended_text(value)
    return value.encode("latin-1", "replace").decode("latin-1")


def generate_ride_pdf(ride, driver, profile):
    """Generate a PDF ride report and return its bytes."""
    _ensure_reportlab()
    buffer = BytesIO()
    pdf = canvas.Canvas(buffer, pagesize=A4)
    width, height = A4

    x = 18 * mm
    y = height - 20 * mm

    def write_line(label, value, gap=7 * mm):
        nonlocal y
        text = f"{label}: {_safe_pdf_value(value)}"
        pdf.drawString(x, y, text)
        y -= gap
        if y < 22 * mm:
            pdf.showPage()
            y = height - 20 * mm

    pdf.setTitle("Driver Safety AI - Ride Report")
    pdf.setFont("Helvetica-Bold", 16)
    pdf.drawString(x, y, "Driver Safety AI - Ride Report")
    y -= 11 * mm

    pdf.setFont("Helvetica", 10)
    write_line("Ride ID", ride["ride_id"])
    write_line("Driver Name", driver["full_name"])
    write_line("Account ID", driver["driver_id"] or "")
    write_line("Registered Email", driver["email"] or "")
    write_line("Vehicle Number", profile["vehicle_number"] if profile else "")
    write_line("Vehicle Type", profile["vehicle_type"] if profile else "")
    write_line("Vehicle Model", profile["vehicle_model"] if profile else "")
    write_line("Driving Licence", driver["driving_license"] or "")
    write_line("Ride Date", ride["created_at"] or "")
    write_line("Start Time", ride["start_time"] or "")
    write_line("End Time", ride["end_time"] or "")
    write_line("Start Location", ride["start_location"] or "")
    write_line("End Location", ride["end_location"] or "")
    write_line("Distance (km)", ride["distance_km"] or "")
    write_line("Duration (minutes)", ride["duration_minutes"] or "")
    write_line("Route", ride["route_info"] or "")
    write_line("GPS Information", ride["gps_info"] or "")
    write_line("Safety Events", ride["safety_events"] or "")
    write_line("Alerts", ride["alerts"] or "")
    write_line("Ride Summary", ride["ride_summary"] or "")

    pdf.setFont("Helvetica-Oblique", 9)
    y -= 4 * mm
    pdf.drawString(
        x,
        y,
        "Generated automatically by Driver Safety AI.",
    )

    pdf.save()
    buffer.seek(0)
    return buffer.getvalue()


def send_ride_report_email(recipient_email, full_name, ride_id, pdf_bytes):
    if not recipient_email:
        return False

    message = EmailMessage(policy=SMTPPolicy)
    message["Subject"] = "Driver Safety AI - Ride Report"
    message["From"] = SMTP_EMAIL.strip()
    message["To"] = recipient_email.replace("\u00a0", "").strip()

    message.set_content(
        f"""Hello {full_name or 'Driver'},

Your Driver Safety AI ride has been completed.

Ride ID: {ride_id}

Your ride report is attached as a PDF.

Regards,
Driver Safety AI Team
"""
    )

    message.add_attachment(
        pdf_bytes,
        maintype="application",
        subtype="pdf",
        filename=f"Ride_Report_{ride_id}.pdf",
    )

    return send_email(message)


# ============================================================
# PROFILE / EMERGENCY / VEHICLE APIs
# ============================================================

@app.get("/profile/details")
def get_profile_details(account_id: str = ""):
    connection = None
    try:
        connection = get_database_connection()
        user = _find_user_by_account_id(connection, account_id)
        if user is None:
            return {"success": False, "message": "Account not found."}

        cursor = connection.cursor()
        cursor.execute(
            "SELECT * FROM driver_profiles WHERE user_id = ? LIMIT 1",
            (user["id"],),
        )
        profile = cursor.fetchone()
        connection.close()

        return {
            "success": True,
            "profile": {
                "account_id": user["driver_id"] or "",
                "driver_name": user["full_name"] or "",
                "email": user["email"] or "",
                "phone": user["phone"] or "",
                "driving_license": user["driving_license"] or "",
                "vehicle_number": profile["vehicle_number"] if profile else "",
                "vehicle_type": profile["vehicle_type"] if profile else "",
                "vehicle_model": profile["vehicle_model"] if profile else "",
                "vehicle_other_info": profile["vehicle_other_info"] if profile else "",
                "emergency_contact_name": profile["emergency_contact_name"] if profile else "",
                "emergency_contact_phone": profile["emergency_contact_phone"] if profile else "",
                "emergency_contact_email": profile["emergency_contact_email"] if profile else "",
                "emergency_contact_relationship": profile["emergency_contact_relationship"] if profile else "",
            },
        }
    except Exception as e:
        if connection is not None:
            connection.close()
        print("PROFILE DETAILS ERROR:", str(e))
        return {"success": False, "message": "Unable to load profile details."}


@app.post("/profile/details")
def save_profile_details(request: DriverProfileRequest):
    connection = None
    try:
        connection = get_database_connection()
        user = _find_user_by_account_id(connection, request.account_id)
        if user is None:
            return {"success": False, "message": "Account not found."}

        cursor = connection.cursor()
        cursor.execute(
            """
            INSERT INTO driver_profiles (
                user_id, vehicle_number, vehicle_type, vehicle_model,
                vehicle_other_info, emergency_contact_name,
                emergency_contact_phone, emergency_contact_email,
                emergency_contact_relationship, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(user_id) DO UPDATE SET
                vehicle_number = excluded.vehicle_number,
                vehicle_type = excluded.vehicle_type,
                vehicle_model = excluded.vehicle_model,
                vehicle_other_info = excluded.vehicle_other_info,
                emergency_contact_name = excluded.emergency_contact_name,
                emergency_contact_phone = excluded.emergency_contact_phone,
                emergency_contact_email = excluded.emergency_contact_email,
                emergency_contact_relationship = excluded.emergency_contact_relationship,
                updated_at = CURRENT_TIMESTAMP
            """,
            (
                user["id"],
                _clean_extended_text(request.vehicle_number),
                _clean_extended_text(request.vehicle_type),
                _clean_extended_text(request.vehicle_model),
                _clean_extended_text(request.vehicle_other_info),
                _clean_extended_text(request.emergency_contact_name),
                _clean_extended_text(request.emergency_contact_phone),
                _clean_extended_text(request.emergency_contact_email),
                _clean_extended_text(request.emergency_contact_relationship),
            ),
        )
        connection.commit()
        connection.close()
        return {"success": True, "message": "Profile details saved successfully."}
    except Exception as e:
        if connection is not None:
            connection.close()
        print("PROFILE SAVE ERROR:", str(e))
        return {"success": False, "message": "Unable to save profile details."}


@app.get("/emergency-contact")
def get_emergency_contact(account_id: str = ""):
    result = get_profile_details(account_id)
    if not result.get("success"):
        return result
    profile = result["profile"]
    return {
        "success": True,
        "emergency_contact": {
            "name": profile["emergency_contact_name"],
            "phone": profile["emergency_contact_phone"],
            "email": profile["emergency_contact_email"],
            "relationship": profile["emergency_contact_relationship"],
        },
    }


@app.post("/emergency-contact")
def save_emergency_contact(request: DriverProfileRequest):
    return save_profile_details(request)


# ============================================================
# RATING / FEEDBACK APIs
# ============================================================

@app.post("/feedback")
def submit_rating_feedback(request: RatingFeedbackRequest):
    connection = None
    try:
        if request.rating < 0 or request.rating > 10:
            return {"success": False, "message": "Rating must be between 0 and 10."}

        connection = get_database_connection()
        user = _find_user_by_account_id(connection, request.account_id)
        if user is None:
            return {"success": False, "message": "Account not found."}

        ride_id = _clean_extended_text(request.ride_id) or None
        if ride_id:
            cursor = connection.cursor()
            cursor.execute(
                "SELECT id FROM rides WHERE ride_id = ? AND user_id = ? LIMIT 1",
                (ride_id, user["id"]),
            )
            if cursor.fetchone() is None:
                ride_id = None

        cursor = connection.cursor()
        cursor.execute(
            """
            INSERT INTO ratings_feedback
                (user_id, ride_id, rating, feedback)
            VALUES (?, ?, ?, ?)
            """,
            (
                user["id"],
                ride_id,
                int(request.rating),
                _clean_extended_text(request.feedback) or None,
            ),
        )
        feedback_id = cursor.lastrowid
        connection.commit()
        connection.close()

        return {
            "success": True,
            "message": "Rating and feedback submitted successfully.",
            "feedback_id": feedback_id,
        }
    except Exception as e:
        if connection is not None:
            connection.close()
        print("FEEDBACK SUBMIT ERROR:", str(e))
        return {"success": False, "message": "Unable to submit feedback."}


@app.get("/feedback/my")
def get_my_feedback(account_id: str = ""):
    connection = None
    try:
        connection = get_database_connection()
        user = _find_user_by_account_id(connection, account_id)
        if user is None:
            return {"success": False, "message": "Account not found.", "feedback": []}
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT id, ride_id, rating, feedback, created_at
            FROM ratings_feedback
            WHERE user_id = ?
            ORDER BY id DESC
            """,
            (user["id"],),
        )
        rows = cursor.fetchall()
        connection.close()
        return {
            "success": True,
            "feedback": [dict(row) for row in rows],
        }
    except Exception as e:
        if connection is not None:
            connection.close()
        print("MY FEEDBACK ERROR:", str(e))
        return {"success": False, "feedback": []}


@app.get("/admin/feedback")
def admin_get_feedback(admin_account_id: str = ""):
    if _admin_required(admin_account_id) is None:
        return {"success": False, "message": "Admin authorization required.", "feedback": []}

    connection = None
    try:
        connection = get_database_connection()
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT
                f.id, f.ride_id, f.rating, f.feedback, f.created_at,
                u.driver_id AS account_id, u.full_name, u.email
            FROM ratings_feedback f
            JOIN users u ON u.id = f.user_id
            ORDER BY f.id DESC
            """
        )
        rows = cursor.fetchall()
        connection.close()
        return {"success": True, "count": len(rows), "feedback": [dict(row) for row in rows]}
    except Exception as e:
        if connection is not None:
            connection.close()
        print("ADMIN FEEDBACK ERROR:", str(e))
        return {"success": False, "feedback": []}


# ============================================================
# CUSTOMER SUPPORT / CONTACT US APIs
# ============================================================

@app.post("/support/tickets")
def create_support_ticket(request: SupportTicketRequest):
    connection = None
    try:
        subject = _clean_extended_text(request.subject)
        message_text = _clean_extended_text(request.message)
        if not subject or not message_text:
            return {"success": False, "message": "Subject and message are required."}

        connection = get_database_connection()
        user = _find_user_by_account_id(connection, request.account_id)
        if user is None:
            return {"success": False, "message": "Account not found."}

        ticket_id = _generate_unique_ticket_id(connection)
        cursor = connection.cursor()
        cursor.execute(
            """
            INSERT INTO support_tickets (ticket_id, user_id, subject, status)
            VALUES (?, ?, ?, 'Open')
            """,
            (ticket_id, user["id"], subject),
        )
        cursor.execute(
            """
            INSERT INTO support_messages
                (ticket_id, sender_type, sender_account_id, message)
            VALUES (?, 'user', ?, ?)
            """,
            (ticket_id, user["driver_id"], message_text),
        )
        connection.commit()
        connection.close()
        connection = None

        admin_email_sent = send_support_ticket_notification_email(
            user_name=user["full_name"],
            user_email=user["email"],
            ticket_id=ticket_id,
            subject=subject,
            message_text=message_text,
        )

        return {
            "success": True,
            "ticket_id": ticket_id,
            "status": "Open",
            "admin_email_sent": admin_email_sent,
        }
    except Exception as e:
        if connection is not None:
            connection.close()
        print("SUPPORT CREATE ERROR:", str(e))
        return {"success": False, "message": "Unable to create support ticket."}


@app.get("/support/my")
def get_my_support_tickets(account_id: str = ""):
    connection = None
    try:
        connection = get_database_connection()
        user = _find_user_by_account_id(connection, account_id)
        if user is None:
            return {"success": False, "message": "Account not found.", "tickets": []}
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT ticket_id, subject, status, created_at, updated_at
            FROM support_tickets
            WHERE user_id = ?
            ORDER BY id DESC
            """,
            (user["id"],),
        )
        tickets = [dict(row) for row in cursor.fetchall()]
        for ticket in tickets:
            cursor.execute(
                """
                SELECT sender_type, sender_account_id, message, created_at
                FROM support_messages
                WHERE ticket_id = ?
                ORDER BY id ASC
                """,
                (ticket["ticket_id"],),
            )
            ticket["messages"] = [dict(row) for row in cursor.fetchall()]
        connection.close()
        return {"success": True, "tickets": tickets}
    except Exception as e:
        if connection is not None:
            connection.close()
        print("MY SUPPORT ERROR:", str(e))
        return {"success": False, "tickets": []}


@app.post("/support/reply")
def user_reply_support_ticket(request: SupportUserReplyRequest):
    connection = None
    try:
        connection = get_database_connection()
        user = _find_user_by_account_id(connection, request.account_id)
        if user is None:
            return {"success": False, "message": "Account not found."}
        message_text = _clean_extended_text(request.message)
        if not message_text:
            return {"success": False, "message": "Message is required."}

        cursor = connection.cursor()
        cursor.execute(
            "SELECT user_id FROM support_tickets WHERE ticket_id = ? LIMIT 1",
            (_clean_extended_text(request.ticket_id),),
        )
        ticket = cursor.fetchone()
        if ticket is None or ticket["user_id"] != user["id"]:
            return {"success": False, "message": "Support ticket not found."}

        cursor.execute(
            """
            INSERT INTO support_messages
                (ticket_id, sender_type, sender_account_id, message)
            VALUES (?, 'user', ?, ?)
            """,
            (request.ticket_id, user["driver_id"], message_text),
        )
        cursor.execute(
            """
            UPDATE support_tickets
            SET status = 'Open', updated_at = CURRENT_TIMESTAMP
            WHERE ticket_id = ?
            """,
            (request.ticket_id,),
        )
        connection.commit()
        connection.close()
        connection = None

        admin_email_sent = False
        if MAIN_ADMIN_EMAIL:
            notification = EmailMessage()
            notification["Subject"] = f"Driver Safety AI - User Reply {request.ticket_id}"
            notification["From"] = SMTP_EMAIL
            notification["To"] = MAIN_ADMIN_EMAIL
            notification.set_content(
                f"""A user replied to a Driver Safety AI support ticket.

Ticket ID: {request.ticket_id}
User: {user["full_name"] or "User"}
Email: {user["email"] or "Not provided"}

Message:
{message_text}

Open Admin Support in the application to continue the conversation.
"""
            )
            admin_email_sent = send_email(notification)

        return {
            "success": True,
            "message": "Reply submitted.",
            "admin_email_sent": admin_email_sent,
        }
    except Exception as e:
        if connection is not None:
            connection.close()
        print("SUPPORT USER REPLY ERROR:", str(e))
        return {"success": False, "message": "Unable to send reply."}


@app.get("/admin/support")
def admin_get_support(admin_account_id: str = ""):
    if _admin_required(admin_account_id) is None:
        return {"success": False, "message": "Admin authorization required.", "tickets": []}

    connection = None
    try:
        connection = get_database_connection()
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT
                t.ticket_id, t.subject, t.status, t.created_at, t.updated_at,
                u.driver_id AS account_id, u.full_name, u.email
            FROM support_tickets t
            JOIN users u ON u.id = t.user_id
            ORDER BY t.id DESC
            """
        )
        tickets = [dict(row) for row in cursor.fetchall()]
        for ticket in tickets:
            cursor.execute(
                """
                SELECT sender_type, sender_account_id, message, created_at
                FROM support_messages
                WHERE ticket_id = ?
                ORDER BY id ASC
                """,
                (ticket["ticket_id"],),
            )
            ticket["messages"] = [dict(row) for row in cursor.fetchall()]
        connection.close()
        return {"success": True, "count": len(tickets), "tickets": tickets}
    except Exception as e:
        if connection is not None:
            connection.close()
        print("ADMIN SUPPORT ERROR:", str(e))
        return {"success": False, "tickets": []}


@app.post("/admin/support/reply")
def admin_reply_support_ticket(request: SupportReplyRequest):
    if _admin_required(request.admin_account_id) is None:
        return {"success": False, "message": "Admin authorization required."}

    connection = None
    try:
        message_text = _clean_extended_text(request.message)
        status = _clean_extended_text(request.status) or "Replied"
        allowed_statuses = {"Open", "In Progress", "Replied", "Resolved", "Closed"}
        if status not in allowed_statuses:
            status = "Replied"
        if not message_text:
            return {"success": False, "message": "Reply message is required."}

        connection = get_database_connection()
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT
                t.ticket_id, t.subject, t.user_id,
                u.full_name, u.email
            FROM support_tickets t
            JOIN users u ON u.id = t.user_id
            WHERE t.ticket_id = ?
            LIMIT 1
            """,
            (_clean_extended_text(request.ticket_id),),
        )
        ticket = cursor.fetchone()
        if ticket is None:
            return {"success": False, "message": "Support ticket not found."}

        admin = _admin_required(request.admin_account_id)
        cursor.execute(
            """
            INSERT INTO support_messages
                (ticket_id, sender_type, sender_account_id, message)
            VALUES (?, 'admin', ?, ?)
            """,
            (request.ticket_id, admin["driver_id"], message_text),
        )
        cursor.execute(
            """
            UPDATE support_tickets
            SET status = ?, updated_at = CURRENT_TIMESTAMP
            WHERE ticket_id = ?
            """,
            (status, request.ticket_id),
        )
        connection.commit()
        connection.close()
        connection = None

        user_email_sent = send_support_reply_email(
            recipient_email=ticket["email"],
            full_name=ticket["full_name"],
            ticket_id=ticket["ticket_id"],
            subject=ticket["subject"],
            reply_text=message_text,
            status=status,
        )

        return {
            "success": True,
            "message": "Admin reply sent.",
            "status": status,
            "user_email_sent": user_email_sent,
        }
    except Exception as e:
        if connection is not None:
            connection.close()
        print("ADMIN SUPPORT REPLY ERROR:", str(e))
        return {"success": False, "message": "Unable to send admin reply."}


# ============================================================
# ADMIN USER EDIT / DELETE APIs
# ============================================================

@app.put("/admin/users/edit")
def admin_edit_user(request: AdminEditUserRequest):
    if _admin_required(request.admin_account_id) is None:
        return {"success": False, "message": "Admin authorization required."}

    connection = None
    try:
        connection = get_database_connection()
        target = _find_user_by_account_id(connection, request.target_account_id)
        if target is None:
            return {"success": False, "message": "Target account not found."}

        # Keep admin records protected from role changes through this endpoint.
        if (target["role"] or "user").lower() == "admin":
            if request.role is not None and request.role.strip().lower() != "admin":
                return {"success": False, "message": "Admin role cannot be changed here."}

        updates = []
        values = []
        if request.full_name is not None:
            updates.append("full_name = ?")
            values.append(_clean_extended_text(request.full_name))
        if request.email is not None:
            updates.append("email = ?")
            values.append(str(request.email).strip().lower())
        if request.phone is not None:
            updates.append("phone = ?")
            values.append(_clean_extended_text(request.phone))
        if request.driving_license is not None:
            updates.append("driving_license = ?")
            values.append(_clean_extended_text(request.driving_license))

        if not updates:
            connection.close()
            return {"success": True, "message": "No account fields required updating."}

        values.append(target["id"])
        cursor = connection.cursor()
        cursor.execute(
            f"UPDATE users SET {', '.join(updates)} WHERE id = ?",
            tuple(values),
        )
        connection.commit()
        connection.close()
        return {"success": True, "message": "User account updated successfully."}
    except sqlite3.IntegrityError:
        if connection is not None:
            connection.close()
        return {"success": False, "message": "Email is already registered."}
    except Exception as e:
        if connection is not None:
            connection.close()
        print("ADMIN EDIT USER ERROR:", str(e))
        return {"success": False, "message": "Unable to edit account."}


@app.delete("/admin/users/{target_account_id}")
def admin_delete_user(target_account_id: str, admin_account_id: str = ""):
    if _admin_required(admin_account_id) is None:
        return {"success": False, "message": "Admin authorization required."}

    connection = None
    try:
        connection = get_database_connection()
        target = _find_user_by_account_id(connection, target_account_id)
        if target is None:
            return {"success": False, "message": "Account not found."}

        if (target["role"] or "user").lower() == "admin":
            return {
                "success": False,
                "message": "Admin accounts cannot be deleted through the user-delete endpoint.",
            }

        cursor = connection.cursor()
        cursor.execute("PRAGMA foreign_keys = ON")
        cursor.execute("DELETE FROM users WHERE id = ?", (target["id"],))
        connection.commit()
        connection.close()

        # Keep the existing Excel representation synchronized.
        try:
            sync_admins_to_excel()
        except Exception as sync_error:
            print("EXCEL SYNC AFTER DELETE ERROR:", str(sync_error))

        return {"success": True, "message": "User account deleted successfully."}
    except Exception as e:
        if connection is not None:
            connection.close()
        print("ADMIN DELETE USER ERROR:", str(e))
        return {"success": False, "message": "Unable to delete user account."}


# ============================================================
# ADMIN EXPORT APIs
# ============================================================

@app.get("/admin/sql-database")
def admin_download_sql_database(admin_account_id: str = ""):
    if _admin_required(admin_account_id) is None:
        return {"success": False, "message": "Admin authorization required."}
    if not os.path.exists(DATABASE):
        return {"success": False, "message": "Database file not found."}
    return FileResponse(
        DATABASE,
        media_type="application/x-sqlite3",
        filename="driver_safety.db",
    )


@app.get("/admin/excel-download")
def admin_download_excel(admin_account_id: str = ""):
    if _admin_required(admin_account_id) is None:
        return {"success": False, "message": "Admin authorization required."}
    try:
        sync_admins_to_excel()
    except Exception as e:
        print("EXCEL EXPORT ERROR:", str(e))
        return {"success": False, "message": "Unable to prepare Excel export."}
    if not os.path.exists(EXCEL_FILE):
        return {"success": False, "message": "Excel file not found."}
    return FileResponse(
        EXCEL_FILE,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        filename="driver_safety_users.xlsx",
    )


@app.get("/admin/users/{target_account_id}/pdf")
def admin_download_user_pdf(target_account_id: str, admin_account_id: str = ""):
    if _admin_required(admin_account_id) is None:
        return {"success": False, "message": "Admin authorization required."}

    if not REPORTLAB_AVAILABLE:
        return {"success": False, "message": "PDF support requires reportlab. Install it with: python -m pip install reportlab"}

    connection = None
    try:
        connection = get_database_connection()
        user = _find_user_by_account_id(connection, target_account_id)
        if user is None:
            return {"success": False, "message": "Account not found."}
        cursor = connection.cursor()
        cursor.execute(
            "SELECT * FROM driver_profiles WHERE user_id = ? LIMIT 1",
            (user["id"],),
        )
        profile = cursor.fetchone()
        connection.close()

        buffer = BytesIO()
        pdf = canvas.Canvas(buffer, pagesize=A4)
        width, height = A4
        x = 18 * mm
        y = height - 20 * mm
        pdf.setFont("Helvetica-Bold", 16)
        pdf.drawString(x, y, "Driver Safety AI - User Report")
        y -= 12 * mm
        pdf.setFont("Helvetica", 10)

        rows = [
            ("Driver Name", user["full_name"]),
            ("Account ID", user["driver_id"]),
            ("Email", user["email"]),
            ("Phone", user["phone"]),
            ("Driving Licence", user["driving_license"]),
            ("Role", user["role"]),
            ("Admin Status", user["admin_status"]),
            ("Registered Date", user["created_at"]),
            ("Vehicle Number", profile["vehicle_number"] if profile else ""),
            ("Vehicle Type", profile["vehicle_type"] if profile else ""),
            ("Vehicle Model", profile["vehicle_model"] if profile else ""),
            ("Emergency Contact", profile["emergency_contact_name"] if profile else ""),
            ("Emergency Phone", profile["emergency_contact_phone"] if profile else ""),
            ("Emergency Email", profile["emergency_contact_email"] if profile else ""),
            ("Relationship", profile["emergency_contact_relationship"] if profile else ""),
        ]
        for label, value in rows:
            pdf.drawString(x, y, f"{label}: {_safe_pdf_value(value)}")
            y -= 7 * mm
            if y < 20 * mm:
                pdf.showPage()
                pdf.setFont("Helvetica", 10)
                y = height - 20 * mm
        pdf.save()
        buffer.seek(0)
        return StreamingResponse(
            buffer,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="User_Report_{user["driver_id"] or user["id"]}.pdf"'
            },
        )
    except Exception as e:
        if connection is not None:
            connection.close()
        print("ADMIN USER PDF ERROR:", str(e))
        return {"success": False, "message": "Unable to generate PDF report."}


# ============================================================
# RIDE COMPLETION + AUTOMATIC PDF EMAIL
# ============================================================

@app.post("/rides/complete")
def complete_ride(request: RideCompletionRequest):
    connection = None
    try:
        connection = get_database_connection()
        user = _find_user_by_account_id(connection, request.account_id)
        if user is None:
            return {"success": False, "message": "Account not found."}

        cursor = connection.cursor()
        cursor.execute(
            "SELECT * FROM driver_profiles WHERE user_id = ? LIMIT 1",
            (user["id"],),
        )
        profile = cursor.fetchone()

        ride_id = _clean_extended_text(request.ride_id)
        if not ride_id:
            ride_id = _generate_unique_ride_id(connection)

        cursor.execute(
            "SELECT 1 FROM rides WHERE ride_id = ? LIMIT 1",
            (ride_id,),
        )
        if cursor.fetchone() is not None:
            connection.close()
            return {"success": False, "message": "Ride ID already exists."}

        cursor.execute(
            """
            INSERT INTO rides (
                ride_id, user_id, start_time, end_time,
                start_location, end_location, distance_km,
                duration_minutes, route_info, gps_info,
                safety_events, alerts, ride_summary, report_email
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                ride_id,
                user["id"],
                _clean_extended_text(request.start_time),
                _clean_extended_text(request.end_time),
                _clean_extended_text(request.start_location),
                _clean_extended_text(request.end_location),
                request.distance_km,
                request.duration_minutes,
                _clean_extended_text(request.route_info),
                _clean_extended_text(request.gps_info),
                _clean_extended_text(request.safety_events),
                _clean_extended_text(request.alerts),
                _clean_extended_text(request.ride_summary),
                _clean_extended_text(user["email"]),
            ),
        )
        connection.commit()

        cursor.execute(
            "SELECT * FROM rides WHERE ride_id = ? LIMIT 1",
            (ride_id,),
        )
        ride = cursor.fetchone()
        connection.close()
        connection = None

        pdf_bytes = generate_ride_pdf(ride, user, profile)
        email_sent = send_ride_report_email(
            user["email"],
            user["full_name"],
            ride_id,
            pdf_bytes,
        )

        connection = get_database_connection()
        cursor = connection.cursor()
        cursor.execute(
            "UPDATE rides SET report_sent = ? WHERE ride_id = ?",
            (1 if email_sent else 0, ride_id),
        )
        connection.commit()
        connection.close()
        connection = None

        return {
            "success": True,
            "message": "Ride completed successfully.",
            "ride_id": ride_id,
            "report_generated": True,
            "report_email": user["email"],
            "report_sent": email_sent,
            "email_message": (
                "Ride report sent to registered email."
                if email_sent
                else "Ride report generated, but email could not be sent."
            ),
        }
    except Exception as e:
        if connection is not None:
            connection.close()
        print("RIDE COMPLETION ERROR:", str(e))
        return {"success": False, "message": "Unable to complete ride."}


@app.get("/rides/my")
def get_my_rides(account_id: str = ""):
    connection = None
    try:
        connection = get_database_connection()
        user = _find_user_by_account_id(connection, account_id)
        if user is None:
            return {"success": False, "message": "Account not found.", "rides": []}
        cursor = connection.cursor()
        cursor.execute(
            "SELECT * FROM rides WHERE user_id = ? ORDER BY id DESC",
            (user["id"],),
        )
        rides = [dict(row) for row in cursor.fetchall()]
        connection.close()
        return {"success": True, "rides": rides}
    except Exception as e:
        if connection is not None:
            connection.close()
        print("MY RIDES ERROR:", str(e))
        return {"success": False, "rides": []}


@app.get("/rides/{ride_id}/report")
def download_my_ride_report(ride_id: str, account_id: str = ""):
    connection = None
    try:
        connection = get_database_connection()
        user = _find_user_by_account_id(connection, account_id)
        if user is None:
            return {"success": False, "message": "Account not found."}
        cursor = connection.cursor()
        cursor.execute(
            "SELECT * FROM rides WHERE ride_id = ? AND user_id = ? LIMIT 1",
            (_clean_extended_text(ride_id), user["id"]),
        )
        ride = cursor.fetchone()
        if ride is None:
            connection.close()
            return {"success": False, "message": "Ride not found."}
        cursor.execute(
            "SELECT * FROM driver_profiles WHERE user_id = ? LIMIT 1",
            (user["id"],),
        )
        profile = cursor.fetchone()
        connection.close()
        pdf_bytes = generate_ride_pdf(ride, user, profile)
        return StreamingResponse(
            BytesIO(pdf_bytes),
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="Ride_Report_{ride["ride_id"]}.pdf"'
            },
        )
    except Exception as e:
        if connection is not None:
            connection.close()
        print("RIDE PDF ERROR:", str(e))
        return {"success": False, "message": "Unable to generate ride report."}


@app.get("/admin/rides")
def admin_get_rides(admin_account_id: str = ""):
    if _admin_required(admin_account_id) is None:
        return {"success": False, "message": "Admin authorization required.", "rides": []}
    connection = None
    try:
        connection = get_database_connection()
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT r.*, u.driver_id AS account_id, u.full_name, u.email
            FROM rides r
            JOIN users u ON u.id = r.user_id
            ORDER BY r.id DESC
            """
        )
        rows = [dict(row) for row in cursor.fetchall()]
        connection.close()
        return {"success": True, "count": len(rows), "rides": rows}
    except Exception as e:
        if connection is not None:
            connection.close()
        print("ADMIN RIDES ERROR:", str(e))
        return {"success": False, "rides": []}


# ============================================================
# EXTENDED ADMIN EXCEL EXPORT
# ============================================================

@app.get("/admin/full-excel-download")
def admin_download_full_excel(admin_account_id: str = ""):
    if _admin_required(admin_account_id) is None:
        return {"success": False, "message": "Admin authorization required."}

    connection = None
    try:
        connection = get_database_connection()
        workbook = Workbook()
        default_sheet = workbook.active
        workbook.remove(default_sheet)

        datasets = {
            "Users": (
                "SELECT id, driver_id, full_name, email, phone, driving_license, role, admin_status, created_at FROM users"
            ),
            "Profiles": (
                "SELECT * FROM driver_profiles"
            ),
            "Rides": (
                "SELECT * FROM rides"
            ),
            "Feedback": (
                "SELECT * FROM ratings_feedback"
            ),
            "Support Tickets": (
                "SELECT * FROM support_tickets"
            ),
            "Support Messages": (
                "SELECT * FROM support_messages"
            ),
        }

        cursor = connection.cursor()
        for sheet_name, query in datasets.items():
            worksheet = workbook.create_sheet(sheet_name)
            cursor.execute(query)
            rows = cursor.fetchall()
            if rows:
                headers = list(rows[0].keys())
            else:
                # Retrieve column names without changing the database.
                temp = cursor.execute(query)
                headers = [description[0] for description in temp.description]
            worksheet.append(headers)
            for row in rows:
                worksheet.append([row[header] for header in headers])

        summary = workbook.create_sheet("Summary")
        summary.append(["Dataset", "Row Count"])
        for sheet_name in datasets:
            summary.append([sheet_name, workbook[sheet_name].max_row - 1])

        connection.close()
        output_path = os.path.join(BASE_DIR, "driver_safety_full_export.xlsx")
        workbook.save(output_path)
        return FileResponse(
            output_path,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            filename="driver_safety_full_export.xlsx",
        )
    except Exception as e:
        if connection is not None:
            connection.close()
        print("FULL EXCEL EXPORT ERROR:", str(e))
        return {"success": False, "message": "Unable to create full Excel export."}

