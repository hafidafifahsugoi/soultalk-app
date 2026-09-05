@echo off
title SoulTalk AI - Online Server Runner (Cloudflare Tunnel)
echo ==============================================================
echo        SoulTalk AI - Server Online Gratis (Tanpa Kartu)
echo ==============================================================
echo.

:: Move to project folder
cd /d "%~dp0"

:: Check if cloudflared exists
if not exist "cloudflared.exe" (
    echo [INFO] Mengunduh Cloudflare Tunnel resmi...
    curl.exe -s -L -o cloudflared.exe https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
)

:: Run FastAPI backend in separate window
echo [1/2] Menjalankan Server Backend FastAPI...
start "SoulTalk Backend (Uvicorn)" cmd /k "cd /d "%~dp0backend" && venv\Scripts\activate && python -m uvicorn main:app --host 0.0.0.0 --port 8000"

:: Wait 2 seconds for backend to start
timeout /t 2 /nobreak >nul

echo [2/2] Menghubungkan ke Internet Cloudflare (HTTPS Publik)...
echo ==============================================================
echo CARA PAKAI DI HP:
echo 1. Perhatikan link https://xxxx.trycloudflare.com di bawah ini.
echo 2. Buka aplikasi SoulTalk di HP Anda (bisa pakai kuota / data).
echo 3. Di layar Login, ketuk "Server: ...", lalu masukkan link itu.
echo 4. Ketuk "Tes Koneksi" -> "Simpan", lalu coba Login / Daftar!
echo ==============================================================
echo.

:: Run Cloudflare tunnel
.\cloudflared.exe tunnel --url http://localhost:8000

pause
