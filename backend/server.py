from fastapi import FastAPI, APIRouter, HTTPException, Request, Response, Depends, UploadFile, File
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional
import uuid
from datetime import datetime, timezone, timedelta
import httpx

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

# Create the main app
app = FastAPI()

# Create a router with the /api prefix
api_router = APIRouter(prefix="/api")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ============ MODELS ============

class User(BaseModel):
    model_config = ConfigDict(extra="ignore")
    user_id: str
    email: str
    name: str
    picture: Optional[str] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class UserSession(BaseModel):
    model_config = ConfigDict(extra="ignore")
    session_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    session_token: str
    expires_at: datetime
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class EncryptedDataStore(BaseModel):
    """Stores encrypted task data - backend never sees raw content"""
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    encrypted_data: str  # AES-256-GCM encrypted blob (base64)
    iv: str  # Initialization vector (base64)
    salt: str  # Salt for key derivation (base64)
    version: int = 1  # Data schema version
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class EncryptedDataCreate(BaseModel):
    encrypted_data: str
    iv: str
    salt: str


class UserSettings(BaseModel):
    """User settings (encrypted client-side)"""
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    encrypted_settings: str  # Encrypted settings blob
    iv: str
    salt: str
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class UserSettingsCreate(BaseModel):
    encrypted_settings: str
    iv: str
    salt: str


class WebAuthnCredential(BaseModel):
    """WebAuthn credential for biometric unlock"""
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    credential_id: str
    public_key: str
    counter: int = 0
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class WebAuthnCredentialCreate(BaseModel):
    credential_id: str
    public_key: str


class EncryptedBackup(BaseModel):
    """Encrypted backup metadata"""
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    backup_type: str  # 'google_drive' or 'proton_export'
    encrypted_data: str
    iv: str
    salt: str
    file_id: Optional[str] = None  # Google Drive file ID
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


# ============ AUTH HELPERS ============

async def get_current_user(request: Request) -> User:
    """Get current user from session token (cookie or header)"""
    session_token = request.cookies.get("session_token")
    if not session_token:
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            session_token = auth_header.split(" ")[1]
    
    if not session_token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    # Find session
    session_doc = await db.user_sessions.find_one(
        {"session_token": session_token},
        {"_id": 0}
    )
    
    if not session_doc:
        raise HTTPException(status_code=401, detail="Invalid session")
    
    # Check expiry
    expires_at = session_doc.get("expires_at")
    if isinstance(expires_at, str):
        expires_at = datetime.fromisoformat(expires_at)
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="Session expired")
    
    # Get user
    user_doc = await db.users.find_one(
        {"user_id": session_doc["user_id"]},
        {"_id": 0}
    )
    
    if not user_doc:
        raise HTTPException(status_code=401, detail="User not found")
    
    return User(**user_doc)


# ============ AUTH ROUTES ============

@api_router.post("/auth/session")
async def create_session(request: Request, response: Response):
    """Exchange session_id from Emergent Auth for session_token"""
    data = await request.json()
    session_id = data.get("session_id")
    
    if not session_id:
        raise HTTPException(status_code=400, detail="session_id required")
    
    # Call Emergent Auth to get user data
    async with httpx.AsyncClient() as client:
        try:
            auth_response = await client.get(
                "https://demobackend.emergentagent.com/auth/v1/env/oauth/session-data",
                headers={"X-Session-ID": session_id}
            )
            if auth_response.status_code != 200:
                raise HTTPException(status_code=401, detail="Invalid session_id")
            
            user_data = auth_response.json()
        except Exception as e:
            logger.error(f"Auth error: {e}")
            raise HTTPException(status_code=401, detail="Authentication failed")
    
    # Create or update user
    user_id = f"user_{uuid.uuid4().hex[:12]}"
    existing_user = await db.users.find_one({"email": user_data["email"]}, {"_id": 0})
    
    if existing_user:
        user_id = existing_user["user_id"]
        await db.users.update_one(
            {"user_id": user_id},
            {"$set": {
                "name": user_data.get("name", ""),
                "picture": user_data.get("picture", "")
            }}
        )
    else:
        new_user = {
            "user_id": user_id,
            "email": user_data["email"],
            "name": user_data.get("name", ""),
            "picture": user_data.get("picture", ""),
            "created_at": datetime.now(timezone.utc).isoformat()
        }
        await db.users.insert_one(new_user)
    
    # Create session
    session_token = user_data.get("session_token", str(uuid.uuid4()))
    expires_at = datetime.now(timezone.utc) + timedelta(days=7)
    
    session_doc = {
        "session_id": str(uuid.uuid4()),
        "user_id": user_id,
        "session_token": session_token,
        "expires_at": expires_at.isoformat(),
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.user_sessions.insert_one(session_doc)
    
    # Set cookie
    response.set_cookie(
        key="session_token",
        value=session_token,
        httponly=True,
        secure=True,
        samesite="none",
        path="/",
        max_age=7 * 24 * 60 * 60
    )
    
    # Get user for response
    user_doc = await db.users.find_one({"user_id": user_id}, {"_id": 0})
    
    return {
        "user": user_doc,
        "session_token": session_token
    }


@api_router.get("/auth/me")
async def get_me(user: User = Depends(get_current_user)):
    """Get current authenticated user"""
    return user.model_dump()


@api_router.post("/auth/logout")
async def logout(request: Request, response: Response):
    """Logout and clear session"""
    session_token = request.cookies.get("session_token")
    if session_token:
        await db.user_sessions.delete_one({"session_token": session_token})
    
    response.delete_cookie(key="session_token", path="/")
    return {"message": "Logged out"}


# ============ ENCRYPTED DATA ROUTES ============

@api_router.get("/data")
async def get_encrypted_data(user: User = Depends(get_current_user)):
    """Get user's encrypted data blob"""
    data_doc = await db.encrypted_data.find_one(
        {"user_id": user.user_id},
        {"_id": 0}
    )
    if not data_doc:
        return None
    return data_doc


@api_router.post("/data")
async def save_encrypted_data(
    data: EncryptedDataCreate,
    user: User = Depends(get_current_user)
):
    """Save encrypted data blob"""
    # Upsert encrypted data
    existing = await db.encrypted_data.find_one({"user_id": user.user_id})
    
    doc = {
        "user_id": user.user_id,
        "encrypted_data": data.encrypted_data,
        "iv": data.iv,
        "salt": data.salt,
        "version": 1,
        "updated_at": datetime.now(timezone.utc).isoformat()
    }
    
    if existing:
        await db.encrypted_data.update_one(
            {"user_id": user.user_id},
            {"$set": doc}
        )
    else:
        doc["id"] = str(uuid.uuid4())
        doc["created_at"] = datetime.now(timezone.utc).isoformat()
        await db.encrypted_data.insert_one(doc)
    
    return {"message": "Data saved", "updated_at": doc["updated_at"]}


# ============ SETTINGS ROUTES ============

@api_router.get("/settings")
async def get_settings(user: User = Depends(get_current_user)):
    """Get user's encrypted settings"""
    settings_doc = await db.user_settings.find_one(
        {"user_id": user.user_id},
        {"_id": 0}
    )
    if not settings_doc:
        return None
    return settings_doc


@api_router.post("/settings")
async def save_settings(
    settings: UserSettingsCreate,
    user: User = Depends(get_current_user)
):
    """Save encrypted settings"""
    existing = await db.user_settings.find_one({"user_id": user.user_id})
    
    doc = {
        "user_id": user.user_id,
        "encrypted_settings": settings.encrypted_settings,
        "iv": settings.iv,
        "salt": settings.salt,
        "updated_at": datetime.now(timezone.utc).isoformat()
    }
    
    if existing:
        await db.user_settings.update_one(
            {"user_id": user.user_id},
            {"$set": doc}
        )
    else:
        doc["id"] = str(uuid.uuid4())
        await db.user_settings.insert_one(doc)
    
    return {"message": "Settings saved"}


# ============ WEBAUTHN ROUTES ============

@api_router.post("/webauthn/register")
async def register_webauthn(
    cred: WebAuthnCredentialCreate,
    user: User = Depends(get_current_user)
):
    """Register WebAuthn credential for biometric unlock"""
    doc = {
        "id": str(uuid.uuid4()),
        "user_id": user.user_id,
        "credential_id": cred.credential_id,
        "public_key": cred.public_key,
        "counter": 0,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.webauthn_credentials.insert_one(doc)
    return {"message": "WebAuthn credential registered"}


@api_router.get("/webauthn/credentials")
async def get_webauthn_credentials(user: User = Depends(get_current_user)):
    """Get user's WebAuthn credentials"""
    creds = await db.webauthn_credentials.find(
        {"user_id": user.user_id},
        {"_id": 0}
    ).to_list(100)
    return creds


@api_router.delete("/webauthn/credentials/{credential_id}")
async def delete_webauthn_credential(
    credential_id: str,
    user: User = Depends(get_current_user)
):
    """Delete WebAuthn credential"""
    result = await db.webauthn_credentials.delete_one({
        "user_id": user.user_id,
        "credential_id": credential_id
    })
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Credential not found")
    return {"message": "Credential deleted"}


# ============ BACKUP ROUTES ============

@api_router.post("/backup/create")
async def create_backup(
    data: EncryptedDataCreate,
    backup_type: str = "proton_export",
    user: User = Depends(get_current_user)
):
    """Create encrypted backup"""
    doc = {
        "id": str(uuid.uuid4()),
        "user_id": user.user_id,
        "backup_type": backup_type,
        "encrypted_data": data.encrypted_data,
        "iv": data.iv,
        "salt": data.salt,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.encrypted_backups.insert_one(doc)
    return {"message": "Backup created", "backup_id": doc["id"]}


@api_router.get("/backup/list")
async def list_backups(user: User = Depends(get_current_user)):
    """List user's backups"""
    backups = await db.encrypted_backups.find(
        {"user_id": user.user_id},
        {"_id": 0, "encrypted_data": 0, "iv": 0, "salt": 0}
    ).sort("created_at", -1).to_list(100)
    return backups


# ============ ROOT ROUTE ============

@api_router.get("/")
async def root():
    return {"message": "Obsidian Vault API - Zero-Trust Task Manager"}


@api_router.get("/health")
async def health():
    return {"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat()}


# Include the router in the main app
app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=os.environ.get('CORS_ORIGINS', '*').split(','),
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
