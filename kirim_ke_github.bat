@echo off
title Kirim Kode ke GitHub hafidafifahsugoi
cd /d "%~dp0"
echo ============================================================
echo   MENGUNGGAH KODE SOULTALK KE GITHUB hafidafifahsugoi
echo ============================================================
echo.
echo Jendela browser akan terbuka meminta izin masuk GitHub akun kamu.
echo Silakan klik tombol hijau "Authorize" di browser ya.
echo.
git push -u origin main
echo.
echo ============================================================
echo  SELESAI! Seluruh kode sudah masuk ke GitHub kamu!
echo ============================================================
pause
