# Quick verification script for enrollment status

param(
    [Parameter(Mandatory=$true)]
    [string]$IdentityName
)

Write-Host "`n[CHECK] Quick Enrollment Check for: $IdentityName" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Check if identity file exists
$SystemDir = "C:\Windows\System32\config\systemprofile\AppData\Roaming\NetFoundry"
$identityFile = "$SystemDir\$IdentityName.json"

Write-Host "`n[FILES] Checking identity file..." -ForegroundColor Yellow
if (Test-Path $identityFile) {
    Write-Host "[OK] Identity file EXISTS: $identityFile" -ForegroundColor Green
    
    try {
        $identity = Get-Content $identityFile -Raw | ConvertFrom-Json
        Write-Host "   Controller: $($identity.ztAPI)" -ForegroundColor White
        Write-Host "   Has Certificate: $(if ($identity.id.cert) { '[YES]' } else { '[NO]' })" -ForegroundColor White
        Write-Host "   Key Type: $(if ($identity.id.key -match '^keychain:') { '[KEYCHAIN]' } else { '[FILE]' })" -ForegroundColor White
        
        Write-Host "`n[SUCCESS] ENROLLMENT SUCCESSFUL!" -ForegroundColor Green
        Write-Host "The identity was enrolled correctly." -ForegroundColor Green
        
        Write-Host "`n[TIP] To make it appear in the UI:" -ForegroundColor Yellow
        Write-Host "   Option 1: Restart the UI from system tray" -ForegroundColor White
        Write-Host "   Option 2: Run these commands:" -ForegroundColor White
        Write-Host "      Stop-Service ZitiDesktopEdge -Force" -ForegroundColor Gray
        Write-Host "      Start-Service ZitiDesktopEdge" -ForegroundColor Gray
        
        return $true
        
    } catch {
        Write-Host "[WARNING] File exists but could not parse: $_" -ForegroundColor Yellow
        return $false
    }
} else {
    Write-Host "[ERROR] Identity file NOT FOUND" -ForegroundColor Red
    Write-Host "   Expected location: $identityFile" -ForegroundColor Gray
    
    # Check current directory
    if (Test-Path ".\$IdentityName.json") {
        Write-Host "`n[WARNING] Found in current directory!" -ForegroundColor Yellow
        Write-Host "   Move it to: $SystemDir" -ForegroundColor White
        Write-Host "   Command: Copy-Item `".\$IdentityName.json`" `"$identityFile`"" -ForegroundColor Gray
    }
    
    return $false
}

# Quick service check
Write-Host "`n[SERVICE] Service Status:" -ForegroundColor Yellow
try {
    $zitiSvc = Get-Service -Name "ziti" -ErrorAction SilentlyContinue
    $uiSvc = Get-Service -Name "ZitiDesktopEdge" -ErrorAction SilentlyContinue
    
    if ($zitiSvc) {
        Write-Host "   Tunnel Service: $($zitiSvc.Status)" -ForegroundColor $(if ($zitiSvc.Status -eq 'Running') { 'Green' } else { 'Red' })
    }
    if ($uiSvc) {
        Write-Host "   UI Service: $($uiSvc.Status)" -ForegroundColor $(if ($uiSvc.Status -eq 'Running') { 'Green' } else { 'Red' })
    }
} catch {
    Write-Host "   Could not check services" -ForegroundColor Gray
}