# ==============================================================================
#                             *** 用户配置区域 ***
# ==============================================================================

# --- 任务定义 ---
$Configurations = @(
    [PSCustomObject]@{
        Type        = 'ZipInstall'
        Description = "安装 uv 并配置环境变量"
        SourceFile  = "uv-x86_64-pc-windows-msvc.zip"
        Destination = "$HOME\.local\bin"
    },
    [PSCustomObject]@{
        Type        = 'ConfigFile'
        Description = "配置 pip 源"
        SourceFile  = "pip.ini"
        Destination = "$env:APPDATA\pip\pip.ini"
    },
    [PSCustomObject]@{
        Type        = 'ConfigFile'
        Description = "配置 Conda 源"
        SourceFile  = ".condarc"
        Destination = "$HOME\.condarc"
    },
    [PSCustomObject]@{
        Type        = 'ConfigFile'
        Description = "配置 uv 全局源"
        SourceFile  = "uv.toml"
        Destination = "$env:APPDATA\uv\uv.toml"
    }
)

# --- 任务队列配置 ---
$TaskQueue = @()


# ==============================================================================
#                            *** 功能函数定义 ***
# ==============================================================================

function Set-ConfigFile {
    param( [Parameter(Mandatory = $true)] [PSCustomObject]$Config )

    $SourcePath = Join-Path $PSScriptRoot $Config.SourceFile
    $DestinationPath = $ExecutionContext.InvokeCommand.ExpandString($Config.Destination)
    $DestinationDir = Split-Path -Path $DestinationPath -Parent

    Write-Host "`n--- $($Config.Description) ---" -ForegroundColor Cyan

    if (-not (Test-Path -Path $SourcePath)) {
        Write-Error "错误：源文件 '$($Config.SourceFile)' 未找到！"
        return
    }

    if (Test-Path -Path $DestinationPath) {
        $confirm = Read-Host "目标文件 '$DestinationPath' 已存在。是否覆盖? (Y/N)"
        if ($confirm.ToLower() -ne 'y') {
            Write-Host "操作取消，跳过此任务。" -ForegroundColor Yellow
            return
        }

        $BackupPath = "$DestinationPath.bak"
        try {
            Rename-Item -Path $DestinationPath -NewName "$BackupPath" -Force -ErrorAction Stop
            Write-Host "已将原始文件备份到 '$BackupPath'" -ForegroundColor Green
        }
        catch {
            Write-Error "备份文件失败！请检查权限。错误: $($_.Exception.Message)"
            return
        }
    }

    if (-not (Test-Path -Path $DestinationDir)) {
        New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    }

    try {
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
        Write-Host "成功将 '$($Config.SourceFile)' 配置到 '$DestinationPath'" -ForegroundColor Green
    }
    catch {
        Write-Error "复制文件失败！请检查权限。错误: $($_.Exception.Message)"
    }
}

function Install-PackageFromZip {
    param( [Parameter(Mandatory = $true)] [PSCustomObject]$Config )

    $SourcePath = Join-Path $PSScriptRoot $Config.SourceFile
    $DestinationDir = $ExecutionContext.InvokeCommand.ExpandString($Config.Destination)

    Write-Host "`n--- $($Config.Description) ---" -ForegroundColor Cyan

    if (-not (Test-Path -Path $SourcePath)) {
        Write-Error "错误：源文件 '$($Config.SourceFile)' 未找到！"
        return
    }

    New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    try {
        Write-Host "正在解压 '$($Config.SourceFile)' 到临时目录..."
        Expand-Archive -Path $SourcePath -DestinationPath $TempDir -Force -ErrorAction Stop

        # --- 核心修正逻辑 ---
        # 检查解压后的内容。如果只有一个子目录，就把它作为源。否则，把临时目录本身作为源。
        $ExtractedItems = Get-ChildItem -Path $TempDir
        $SourceContentDir = $TempDir # 默认为临时目录本身

        if ($ExtractedItems.Count -eq 1 -and $ExtractedItems[0].PSIsContainer) {
            # 如果zip解压后只有一个根文件夹，就将该文件夹作为内容源
            $SourceContentDir = $ExtractedItems[0].FullName
            Write-Host "检测到根文件夹，将从 '$SourceContentDir' 移动内容。"
        }

        Write-Host "正在将文件移动到 '$DestinationDir'..."
        # 使用 -Path "$SourceContentDir\*" 来移动文件夹的 *内容* 而不是文件夹本身
        Move-Item -Path (Join-Path $SourceContentDir "*") -Destination $DestinationDir -Force -ErrorAction Stop

        Write-Host "解压并部署成功。" -ForegroundColor Green
    }
    catch {
        Write-Error "操作失败！请检查ZIP文件及权限。错误: $($_.Exception.Message)"
        return
    }
    finally {
        if (Test-Path -Path $TempDir) {
            Remove-Item -Path $TempDir -Recurse -Force
        }
    }

    Set-UserPath -Directory $DestinationDir
}

function Set-UserPath {
    param( [Parameter(Mandatory = $true)] [string]$Directory )

    Write-Host "正在配置环境变量..."
    $RegistryPath = "Registry::HKEY_CURRENT_USER\Environment"
    $CurrentPath = (Get-ItemProperty -Path $RegistryPath -Name Path -ErrorAction SilentlyContinue).Path
    $PathArray = $CurrentPath -split ';' -ne ''

    if ($PathArray -notcontains $Directory) {
        $NewPath = @($Directory) + $PathArray -join ';'
        Set-ItemProperty -Path $RegistryPath -Name Path -Value $NewPath -Type ExpandString
        Write-Host "已将 '$Directory' 添加到用户 PATH 环境变量。" -ForegroundColor Green
    }
    else {
        Write-Host "环境变量已配置，无需更改。" -ForegroundColor Yellow
    }
}

function Show-InteractiveMenu {
    while ($true) {
        Clear-Host
        Write-Host "=====================================" -ForegroundColor Yellow
        Write-Host "         请选择要执行的任务" -ForegroundColor White
        Write-Host "=====================================" -ForegroundColor Yellow

        for ($i = 0; $i -lt $Configurations.Count; $i++) {
            Write-Host "  $($i + 1). $($Configurations[$i].Description)"
        }

        Write-Host "  $($Configurations.Count + 1). 执行以上所有任务"
        Write-Host "  q. 退出"
        Write-Host "-------------------------------------"
        $choice = Read-Host "请输入你的选择 (可多选，用逗号隔开，例如 1,3)"

        if ($choice -eq 'q') { break }

        $choices = $choice.Split(',').Trim()

        if ($choices -contains ($Configurations.Count + 1)) {
            Invoke-ConfigurationTask -TaskNumbers (1..$Configurations.Count)
        }
        else {
            Invoke-ConfigurationTask -TaskNumbers $choices
        }

        Write-Host "`n已完成所选任务。" -ForegroundColor Green
        Read-Host "按回车键返回主菜单..."
    }
}

function Invoke-ConfigurationTask {
    param( [Parameter(Mandatory = $true)] [array]$TaskNumbers )

    foreach ($taskNum in $TaskNumbers) {
        if ($taskNum -match "^\d+$") {
            $taskIndex = [int]$taskNum - 1
            if ($taskIndex -ge 0 -and $taskIndex -lt $Configurations.Count) {
                $task = $Configurations[$taskIndex]
                if ($task.Type -eq 'ConfigFile') {
                    Set-ConfigFile -Config $task
                }
                elseif ($task.Type -eq 'ZipInstall') {
                    Install-PackageFromZip -Config $task
                }
            }
            else {
                Write-Warning "无效的任务编号: '$taskNum'，已忽略。"
            }
        }
        else {
            Write-Warning "无效的输入: '$taskNum'，已忽略。"
        }
    }
}

# ==============================================================================
#                            *** 主执行流程 ***
# ==============================================================================

if ($TaskQueue.Count -gt 0) {
    # --- 自动模式 ---
    Write-Host "检测到任务队列，进入自动执行模式..." -ForegroundColor Cyan
    Invoke-ConfigurationTask -TaskNumbers $TaskQueue
    Write-Host "`n==================================================" -ForegroundColor Green
    Write-Host "自动队列中的所有任务已执行完毕！" -ForegroundColor Green
}
else {
    # --- 交互模式 ---
    Show-InteractiveMenu
    Write-Host "`n脚本已退出。感谢使用！"
}

# 结束提示
Write-Host "提示：如果配置了环境变量，请重新打开一个新的终端窗口使其生效。" -ForegroundColor Yellow
if ($Host.Name -eq "ConsoleHost" -and $TaskQueue.Count -eq 0) {
    Read-Host "按回车键关闭窗口"
}