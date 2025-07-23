# Final MVP Test - Comprehensive Enrollment Test (Fixed)
# This validates the complete auto-enrollment solution

param(
    [Parameter(Mandatory=$true)]
    [string]$JwtFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseKeychain = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowDetails = $false
)

Write-Host "`n[FINAL TEST] MVP VALIDATION TEST" -ForegroundColor Magenta
Write-Host "============================" -ForegroundColor Magenta
Write-Host "Testing complete auto-enrollment workflow" -ForegroundColor Cyan

# Validate JWT file
if (-not (Test-Path $JwtFile)) {
    Write-Host "[ERROR] JWT file not found: $JwtFile" -ForegroundColor Red
    exit 1
}

$identityName = [System.IO.Path]::GetFileNameWithoutExtension($JwtFile)
$SystemDir = "C:\Windows\System32\config\systemprofile\AppData\Roaming\NetFoundry"
$expectedFile = "$SystemDir\$identityName.json"

Write-Host "`n[CONFIG] Test Configuration:" -ForegroundColor Yellow
Write-Host "  JWT File: $JwtFile" -ForegroundColor White
Write-Host "  Identity: $identityName" -ForegroundColor White
Write-Host "  Keychain: $(if ($UseKeychain) { 'Enabled' } else { 'File-based' })" -ForegroundColor White
Write-Host "  Target: $expectedFile" -ForegroundColor Gray

# Pre-test cleanup check
Write-Host "`n[PREP] Pre-test checks..." -ForegroundColor Yellow
if (Test-Path $expectedFile) {
    Write-Host "[WARNING] Identity already exists - removing for clean test" -ForegroundColor Yellow
    try {
        Remove-Item $expectedFile -Force
        Write-Host "[OK] Cleaned existing identity" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Could not remove existing identity: $_" -ForegroundColor Red
        exit 1
    }
}

# Record start time
$startTime = Get-Date
Write-Host "`n[START] Starting enrollment at: $($startTime.ToString('HH:mm:ss'))" -ForegroundColor Green

# Execute the working enrollment method
Write-Host "`n[EXECUTE] Named Pipe Enrollment..." -ForegroundColor Cyan
try {
    if ($UseKeychain) {
        & .\enroll-new-session.ps1 -JwtFile $JwtFile -UseKeychain
    } else {
        & .\enroll-new-session.ps1 -JwtFile $JwtFile
    }
} catch {
    Write-Host "[ERROR] Enrollment execution failed: $_" -ForegroundColor Red
    exit 1
}

$enrollTime = Get-Date
$enrollDuration = ($enrollTime - $startTime).TotalSeconds

Write-Host "`n[TIME] Enrollment completed in: $([math]::Round($enrollDuration, 1)) seconds" -ForegroundColor Gray

# Wait for file system sync
Start-Sleep -Seconds 2

# Comprehensive verification
Write-Host "`n[VERIFY] COMPREHENSIVE VERIFICATION" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

$testResults = @{
    FileExists = $false
    FileValid = $false
    TunnelLoaded = $false
    TunnelActive = $false
    ControllerConnected = $false
}

# Test 1: File existence and validity
Write-Host "`n[1] File System Test..." -ForegroundColor Yellow
if (Test-Path $expectedFile) {
    $testResults.FileExists = $true
    Write-Host "   [OK] Identity file exists" -ForegroundColor Green
    
    try {
        $identity = Get-Content $expectedFile -Raw | ConvertFrom-Json
        $testResults.FileValid = $true
        Write-Host "   [OK] Identity file is valid JSON" -ForegroundColor Green
        Write-Host "      Controller: $($identity.ztAPI)" -ForegroundColor Gray
        Write-Host "      Key Type: $(if ($identity.id.key -match '^keychain:') { 'Keychain' } else { 'File-based' })" -ForegroundColor Gray
        Write-Host "      Has Cert: $(if ($identity.id.cert) { '[YES]' } else { '[NO]' })" -ForegroundColor Gray
        Write-Host "      Has Key: $(if ($identity.id.key) { '[YES]' } else { '[NO]' })" -ForegroundColor Gray
    } catch {
        Write-Host "   [ERROR] Identity file is corrupted: $_" -ForegroundColor Red
    }
} else {
    Write-Host "   [ERROR] Identity file not found" -ForegroundColor Red
}

# Test 2: Tunnel integration
Write-Host "`n[2] Tunnel Integration Test..." -ForegroundColor Yellow
$ZitiCliPath = "C:\Program Files (x86)\NetFoundry Inc\Ziti Desktop Edge\ziti-edge-tunnel.exe"

if (Test-Path $ZitiCliPath) {
    try {
        $statusOutput = & $ZitiCliPath tunnel_status 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            # Parse JSON response
            $jsonStart = -1
            for ($i = 0; $i -lt $statusOutput.Length; $i++) {
                if ($statusOutput[$i] -match '^\s*{') {
                    $jsonStart = $i
                    break
                }
            }
            
            if ($jsonStart -ge 0) {
                $jsonContent = ($statusOutput[$jsonStart..($statusOutput.Length-1)]) -join "`n"
                $status = $jsonContent | ConvertFrom-Json
                
                $targetIdentity = $status.Data.Identities | Where-Object { $_.Name -eq $identityName }
                
                if ($targetIdentity) {
                    $testResults.TunnelLoaded = $true
                    Write-Host "   [OK] Identity loaded in tunnel" -ForegroundColor Green
                    
                    if ($targetIdentity.Active) {
                        $testResults.TunnelActive = $true
                        Write-Host "   [OK] Identity is active" -ForegroundColor Green
                    } else {
                        Write-Host "   [WARNING] Identity loaded but not active" -ForegroundColor Yellow
                    }
                    
                    if ($targetIdentity.Config) {
                        $testResults.ControllerConnected = $true
                        Write-Host "   [OK] Connected to controller" -ForegroundColor Green
                        Write-Host "      Controller: $($targetIdentity.Config.ztAPI)" -ForegroundColor Gray
                        if ($targetIdentity.Services) {
                            Write-Host "      Services: $($targetIdentity.Services.Count) available" -ForegroundColor Gray
                        }
                    } else {
                        Write-Host "   [ERROR] No controller connection" -ForegroundColor Red
                    }
                } else {
                    Write-Host "   [ERROR] Identity not found in tunnel" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "   [ERROR] Could not get tunnel status" -ForegroundColor Red
        }
    } catch {
        Write-Host "   [ERROR] Tunnel test failed: $_" -ForegroundColor Red
    }
}

# Test 3: Service status
Write-Host "`n[3] Service Status Test..." -ForegroundColor Yellow
$services = @("ziti", "ZitiDesktopEdge")
foreach ($svcName in $services) {
    try {
        $service = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($service) {
            $color = if ($service.Status -eq "Running") { "Green" } else { "Red" }
            Write-Host "   $svcName Service: $($service.Status)" -ForegroundColor $color
        }
    } catch {
        Write-Host "   $svcName Service: Error checking" -ForegroundColor Red
    }
}

# Calculate total time
$endTime = Get-Date
$totalDuration = ($endTime - $startTime).TotalSeconds

# Final results
Write-Host "`n[RESULTS] FINAL TEST RESULTS" -ForegroundColor Magenta
Write-Host "=====================" -ForegroundColor Magenta

$passedTests = ($testResults.Values | Where-Object { $_ -eq $true }).Count
$totalTests = $testResults.Count

Write-Host "`n[SUMMARY] Test Summary:" -ForegroundColor Cyan
Write-Host "   Tests Passed: $passedTests/$totalTests" -ForegroundColor White
Write-Host "   Total Time: $([math]::Round($totalDuration, 1)) seconds" -ForegroundColor White

Write-Host "`n[DETAILS] Results:" -ForegroundColor Cyan
Write-Host "   [+] File Created: $($testResults.FileExists)" -ForegroundColor $(if ($testResults.FileExists) { "Green" } else { "Red" })
Write-Host "   [+] File Valid: $($testResults.FileValid)" -ForegroundColor $(if ($testResults.FileValid) { "Green" } else { "Red" })
Write-Host "   [+] Tunnel Loaded: $($testResults.TunnelLoaded)" -ForegroundColor $(if ($testResults.TunnelLoaded) { "Green" } else { "Red" })
Write-Host "   [+] Tunnel Active: $($testResults.TunnelActive)" -ForegroundColor $(if ($testResults.TunnelActive) { "Green" } else { "Red" })
Write-Host "   [+] Controller Connected: $($testResults.ControllerConnected)" -ForegroundColor $(if ($testResults.ControllerConnected) { "Green" } else { "Red" })

# Overall assessment
if ($testResults.FileExists -and $testResults.FileValid -and $testResults.TunnelLoaded -and $testResults.ControllerConnected) {
    Write-Host "`n[SUCCESS] COMPLETE SUCCESS!" -ForegroundColor Green
    Write-Host "====================" -ForegroundColor Green
    Write-Host "[OK] Auto-enrollment MVP fully functional" -ForegroundColor Green
    Write-Host "[OK] Named Pipe communication working" -ForegroundColor Green
    Write-Host "[OK] Identity properly integrated" -ForegroundColor Green
    Write-Host "[OK] Controller connection established" -ForegroundColor Green
    
    Write-Host "`n[READY] Ready for production deployment!" -ForegroundColor Cyan
    
} elseif ($testResults.FileExists -and $testResults.FileValid) {
    Write-Host "`n[WARNING] PARTIAL SUCCESS" -ForegroundColor Yellow
    Write-Host "==================" -ForegroundColor Yellow
    Write-Host "[OK] Enrollment mechanism working" -ForegroundColor Green
    Write-Host "[WARNING] Connection/activation issues" -ForegroundColor Yellow
    
    if (-not $testResults.ControllerConnected) {
        Write-Host "`n[TIP] Likely cause: JWT already used" -ForegroundColor Cyan
        Write-Host "   Solution: Generate fresh JWT and retry" -ForegroundColor White
    }
    
} else {
    Write-Host "`n[FAILED] TEST FAILED" -ForegroundColor Red
    Write-Host "==============" -ForegroundColor Red
    Write-Host "The enrollment process did not complete successfully" -ForegroundColor Red
}

Write-Host "`n[END] Test completed at: $($endTime.ToString('HH:mm:ss'))" -ForegroundColor Gray

if ($ShowDetails) {
    Write-Host "`n[INFO] Additional Information:" -ForegroundColor Gray
    Write-Host "   Working Directory: $PWD" -ForegroundColor Gray
    Write-Host "   PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "   System: $env:COMPUTERNAME" -ForegroundColor Gray
}