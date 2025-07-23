# Enrollment script that starts a new PowerShell session to avoid type conflicts

param(
    [Parameter(Mandatory=$true)]
    [string]$JwtFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseKeychain = $false
)

# Logging Function
function Write-EnrollmentLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $jwtFileName = [System.IO.Path]::GetFileNameWithoutExtension($JwtFile)
    $logFileName = "${timestamp}_${jwtFileName}.log"
    $logPath = Join-Path $PSScriptRoot "logs\$logFileName"
    
    # Ensure logs directory exists
    $logsDir = Join-Path $PSScriptRoot "logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    }
    
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $logPath -Value $logMessage
}

Write-EnrollmentLog "Starting enrollment in new session..."
Write-EnrollmentLog "======================================"

# Validate JWT file
if (-not (Test-Path $JwtFile)) {
    Write-EnrollmentLog "JWT file not found: $JwtFile" "ERROR"
    exit 1
}

$identityName = [System.IO.Path]::GetFileNameWithoutExtension($JwtFile)
Write-EnrollmentLog "Identity: $identityName"

# Create a temporary script
$tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
$scriptContent = @"
# Temporary enrollment script
Write-Host 'Running enrollment for: $identityName' -ForegroundColor Cyan

try {
    if (Test-Path '$PSScriptRoot\enroll-direct.ps1') {
        & '$PSScriptRoot\enroll-direct.ps1' -JwtFile '$JwtFile' $(if ($UseKeychain) { '-UseKeychain' })
    } else {
        Write-Host 'Direct enrollment script not found, using fallback' -ForegroundColor Yellow
        & '$PSScriptRoot\enroll-fallback.ps1' -JwtFile '$JwtFile' $(if ($UseKeychain) { '-UseKeychain' })
    }
} catch {
    Write-Host "Error: `$_" -ForegroundColor Red
}

Write-Host 'Press any key to continue...'
`$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
"@

Set-Content -Path $tempScript -Value $scriptContent

# Start new PowerShell window
Write-EnrollmentLog "Opening new PowerShell window..."
Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$tempScript`"" -Wait

# Clean up
Remove-Item $tempScript -Force -ErrorAction SilentlyContinue

# Verify results
Write-EnrollmentLog "Checking enrollment results..."
& "$PSScriptRoot\..\verification\verify-identity.ps1" -IdentityName $identityName