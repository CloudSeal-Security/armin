# Quick Access Entry Point for Ziti Auto-Enrollment
# This script provides easy access to the main enrollment functionality

param(
    [Parameter(Mandatory=$false)]
    [string]$JwtFile = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$UseKeychain = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Interactive = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verify = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$IdentityName = ""
)

# Logging Function
function Write-EnrollmentLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    
    # Use JWT filename if available, otherwise use "general"
    $logFileName = if ($JwtFile) {
        $jwtFileName = [System.IO.Path]::GetFileNameWithoutExtension($JwtFile)
        "${timestamp}_${jwtFileName}.log"
    } else {
        "${timestamp}_general.log"
    }
    
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

Write-EnrollmentLog "Ziti Auto-Enrollment MVP"
Write-EnrollmentLog "==========================="

# Show help if no parameters
if (-not $JwtFile -and -not $Interactive -and -not $Verify) {
    Write-Host "`nUsage Examples:" -ForegroundColor Yellow
    Write-Host "  .\enroll.ps1 -JwtFile 'identity.jwt'                    # Basic enrollment" -ForegroundColor White
    Write-Host "  .\enroll.ps1 -JwtFile 'identity.jwt' -UseKeychain       # Secure keychain enrollment" -ForegroundColor White
    Write-Host "  .\enroll.ps1 -Interactive                               # Interactive menu" -ForegroundColor White
    Write-Host "  .\enroll.ps1 -Verify -IdentityName 'identity'           # Verify enrollment" -ForegroundColor White
    
    Write-Host "`nOrganized Structure:" -ForegroundColor Yellow
    Write-Host "  docs/        - Complete documentation" -ForegroundColor White
    Write-Host "  core/        - Main enrollment scripts" -ForegroundColor White
    Write-Host "  verification/ - Testing and verification tools" -ForegroundColor White
    Write-Host "  support/     - Diagnostic and support tools" -ForegroundColor White
    Write-Host "  ui/          - User interfaces" -ForegroundColor White
    Write-Host "  advanced/    - Advanced tools and C# source" -ForegroundColor White
    
    Write-Host "`nFor detailed documentation: Get-Content docs\README.md" -ForegroundColor Cyan
    exit 0
}

# Interactive mode
if ($Interactive) {
    Write-EnrollmentLog "Starting interactive mode..."
    & "$PSScriptRoot\ui\interactive-menu.ps1"
    exit $LASTEXITCODE
}

# Verification mode
if ($Verify) {
    if (-not $IdentityName) {
        Write-EnrollmentLog "-IdentityName required for verification" "ERROR"
        exit 1
    }
    Write-EnrollmentLog "Verifying identity: $IdentityName"
    & "$PSScriptRoot\verification\verify-identity-quick.ps1" -IdentityName $IdentityName
    exit $LASTEXITCODE
}

# Enrollment mode
if (-not $JwtFile) {
    Write-EnrollmentLog "-JwtFile required for enrollment" "ERROR"
    exit 1
}

if (-not (Test-Path $JwtFile)) {
    Write-EnrollmentLog "JWT file not found: $JwtFile" "ERROR"
    exit 1
}

Write-EnrollmentLog "Enrollment Configuration:"
Write-EnrollmentLog "  JWT File: $JwtFile"
Write-EnrollmentLog "  Use Keychain: $UseKeychain"

# Detect if running in a service context (GPO/SCCM)
$isServiceContext = $false
try {
    # Check if running as SYSTEM or in non-interactive mode
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $isSystemAccount = $currentUser -like "*SYSTEM*" -or $currentUser -like "*NetworkService*"
    $isNonInteractive = [Environment]::UserInteractive -eq $false
    $isServiceContext = $isSystemAccount -or $isNonInteractive
} catch {
    # If we can't determine, assume interactive mode
    $isServiceContext = $false
}

# Run enrollment - Default to GPO mode for better reliability
Write-EnrollmentLog "Using GPO enrollment mode (default)"
if ($UseKeychain) {
    & "$PSScriptRoot\core\enroll-gpo.ps1" -JwtFile $JwtFile -UseKeychain
} else {
    & "$PSScriptRoot\core\enroll-gpo.ps1" -JwtFile $JwtFile
}

$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-EnrollmentLog "Enrollment completed successfully!"
    
    # Quick verification
    $identityName = [System.IO.Path]::GetFileNameWithoutExtension($JwtFile)
    Write-EnrollmentLog "Running quick verification..."
    & "$PSScriptRoot\verification\verify-identity-quick.ps1" -IdentityName $identityName
} else {
    Write-EnrollmentLog "Enrollment failed with exit code: $exitCode" "ERROR"
    Write-EnrollmentLog "Try troubleshooting:"
    Write-EnrollmentLog "  .\support\diagnose-issues.ps1"
}

exit $exitCode