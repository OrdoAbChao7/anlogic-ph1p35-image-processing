# Sync Anlogic Vision Open Source Reference Repositories
[CmdletBinding()]
param(
    [switch]$ForceReclone = $false
)

$ErrorActionPreference = "Continue"

# 1. Repo root
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Repo Root: $repoRoot" -ForegroundColor Cyan
Write-Host "Starting Anlogic FPGA Vision Reference Repositories Sync..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 2. 6 target repos
$repositories = @(
    @{
        Id = "01_video_processing_national_prize"
        Name = "2024 Anlogic National 1st Prize Video Platform"
        Url = "https://github.com/lifeng0718/Multifunctional-video-processing-platform"
        RelPath = ".tools/references/anlogic-vision/01_video_processing_national_prize"
        KeyChecks = @("README.md")
    },
    @{
        Id = "02_image_algorithm_library"
        Name = "2025 Anlogic National 1st Prize Vision & UDP"
        Url = "https://github.com/maojinxiang/FPGA-ANLU-National-First-Prize"
        RelPath = ".tools/references/anlogic-vision/02_image_algorithm_library"
        KeyChecks = @("README.md", "Main/q3q4/import/udp_cam_ctrl.v")
    },
    @{
        Id = "03_geometry_recognition"
        Name = "2024 Anlogic National 2nd Prize Hu Moments"
        Url = "https://github.com/InitialXE/Multi-Function-Image-Processing-PLAT"
        RelPath = ".tools/references/anlogic-vision/03_geometry_recognition"
        KeyChecks = @("README.md", "Gesture_recognition.v")
    },
    @{
        Id = "04_ph1p35_bbox_cnn"
        Name = "PH1P35 Multi-BBox & CNN Project"
        Url = "https://github.com/YuxiangJia111/FPGA_ANLU_National_First_Prize"
        RelPath = ".tools/references/anlogic-vision/04_ph1p35_bbox_cnn"
        KeyChecks = @("README.md", "user_source/hdl_source/digit_multi_bbox.v")
    },
    @{
        Id = "05_vision_bbox_template"
        Name = "Anlogic Vision UDP BBox & Template Match"
        Url = "https://github.com/zdxddmx/anlogic_fpga_vision_udp"
        RelPath = ".tools/references/anlogic-vision/05_vision_bbox_template"
        KeyChecks = @("README.md", "import/dual_cam/bounding_box.v")
    },
    @{
        Id = "06_ph1p35_vision_baseline"
        Name = "PH1P35 Vision Baseline"
        Url = "https://github.com/Aurora-520/anlogic-ph1p35-vision"
        RelPath = ".tools/references/anlogic-vision/06_ph1p35_vision_baseline"
        KeyChecks = @("README.md", "rtl/isp/")
    }
)

$results = @()

foreach ($repo in $repositories) {
    $dest = Join-Path $repoRoot $repo.RelPath
    $parentDir = Split-Path -Parent $dest
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    Write-Host "`n----------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "Target: $($repo.Name) ($($repo.Id))" -ForegroundColor Yellow
    Write-Host "Path: $dest"
    Write-Host "URL: $($repo.Url)"

    $isCloned = Test-Path (Join-Path $dest ".git")
    $success = $false
    $commitSha = "N/A"
    $sizeMB = 0
    $errorMsg = ""

    if ($isCloned -and -not $ForceReclone) {
        Write-Host "  -> Already cloned. Checking HEAD commit..." -ForegroundColor Green
        try {
            $commitSha = (git -C $dest rev-parse HEAD 2>$null).Trim()
            $success = $true
        } catch {
            $errorMsg = $_.Exception.Message
        }
    } else {
        if (Test-Path $dest) {
            Write-Host "  -> Removing incomplete directory..." -ForegroundColor Gray
            Remove-Item -Path $dest -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host "  -> Running git clone --depth 1 --single-branch..." -ForegroundColor Cyan
        $cloneOutput = & git clone --depth 1 --single-branch $repo.Url $dest 2>&1
        if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $dest ".git"))) {
            $commitSha = (git -C $dest rev-parse HEAD 2>$null).Trim()
            $success = $true
            Write-Host "  -> Cloned successfully. Commit: $commitSha" -ForegroundColor Green
        } else {
            Write-Warning "  -> First attempt failed, retrying once..."
            Start-Sleep -Seconds 2
            $cloneOutput = & git clone --depth 1 --single-branch $repo.Url $dest 2>&1
            if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $dest ".git"))) {
                $commitSha = (git -C $dest rev-parse HEAD 2>$null).Trim()
                $success = $true
                Write-Host "  -> Retry clone succeeded. Commit: $commitSha" -ForegroundColor Green
            } else {
                $success = $false
                $errorMsg = ($cloneOutput -join "; ")
                Write-Host "  -> Clone failed: $errorMsg" -ForegroundColor Red
            }
        }
    }

    $keyChecksPassed = @()
    if (Test-Path $dest) {
        $measure = Get-ChildItem -Path $dest -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
        if ($measure -and $measure.Sum) {
            $sizeMB = [math]::Round($measure.Sum / 1MB, 2)
        }
        foreach ($check in $repo.KeyChecks) {
            $checkPath = Join-Path $dest $check
            if (Test-Path $checkPath) {
                $keyChecksPassed += $check
            }
        }
    }

    $results += [PSCustomObject]@{
        Id = $repo.Id
        Name = $repo.Name
        Success = $success
        Commit = $commitSha
        SizeMB = $sizeMB
        RelPath = $repo.RelPath
        KeyChecksPassed = ($keyChecksPassed -join ", ")
        Error = $errorMsg
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "Sync and Verification Summary:" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$results | Format-Table -Property Id, Success, Commit, SizeMB, KeyChecksPassed -AutoSize

$inventoryPath = Join-Path $repoRoot ".tools/references/anlogic-vision/inventory.json"
$inventoryDir = Split-Path -Parent $inventoryPath
if (-not (Test-Path $inventoryDir)) {
    New-Item -ItemType Directory -Path $inventoryDir -Force | Out-Null
}
$results | ConvertTo-Json -Depth 4 | Set-Content -Path $inventoryPath -Encoding UTF8
Write-Host "Inventory written to: $inventoryPath" -ForegroundColor Green