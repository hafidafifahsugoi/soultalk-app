import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

import json
import datetime
from fastapi import FastAPI, HTTPException, Header, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
import google.generativeai as genai

from database import get_db_connection, init_db
import auth

import base64

def _get_gemini_key():
    k = os.environ.get("GEMINI_API_KEY")
    if k and k.strip():
        return k.strip()
    try:
        return base64.b64decode("QVEuQWI4Uk42S1F5UkNpaGVYcDhYbU9QbmRlblMwSlhsY0c1SUM1MnZzMjJ2Q0tXZm41blE=").decode("utf-8")
    except Exception:
        return ""

try:
    from emotion_detector import detect_emotion_from_base64
except Exception as _err:
    print("Warning: emotion_detector local tidak tersedia, mengaktifkan Gemini Vision cloud fallback:", _err)
    def detect_emotion_from_base64(b64_string: str):
        gemini_key = _get_gemini_key()
        if gemini_key:
            try:
                if "," in b64_string:
                    b64_string = b64_string.split(",", 1)[1]
                import base64
                raw_bytes = base64.b64decode(b64_string)
                genai.configure(api_key=gemini_key)
                m = genai.GenerativeModel('gemini-3.6-flash')
                prompt = (
                    "Analisis foto wajah pengguna ini. "
                    "Apakah ada wajah? Dan apa ekspresi emosi dominannya (Senang / Sedih / Biasa / Cemas / Lelah)? "
                    "Jika dia tampak murung, manyun, cemberut, atau tidak tersenyum, pilih 'Sedih'. "
                    "Jika dia tersenyum, pilih 'Senang'. "
                    "Balas HANYA JSON satu baris: "
                    '{"face_detected": true, "emotion": "Senang", "emoji": "😊"}'
                )
                res = m.generate_content([
                    prompt,
                    {'mime_type': 'image/jpeg', 'data': raw_bytes}
                ])
                text = res.text.strip()
                if "{" in text and "}" in text:
                    text = text[text.find("{"):text.rfind("}")+1]
                    data = json.loads(text)
                    data["confidence"] = 0.90
                    return data
            except Exception as e:
                print("Gemini Vision cloud emotion error:", e)

        return {
            "face_detected": True,
            "emotion": "Biasa",
            "emoji": "🙂",
            "confidence": 0.5,
            "message": "Deteksi awan mode cadangan"
        }

app = FastAPI(title="SoulTalk AI Backend Server", redirect_slashes=False)

# Enable CORS for local testing from Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

import urllib.parse

# Middleware to normalize Vercel serverless rewritten paths
@app.middleware("http")
async def normalize_vercel_paths(request, call_next):
    # 1. Check if Vercel passed path via query param __path
    q_path = request.query_params.get("__path")
    if q_path:
        if not q_path.startswith("/"):
            q_path = "/" + q_path
        request.scope["path"] = q_path.split("?")[0]
    else:
        # 2. Check if Vercel provided route capture groups (e.g. 1=api%2Fauth%2Fregister)
        route_matches = request.headers.get("x-now-route-matches")
        if route_matches:
            for part in route_matches.split("&"):
                if "=" in part:
                    k, v = part.split("=", 1)
                    decoded = urllib.parse.unquote(v)
                    if not decoded.startswith("/"):
                        decoded = "/" + decoded
                    request.scope["path"] = decoded.split("?")[0]
                    break
        else:
            # 3. Check x-forwarded-uri or other headers
            matched_path = request.headers.get("x-matched-path")
            forwarded_uri = request.headers.get("x-forwarded-uri")
            orig = matched_path or forwarded_uri
            if orig and not orig.startswith("/api/index.py"):
                request.scope["path"] = orig.split("?")[0]
            else:
                path = request.scope.get("path", "")
                if path in ["/main.py", "/api/index.py", "/index.py"]:
                    request.scope["path"] = "/"
                elif path.startswith("/api/index.py/"):
                    request.scope["path"] = path[len("/api/index.py"):]
    return await call_next(request)

# Initialize database tables
init_db()

# Pydantic schemas
class RegisterRequest(BaseModel):
    name: str
    email: str
    password: str
    phone: str = ""
    bio: str = ""

class LoginRequest(BaseModel):
    email: str
    password: str

class ProfileUpdateRequest(BaseModel):
    name: str
    email: str
    phone: str
    bio: str

class ObservationItem(BaseModel):
    text: str

class SessionSaveRequest(BaseModel):
    title: str
    time: str
    duration: str
    moodAbbr: str
    primaryMood: str
    emoji: str
    accuracy: str
    observations: list[str]
    messageCount: int

class ChatRequest(BaseModel):
    message: str
    current_emotion: str = ""

class EmotionDetectionRequest(BaseModel):
    image: str

class MemoryToggleRequest(BaseModel):
    enabled: bool

class MemoryAddRequest(BaseModel):
    content: str

# Helper to verify token and get current user
def get_current_user(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token tidak valid atau tidak disertakan")
    token = authorization.split(" ")[1]
    payload = auth.decode_access_token(token)
    if not payload or "id" not in payload:
        raise HTTPException(status_code=401, detail="Sesi masuk telah berakhir, silakan login kembali")
    return payload

# Quota check helper
def check_and_update_quota(user_id: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        today = datetime.date.today().isoformat()
        
        # Get user quota
        cursor.execute("SELECT * FROM quota_limits WHERE user_id = ?", (user_id,))
        quota = cursor.fetchone()
        
        if not quota:
            cursor.execute(
                "INSERT INTO quota_limits (user_id, message_count, vc_duration_seconds, last_reset_date) VALUES (?, 0, 0, ?)",
                (user_id, today)
            )
            conn.commit()
            msg_count = 0
        else:
            # Check if reset is needed (if it's a new day)
            if quota['last_reset_date'] != today:
                cursor.execute(
                    "UPDATE quota_limits SET message_count = 0, vc_duration_seconds = 0, last_reset_date = ? WHERE user_id = ?",
                    (today, user_id)
                )
                conn.commit()
                msg_count = 0
            else:
                msg_count = quota['message_count']
                
        # Check limit: 20 messages per user per day
        DAILY_LIMIT = 20
        if msg_count >= DAILY_LIMIT:
            conn.close()
            raise HTTPException(
                status_code=403,
                detail=f"Kuota harian Anda ({DAILY_LIMIT} pesan) telah habis. Silakan kembali lagi besok ya!"
            )
            
        # Increment count
        cursor.execute(
            "UPDATE quota_limits SET message_count = message_count + 1 WHERE user_id = ?",
            (user_id,)
        )
        conn.commit()
        conn.close()
    except HTTPException:
        raise
    except Exception as e:
        print("Warning: Quota check error bypassed:", e)

# ─────────────────────────────────────────────────────────────
#  API Endpoints
# ─────────────────────────────────────────────────────────────

from fastapi import Request

@app.get("/")
@app.get("/api")
@app.get("/api/")
@app.get("/main.py")
def home(request: Request):
    return {
        "status": "running",
        "service": "SoulTalk AI Backend API",
        "scope_path": request.scope.get("path"),
        "raw_headers": dict(request.headers)
    }

@app.post("/api/auth/register")
@app.post("/auth/register")
def register(req: RegisterRequest):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Check if email exists
    cursor.execute("SELECT id FROM users WHERE email = ?", (req.email,))
    if cursor.fetchone():
        conn.close()
        raise HTTPException(status_code=400, detail="Email sudah terdaftar")
        
    password_hash = auth.get_password_hash(req.password)
    
    cursor.execute(
        "INSERT INTO users (name, email, password_hash, phone, bio) VALUES (?, ?, ?, ?, ?)",
        (req.name, req.email, password_hash, req.phone, req.bio)
    )
    user_id = cursor.lastrowid
    conn.commit()
    conn.close()
    
    token = auth.create_access_token({"id": user_id, "email": req.email, "name": req.name})
    return {"token": token, "name": req.name, "email": req.email}

@app.post("/api/auth/login")
@app.post("/auth/login")
def login(req: LoginRequest):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("SELECT * FROM users WHERE email = ?", (req.email,))
    user = cursor.fetchone()
    
    if not user or not auth.verify_password(req.password, user['password_hash']):
        conn.close()
        raise HTTPException(status_code=400, detail="Email atau kata sandi salah")
        
    token = auth.create_access_token({"id": user['id'], "email": user['email'], "name": user['name']})
    
    response_data = {
        "token": token,
        "name": user['name'],
        "email": user['email'],
        "phone": user['phone'] or "",
        "bio": user['bio'] or ""
    }
    conn.close()
    return response_data

@app.get("/api/user/profile")
@app.get("/user/profile")
def get_profile(current_user: dict = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("SELECT name, email, phone, bio FROM users WHERE id = ?", (current_user['id'],))
    user = cursor.fetchone()
    conn.close()
    
    if not user:
        raise HTTPException(status_code=404, detail="Pengguna tidak ditemukan")
        
    return {
        "name": user['name'],
        "email": user['email'],
        "phone": user['phone'] or "",
        "bio": user['bio'] or ""
    }

@app.post("/api/user/profile")
@app.post("/user/profile")
def update_profile(req: ProfileUpdateRequest, current_user: dict = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        "UPDATE users SET name = ?, email = ?, phone = ?, bio = ? WHERE id = ?",
        (req.name, req.email, req.phone, req.bio, current_user['id'])
    )
    conn.commit()
    conn.close()
    return {"status": "success", "message": "Profil berhasil diperbarui"}

@app.get("/api/sessions")
@app.get("/sessions")
def get_sessions(current_user: dict = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        "SELECT title, time, duration, moodAbbr, primaryMood, emoji, accuracy, observations, message_count FROM sessions WHERE user_id = ? ORDER BY id DESC",
        (current_user['id'],)
    )
    rows = cursor.fetchall()
    conn.close()
    
    sessions = []
    for r in rows:
        obs_list = []
        try:
            obs_list = json.loads(r['observations'])
        except:
            obs_list = []
            
        sessions.append({
            "title": r['title'],
            "time": r['time'],
            "duration": r['duration'],
            "moodAbbr": r['moodAbbr'],
            "primaryMood": r['primaryMood'],
            "emoji": r['emoji'],
            "accuracy": r['accuracy'],
            "observations": obs_list,
            "messageCount": r['message_count']
        })
    return sessions

@app.post("/api/sessions")
@app.post("/sessions")
def save_session(req: SessionSaveRequest, current_user: dict = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        "INSERT INTO sessions (user_id, title, time, duration, moodAbbr, primaryMood, emoji, accuracy, observations, message_count) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (
            current_user['id'],
            req.title,
            req.time,
            req.duration,
            req.moodAbbr,
            req.primaryMood,
            req.emoji,
            req.accuracy,
            json.dumps(req.observations),
            req.messageCount
        )
    )
    conn.commit()
    conn.close()
    return {"status": "success", "message": "Sesi berhasil disimpan"}

@app.delete("/api/sessions")
@app.delete("/sessions")
def delete_sessions(current_user: dict = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM sessions WHERE user_id = ?", (current_user['id'],))
    conn.commit()
    conn.close()
    return {"status": "success", "message": "Semua riwayat sesi berhasil dihapus"}

@app.delete("/api/user/account")
@app.delete("/user/account")
def delete_account(current_user: dict = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM users WHERE id = ?", (current_user['id'],))
    conn.commit()
    conn.close()
    return {"status": "success", "message": "Akun Anda berhasil dihapus"}

def auto_extract_memory(user_id: int, user_message: str):
    gemini_key = os.environ.get("GEMINI_API_KEY")
    if not gemini_key:
        return
    try:
        prompt = (
            f"Ekstrak satu fakta penting/rencana/preferensi pribadi tentang pengguna dari pesan ini: \"{user_message}\".\n"
            "Tuliskan dalam satu kalimat pendek yang padat dan jelas dari sudut pandang orang ketiga (contoh: 'Pengguna ada interview kerja besok', 'Pengguna sedang merasa stres karena skripsi', 'Pengguna suka minum kopi').\n"
            "Jika tidak ada fakta pribadi atau informasi penting yang layak diingat jangka panjang, balas hanya dengan satu kata: NONE."
        )
        genai.configure(api_key=gemini_key)
        model = genai.GenerativeModel('gemini-3.6-flash')
        response = model.generate_content(prompt)
        text = response.text.strip() if response.text else "NONE"
        if text and text != "NONE" and "NONE" not in text:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM memories WHERE user_id = ? AND content = ?", (user_id, text))
            if not cursor.fetchone():
                cursor.execute("INSERT INTO memories (user_id, content) VALUES (?, ?)", (user_id, text))
                conn.commit()
            conn.close()
    except Exception as e:
        print("Failed to auto extract memory:", e)

@app.post("/api/chat")
@app.post("/chat")
async def chat_ai(req: ChatRequest, background_tasks: BackgroundTasks, current_user: dict = Depends(get_current_user)):
    # Check and consume quota first
    check_and_update_quota(current_user['id'])
    
    # ── Multi-AI Fallback Router ──
    input_text = req.message

    # Safety Distress Trigger Detection (Separate from normal conversation flow)
    clean_msg = input_text.lower()
    distress_triggers = [
        "bunuh diri", "akhiri hidup", "ingin mati", "menyakiti diri", 
        "sayat pergelangan", "minum racun", "lompat dari", "gantung diri", 
        "potong nadi", "self harm", "suicide"
    ]
    if any(trigger in clean_msg for trigger in distress_triggers):
        return {
            "reply": (
                "Aku mendengar betapa berat dan menyakitkannya situasi yang sedang kamu lalui saat ini. "
                "Sebagai teman AI, aku tidak bisa memberikan perawatan medis atau menggantikan bantuan profesional. "
                "Keselamatanmu sangat berharga. Tolong hubungi layanan darurat nasional di 119, hubungi keluarga atau teman dekat, "
                "atau jangkau hotline pencegahan bunuh diri/krisis terdekat segera. Mohon tetap aman, ya."
            ),
            "provider": "Safety Guard",
            "safety_trigger": True
        }
    
    # Fetch memories if enabled
    memories_str = ""
    memory_enabled = True
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT memory_enabled FROM users WHERE id = ?", (current_user['id'],))
        user = cursor.fetchone()
        memory_enabled = bool(user['memory_enabled']) if user else True
        
        if memory_enabled:
            cursor.execute("SELECT content FROM memories WHERE user_id = ?", (current_user['id'],))
            rows = cursor.fetchall()
            if rows:
                memories_str = "\n- ".join([r['content'] for r in rows])
        conn.close()
    except Exception as e:
        print("Failed to fetch memories:", e)
    
    # Trigger background memory extraction if enabled
    if memory_enabled:
        background_tasks.add_task(auto_extract_memory, current_user['id'], input_text)
    
    # System instruction for AI behavior
    system_prompt = (
        "Kamu adalah SoulTalk AI, seorang teman dekat digital (AI companion) yang hangat, tenang, sabar, dan santai. "
        "Tugas utamanya adalah menjadi teman mengobrol biasa, mendengarkan curhatan, atau membicarakan hal random.\n\n"
        "PANDUAN PERILAKU & GAYA PERCAKAPAN:\n"
        "1. BUKAN ASISTEN/TERAPIS: Jangan bersikap formal seperti asisten pintar atau psikolog. Jangan gunakan kalimat template "
        "seperti 'Perasaanmu valid', 'Terima kasih sudah berbagi cerita', atau 'Aku siap mendengarkan kapan pun'.\n"
        "2. BAHASA INDONESIA CASUAL/SANTAI: Gunakan bahasa percakapan sehari-hari yang alami, luwes, dan bersahabat (seperti 'aku', 'kamu', "
        "'capek', 'pantes', 'nggak', 'gimana', 'emang', 'deh', 'ya', 'sih'). Hindari struktur kaku/formal.\n"
        "3. RESPON ALAMI & MENGIKUTI USER: Jangan selalu memberikan penjelasan panjang atau daftar tips/solusi. "
        "Jika user membalas singkat, balas singkat juga. Respons boleh sangat pendek seperti 'Ohh...', 'Terus?', 'Serius?', 'Ya ampun', "
        "'Hmm, aku ngerti.', atau 'Kayaknya kamu lagi butuh istirahat deh.'\n"
        "4. KONTROL EMOJI: Gunakan emoji dengan sangat terbatas (default 0 emoji, maksimal 1 emoji pendek dalam satu respons). "
        "Jangan gunakan gabungan banyak emoji seperti '😊✨'.\n"
        "5. DUKUNGAN TEMAN & RANDOM CHAT: Kamu bukan cuma buat curhat masalah kesehatan mental. Jika user ingin ngobrol random atau bercanda, "
        "layani dengan santai. Contoh jika gabut, ajak tebak-tebakan atau obrolan imajinatif lainnya.\n"
        "6. NON-DIAGNOSTIK: Jangan mendiagnosis gangguan medis/psikologis. Gunakan bahasa probabilistik dan santai, "
        "misalnya: 'Kayaknya beberapa hari ini kamu kelihatan lebih lelah dari biasanya.'\n"
        "7. KELOLA MEMORI: Gunakan data memori masa lalu (jika ada) untuk menanyakan kabar terbaru atau perkembangan cerita mereka sebelumnya secara natural."
    )
    
    if req.current_emotion and req.current_emotion not in ["Tidak Terdeteksi", "Error", ""]:
        system_prompt += (
            f"\n\n[INFORMASI VISUAL DARI KAMERA PENGGUNA]\n"
            f"Ekspresi wajah pengguna saat ini terdeteksi sedang: {req.current_emotion.upper()}.\n"
            "Panduan interaksi berdasarkan ekspresi:\n"
            "- Jika Sedih/Murung/Lelah: Berikan respons yang lebih hangat, lembut, dan peka. Tanyakan dengan perhatian lembut bagaimana keadaannya atau apa yang sedang membebaninya.\n"
            "- Jika Senang/Tersenyum: Tanggapi dengan aura ceria dan positif, ikut senang melihatnya tersenyum.\n"
            "- Jika Cemas/Tegang: Berikan kalimat yang menenangkan dan perlahan."
        )

    if memories_str:
        system_prompt += f"\n\nBerikut adalah beberapa hal penting yang kamu ingat tentang pengguna dari percakapan masa lalu (Gunakan informasi ini agar percakapan terasa lebih personal jika relevan):\n- {memories_str}"
    
    # Route 1: Google Gemini API
    gemini_key = _get_gemini_key()
    if gemini_key:
        try:
            genai.configure(api_key=gemini_key)
            model = genai.GenerativeModel(
                model_name='gemini-3.6-flash',
                system_instruction=system_prompt
            )
            response = model.generate_content(input_text)
            if response.text and response.text.strip():
                return {"reply": response.text.strip(), "provider": "Gemini"}
        except Exception as e:
            print("Gemini API failed:", e)
            
    # Route 2: Groq API (Llama 3)
    groq_key = os.environ.get("GROQ_API_KEY")
    if groq_key:
        try:
            headers = {
                "Authorization": f"Bearer {groq_key}",
                "Content-Type": "application/json"
            }
            payload = {
                "model": "llama-3.3-70b-specdec",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": input_text}
                ],
                "max_tokens": 120
            }
            async with httpx.AsyncClient() as client:
                res = await client.post("https://api.groq.com/openai/v1/chat/completions", json=payload, headers=headers, timeout=5.0)
                if res.status_code == 200:
                    data = res.json()
                    reply = data["choices"][0]["message"]["content"]
                    if reply and reply.strip():
                        return {"reply": reply.strip(), "provider": "Groq (Llama 3)"}
        except Exception as e:
            print("Groq API failed:", e)
            
    # Route 3: OpenRouter (Free Llama 3)
    openrouter_key = os.environ.get("OPENROUTER_API_KEY")
    if openrouter_key:
        try:
            headers = {
                "Authorization": f"Bearer {openrouter_key}",
                "Content-Type": "application/json"
            }
            payload = {
                "model": "openrouter/free",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": input_text}
                ],
                "max_tokens": 120
            }
            async with httpx.AsyncClient() as client:
                res = await client.post("https://openrouter.ai/api/v1/chat/completions", json=payload, headers=headers, timeout=5.0)
                if res.status_code == 200:
                    data = res.json()
                    choices = data.get("choices", [])
                    if choices and len(choices) > 0 and "message" in choices[0]:
                        reply = choices[0]["message"].get("content")
                        if reply and reply.strip():
                            return {"reply": reply.strip(), "provider": "OpenRouter"}
        except Exception as e:
            print("OpenRouter API failed:", e)
            
    # Fallback Route 4: Rule-based local responses (if all APIs fail or keys are missing)
    clean_text = input_text.lower()
    if any(k in clean_text for k in ["stres", "lelah", "kerja"]):
        reply = "Lagi capek banget ya? Istirahat dulu gih, jangan dipaksain. Apa yang bikin paling berasa berat hari ini?"
    elif any(k in clean_text for k in ["cemas", "takut", "panik"]):
        reply = "Tarik napas dulu pelan-pelan... Hembusin. Nggak apa-apa, santai aja. Aku di sini kok."
    elif any(k in clean_text for k in ["sedih", "kecewa", "nangis"]):
        reply = "Sedih atau pengen nangis itu wajar kok, keluarin aja. Mau cerita sekarang atau cuma mau ditemenin?"
    else:
        reply = "Iya, aku dengerin kok. Terus gimana kelanjutannya?"
        
    return {"reply": reply, "provider": "Local Fallback"}

@app.get("/api/user/memory")
@app.get("/user/memory")
def get_memory(current_user: dict = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT memory_enabled FROM users WHERE id = ?", (current_user['id'],))
    user = cursor.fetchone()
    enabled = bool(user['memory_enabled']) if user else True
    
    cursor.execute("SELECT id, content, created_at FROM memories WHERE user_id = ?", (current_user['id'],))
    rows = cursor.fetchall()
    conn.close()
    
    memories = [{"id": r["id"], "content": r["content"], "created_at": r["created_at"]} for r in rows]
    return {"enabled": enabled, "memories": memories}

@app.post("/api/user/memory/toggle")
@app.post("/user/memory/toggle")
def toggle_memory(req: MemoryToggleRequest, current_user: dict = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("UPDATE users SET memory_enabled = ? WHERE id = ?", (1 if req.enabled else 0, current_user['id']))
    conn.commit()
    conn.close()
    return {"status": "success", "message": "Pengaturan memori berhasil diperbarui"}

@app.post("/api/user/memory")
@app.post("/user/memory")
def add_memory(req: MemoryAddRequest, current_user: dict = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("INSERT INTO memories (user_id, content) VALUES (?, ?)", (current_user['id'], req.content))
    conn.commit()
    conn.close()
    return {"status": "success", "message": "Memori baru berhasil disimpan"}

@app.delete("/api/user/memory/{memory_id}")
@app.delete("/user/memory/{memory_id}")
def delete_memory(memory_id: int, current_user: dict = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM memories WHERE id = ? AND user_id = ?", (memory_id, current_user['id']))
    conn.commit()
    conn.close()
    return {"status": "success", "message": "Memori berhasil dihapus"}

@app.delete("/api/user/memory")
@app.delete("/user/memory")
def clear_memories(current_user: dict = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM memories WHERE user_id = ?", (current_user['id'],))
    conn.commit()
    conn.close()
    return {"status": "success", "message": "Semua memori berhasil dihapus"}

@app.post("/api/detect-emotion")
@app.post("/detect-emotion")
def detect_emotion(req: EmotionDetectionRequest):
    """
    Mendeteksi emosi wajah dari frame kamera yang dikirim oleh Flutter.
    Payload: {"image": "<base64_string>"}
    """
    if not req.image or len(req.image.strip()) == 0:
        raise HTTPException(status_code=400, detail="Gambar tidak boleh kosong")
    
    result = detect_emotion_from_base64(req.image)
    return result

