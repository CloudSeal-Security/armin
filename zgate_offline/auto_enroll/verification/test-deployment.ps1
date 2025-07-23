# FINAL DEPLOYMENT TEST
# Complete validation of the auto-enrollment solution for production deployment

param(
    [Parameter(Mandatory=$false)]
    [string]$JwtFile = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$UseKeychain = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$CleanupAfter = $false
)

Write-Host "`n🏆 FINAL DEPLOYMENT VALIDATION" -ForegroundColor Magenta
Write-Host "===============================" -ForegroundColor Magenta
Write-Host "Complete production readiness test" -ForegroundColor Cyan

# If no JWT provided, show available options
if (-not $JwtFile) {
    Write-Host "`n📁 Available JWT files:" -ForegroundColor Yellow
    $jwtFiles = Get-ChildItem -Filter "*.jwt" | Select-Object -First 10
    
    if ($jwtFiles.Count -eq 0) {
        Write-Host "❌ No JWT files found in current directory" -ForegroundColor Red
        Write-Host "Please place a JWT file and specify with -JwtFile parameter" -ForegroundColor Yellow
        exit 1
    }
    
    for ($i = 0; $i -lt $jwtFiles.Count; $i++) {
        Write-Host "   $($i+1). $($jwtFiles[$i].Name)" -ForegroundColor White
    }
    
    $selection = Read-Host "`nSelect JWT file (1-$($jwtFiles.Count))"
    $selectedIndex = [int]$selection - 1
    
    if ($selectedIndex -lt 0 -or $selectedIndex -ge $jwtFiles.Count) {
        Write-Host "❌ Invalid selection" -ForegroundColor Red
        exit 1
    }
    
    $JwtFile = $jwtFiles[$selectedIndex].FullName
}

Write-Host "`n📋 Final Test Configuration:" -ForegroundColor Cyan
Write-Host "   JWT File: $JwtFile" -ForegroundColor White
Write-Host "   Use Keychain: $UseKeychain" -ForegroundColor White
Write-Host "   Cleanup After: $CleanupAfter" -ForegroundColor White

# Comprehensive test scenarios
$testScenarios = @(
    @{
        Name = "Production Scenario A"
        Description = "File-based storage (standard deployment)"
        UseKeychain = $false
    },
    @{
        Name = "Production Scenario B" 
        Description = "Keychain storage (enhanced security)"
        UseKeychain = $true
    }
)

$overallResults = @()

foreach ($scenario in $testScenarios) {
    if ($UseKeychain -and -not $scenario.UseKeychain) {
        continue # Skip if user specifically wants keychain
    }
    if (-not $UseKeychain -and $scenario.UseKeychain -and -not $scenario.Name.Contains("A")) {
        continue # Skip keychain test if not requested, except for comprehensive test
    }
    
    Write-Host "`n" + "="*50 -ForegroundColor Magenta
    Write-Host "🧪 $($scenario.Name)" -ForegroundColor Magenta
    Write-Host "$($scenario.Description)" -ForegroundColor Cyan
    Write-Host "="*50 -ForegroundColor Magenta
    
    # Generate unique test identity name
    $testIdentity = "test-$(Get-Random)-$([System.DateTime]::Now.ToString('HHmmss'))"
    $tempJwt = "$testIdentity.jwt"
    
    try {
        # Copy JWT with new name for testing
        Copy-Item $JwtFile $tempJwt -Force
        
        Write-Host "`n🚀 Testing: $testIdentity" -ForegroundColor Green
        
        # Run the comprehensive test
        if ($scenario.UseKeychain) {
            & "$PSScriptRoot\test-complete.ps1" -JwtFile $tempJwt -UseKeychain
        } else {
            & "$PSScriptRoot\test-complete.ps1" -JwtFile $tempJwt
        }
        
        # Capture results
        $SystemDir = "C:\Windows\System32\config\systemprofile\AppData\Roaming\NetFoundry"
        $identityFile = "$SystemDir\$testIdentity.json"
        
        $result = @{
            Scenario = $scenario.Name
            Identity = $testIdentity
            Success = (Test-Path $identityFile)
            Timestamp = Get-Date
        }
        
        if ($result.Success) {
            Write-Host "`n✅ $($scenario.Name) - PASSED" -ForegroundColor Green
        } else {
            Write-Host "`n❌ $($scenario.Name) - FAILED" -ForegroundColor Red
        }
        
        $overallResults += $result
        
        # Cleanup test identity if requested
        if ($CleanupAfter -and (Test-Path $identityFile)) {
            Remove-Item $identityFile -Force -ErrorAction SilentlyContinue
            Write-Host "🗑️  Cleaned up test identity" -ForegroundColor Gray
        }
        
    } finally {
        # Clean up temp JWT
        Remove-Item $tempJwt -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "`n⏳ Waiting before next test..." -ForegroundColor Gray
    Start-Sleep -Seconds 3
}

# Final assessment
Write-Host "`n" + "="*60 -ForegroundColor Magenta
Write-Host "🏆 FINAL DEPLOYMENT ASSESSMENT" -ForegroundColor Magenta
Write-Host "="*60 -ForegroundColor Magenta

$successCount = ($overallResults | Where-Object { $_.Success }).Count
$totalTests = $overallResults.Count

Write-Host "`n📊 Overall Results:" -ForegroundColor Cyan
Write-Host "   Tests Run: $totalTests" -ForegroundColor White
Write-Host "   Successful: $successCount" -ForegroundColor Green
Write-Host "   Failed: $($totalTests - $successCount)" -ForegroundColor Red
Write-Host "   Success Rate: $([math]::Round(($successCount / $totalTests) * 100, 1))%" -ForegroundColor White

foreach ($result in $overallResults) {
    $status = if ($result.Success) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($result.Success) { "Green" } else { "Red" }
    Write-Host "   $($result.Scenario): $status" -ForegroundColor $color
}

# Production readiness verdict
if ($successCount -eq $totalTests) {
    Write-Host "`n🎉 PRODUCTION READY!" -ForegroundColor Green
    Write-Host "===================" -ForegroundColor Green
    Write-Host "🚀 The auto-enrollment solution is fully validated" -ForegroundColor Green
    Write-Host "🚀 All test scenarios passed successfully" -ForegroundColor Green
    Write-Host "🚀 Ready for enterprise deployment" -ForegroundColor Green
    
    Write-Host "`n📦 Deployment Package Contents:" -ForegroundColor Cyan
    Write-Host "   Core Scripts:" -ForegroundColor White
    Write-Host "   - enroll-new-session.ps1 (main execution)" -ForegroundColor Gray
    Write-Host "   - run-auto-enroll-mvp-fixed.ps1 (core logic)" -ForegroundColor Gray
    Write-Host "   - test-named-pipe-enroll.ps1 (fallback)" -ForegroundColor Gray
    Write-Host "   Validation Tools:" -ForegroundColor White
    Write-Host "   - final-test-fixed.ps1 (comprehensive test)" -ForegroundColor Gray
    Write-Host "   - quick-verify.ps1 (quick validation)" -ForegroundColor Gray
    Write-Host "   Support Tools:" -ForegroundColor White
    Write-Host "   - restart-ui.ps1 (UI restart)" -ForegroundColor Gray
    Write-Host "   - diagnose-connection.ps1 (troubleshooting)" -ForegroundColor Gray
    
} elseif ($successCount > 0) {
    Write-Host "`n⚠️  PARTIAL SUCCESS" -ForegroundColor Yellow
    Write-Host "==================" -ForegroundColor Yellow
    Write-Host "Some scenarios passed, review failed tests" -ForegroundColor Yellow
    
} else {
    Write-Host "`n❌ NOT READY" -ForegroundColor Red
    Write-Host "=============" -ForegroundColor Red
    Write-Host "All tests failed - requires investigation" -ForegroundColor Red
}

Write-Host "`n📝 Test completed: $(Get-Date)" -ForegroundColor Gray
Write-Host "💡 For deployment guidance, see MVP-TEST-README.md" -ForegroundColor Cyan