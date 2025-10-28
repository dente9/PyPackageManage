@echo off
cd /d "%~dp0"
>nul chcp 65001

:: 1. 如果 .venv 已存在就跳过创建
if exist ".venv\Scripts\python.exe" (
    echo [1] .venv 已存在，跳过创建虚拟环境
    goto :activate
)

:: 真正需要时才创建
echo [1] 创建虚拟环境 ...
uv venv -p 3.10 .venv
if errorlevel 1 (
    echo 创建失败
    pause & exit /b 1
)

:activate
:: 2. 激活
call .venv\Scripts\activate.bat

:: 3. 离线安装依赖
echo [2] 离线安装依赖 ...
uv pip install --offline --no-index --find-links ./package -r requirement.txt
if errorlevel 1 (
    echo 安装失败
    pause & exit /b 1
)

echo [3] 全部完成！