# PowerShell Script to Pull Expense Tracker Export Files from Android Emulator
# Run this script from your project directory to automatically pull exported files

$ADB_PATH = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$EMULATOR_DOWNLOAD_PATH = "/storage/emulated/0/Download"
$LOCAL_EXPORTS_DIR = ".\exports"

Write-Host "🚀 Expense Tracker Export Puller" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# Check if ADB exists
if (!(Test-Path $ADB_PATH)) {
    Write-Host "❌ ADB not found at $ADB_PATH" -ForegroundColor Red
    Write-Host "Please make sure Android SDK is properly installed." -ForegroundColor Yellow
    exit 1
}

# Check if device is connected
$devices = & $ADB_PATH devices
if ($devices -notmatch "emulator-\d+\s+device") {
    Write-Host "❌ No Android emulator detected" -ForegroundColor Red
    Write-Host "Please start your Android emulator first." -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Android emulator detected" -ForegroundColor Green

# Create local exports directory if it doesn't exist
if (!(Test-Path $LOCAL_EXPORTS_DIR)) {
    New-Item -ItemType Directory -Path $LOCAL_EXPORTS_DIR | Out-Null
    Write-Host "📁 Created exports directory: $LOCAL_EXPORTS_DIR" -ForegroundColor Blue
}

# List available MoneyManager files
Write-Host "📋 Checking for ExpenseTracker export files..." -ForegroundColor Yellow
$files = & $ADB_PATH shell "ls -la $EMULATOR_DOWNLOAD_PATH/ExpenseTracker* 2>/dev/null"

if ($LASTEXITCODE -ne 0 -or $files -eq $null) {
    Write-Host "❌ No ExpenseTracker export files found in emulator Downloads folder" -ForegroundColor Red
    Write-Host "💡 Make sure you've exported some files from the app first." -ForegroundColor Yellow
    exit 1
}

Write-Host "📁 Found export files:" -ForegroundColor Green
$files | ForEach-Object { Write-Host "   $_" -ForegroundColor Cyan }

# Pull all ExpenseTracker files
Write-Host "`n🔄 Pulling files to local directory..." -ForegroundColor Yellow

$fileList = & $ADB_PATH shell "ls $EMULATOR_DOWNLOAD_PATH/ExpenseTracker* 2>/dev/null"
$pulledCount = 0

foreach ($file in $fileList) {
    $fileName = Split-Path $file -Leaf
    $localPath = Join-Path $LOCAL_EXPORTS_DIR $fileName
    
    Write-Host "⬇️  Pulling: $fileName" -ForegroundColor Blue
    & $ADB_PATH pull $file $localPath
    
    if ($LASTEXITCODE -eq 0) {
        $pulledCount++
        Write-Host "✅ Successfully pulled: $fileName" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to pull: $fileName" -ForegroundColor Red
    }
}

Write-Host "`n🎉 Export Complete!" -ForegroundColor Green
Write-Host "📊 Pulled $pulledCount files to: $LOCAL_EXPORTS_DIR" -ForegroundColor Green

# List pulled files
Write-Host "`n📄 Local files:" -ForegroundColor Yellow
Get-ChildItem $LOCAL_EXPORTS_DIR -Name "ExpenseTracker*" | ForEach-Object { 
    Write-Host "   $_" -ForegroundColor Cyan 
}

# Offer to open the folder
Write-Host "`n💡 Tip: You can now open these files in your browser or Excel!" -ForegroundColor Yellow
$openFolder = Read-Host "Would you like to open the exports folder? (y/n)"
if ($openFolder -eq "y" -or $openFolder -eq "Y") {
    Start-Process (Resolve-Path $LOCAL_EXPORTS_DIR)
}

Write-Host "`n💡 Tip: Open PDF files with any PDF viewer, or import CSV files into Excel!" -ForegroundColor Yellow 