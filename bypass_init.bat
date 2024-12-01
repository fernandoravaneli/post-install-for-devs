@echo off
REM Muda o diretório para o local onde o .bat está localizado
cd /d "%~dp0"

REM Executa o PowerShell com o script e ignora a política de execução
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "install.ps1"

REM Pausa para manter a janela aberta após a execução
pause
