@echo off
title SoulTalk AI Backend Runner
echo ==============================================================
echo             SoulTalk AI Backend Setup and Runner
echo ==============================================================
echo.

:: Check if Python 3.11 is installed via Python Launcher
py -3.11 --version >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO] Menggunakan Python 3.11...
    set PYTHON_CMD=py -3.11
) else (
    python --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo [ERROR] Python tidak terdeteksi! Silakan install Python terlebih dahulu.
        echo Pastikan opsi "Add Python to PATH" dicentang saat menginstal.
        pause
        exit /b 1
    )
    echo [WARNING] Python 3.11 tidak terdeteksi melalui Python Launcher.
    echo Menggunakan Python bawaan sistem...
    set PYTHON_CMD=python
)

:: Move to backend folder
cd /d "%~dp0backend"

:: Check if virtual environment exists
if not exist "venv" (
    echo [INFO] Membuat virtual environment baru (venv)...
    %PYTHON_CMD% -m venv venv
    if %errorlevel% neq 0 (
        echo [ERROR] Gagal membuat virtual environment!
        pause
        exit /b 1
    )
)

:: Activate virtual environment
echo [INFO] Mengaktifkan virtual environment...
call venv\Scripts\activate

:: Install requirements
echo [INFO] Memasang dependencies dari requirements.txt...
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo [ERROR] Gagal menginstal dependencies!
    pause
    exit /b 1
)

echo.
:: Detect local IP address
for /f "tokens=*" %%i in ('python -c "import socket; print(socket.gethostbyname(socket.gethostname()))"') do set LOCAL_IP=%%i
if "%LOCAL_IP%"=="" set LOCAL_IP=192.168.1.9

echo ==============================================================
echo [SUCCESS] Backend siap! Server berjalan di port 8000.
echo.
echo CARA MENGHUBUNGKAN KE HP:
echo  [A] Lewat Wi-Fi yang Sama (Wireless):
echo      - Pastikan HP dan Laptop terhubung ke Wi-Fi yang sama.
echo      - Di aplikasi SoulTalk di HP, URL Server: http://%LOCAL_IP%:8000
echo.
echo  [B] Lewat Kabel USB (Paling Stabil / Anti-Gagal):
echo      - Hubungkan HP ke Laptop via kabel USB (USB Debugging aktif).
echo      - Jalankan di CMD: adb reverse tcp:8000 tcp:8000
echo      - Di aplikasi SoulTalk di HP, URL Server: http://localhost:8000
echo ==============================================================
echo.

:: Run FastAPI Server using Uvicorn
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload

pause
