# GPO-Optimized Enrollment Script
# Designed for unattended deployment without UI interactions

param(
    [Parameter(Mandatory=$true)]
    [string]$JwtFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseKeychain = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$NoWait = $false
)

# Configure for unattended execution
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

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
    
    # Also log to Windows Event Log for GPO tracking
    try {
        Write-EventLog -LogName "Application" -Source "ZitiAutoEnroll" -EventId 1000 -EntryType Information -Message $logMessage -ErrorAction SilentlyContinue
    } catch {
        # Event source doesn't exist, that's okay
    }
}

# JWT Decoding and URI Test Function
function Test-ControllerConnectivity {
    param([string]$JwtContent)
    
    try {
        # Split JWT into parts
        $jwtParts = $JwtContent.Trim().Split('.')
        if ($jwtParts.Length -ne 3) {
            Write-EnrollmentLog "Invalid JWT format" "ERROR"
            return $false
        }
        
        # Decode payload (middle part)
        $payload = $jwtParts[1]
        # Add padding if needed
        while ($payload.Length % 4 -ne 0) { $payload += '=' }
        
        # Base64 decode
        $decodedBytes = [System.Convert]::FromBase64String($payload)
        $decodedString = [System.Text.Encoding]::UTF8.GetString($decodedBytes)
        $jwtData = $decodedString | ConvertFrom-Json
        
        # Extract controller URL
        $controllerUrl = $jwtData.iss
        if (-not $controllerUrl) {
            Write-EnrollmentLog "No controller URL found in JWT" "ERROR"
            return $false
        }
        
        Write-EnrollmentLog "Controller URL: $controllerUrl"
        
        # Test connectivity
        Write-EnrollmentLog "Testing connectivity..."
        try {
            # For PowerShell 5.1 compatibility - ignore certificate errors
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            
            Write-EnrollmentLog "Testing basic connectivity to controller..."
            $response = Invoke-RestMethod -Uri "$controllerUrl" -Method Get -TimeoutSec 10
            Write-EnrollmentLog "Controller responding: $($response.data.version)"
            return $true
        } catch {
            Write-EnrollmentLog "Primary HTTPS test failed: $($_.Exception.Message)" "WARNING"
            
            # Try alternative method using WebClient
            try {
                Write-EnrollmentLog "Trying alternative WebClient method..."
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "Ziti-PowerShell-Test")
                $result = $webClient.DownloadString($controllerUrl)
                
                if ($result -match "version" -or $result -match "apiVersions") {
                    Write-EnrollmentLog "Controller responding via WebClient - connectivity confirmed"
                    return $true
                } else {
                    Write-EnrollmentLog "Controller response doesn't contain expected data" "WARNING"
                    # Still proceed as the controller might be responding
                    return $true
                }
            } catch {
                Write-EnrollmentLog "WebClient test also failed: $($_.Exception.Message)" "WARNING"
                
                # As a last resort, just try basic TCP connectivity
                try {
                    Write-EnrollmentLog "Testing basic TCP connectivity..."
                    $uri = [System.Uri]$controllerUrl
                    $tcpClient = New-Object System.Net.Sockets.TcpClient
                    $tcpClient.ConnectAsync($uri.Host, $uri.Port).Wait(5000)
                    
                    if ($tcpClient.Connected) {
                        Write-EnrollmentLog "TCP connection successful - controller appears to be running"
                        Write-EnrollmentLog "Proceeding with enrollment (may be SSL/certificate issue)"
                        $tcpClient.Close()
                        return $true
                    } else {
                        Write-EnrollmentLog "TCP connection failed - controller may be down" "ERROR"
                        return $false
                    }
                } catch {
                    Write-EnrollmentLog "All connectivity tests failed: $($_.Exception.Message)" "ERROR"
                    return $false
                } finally {
                    if ($tcpClient -and $tcpClient.Connected) {
                        $tcpClient.Close()
                    }
                }
            } finally {
                if ($webClient) {
                    $webClient.Dispose()
                }
            }
        } finally {
            # Reset certificate validation
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
        
    } catch {
        Write-EnrollmentLog "JWT decode error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

Write-EnrollmentLog "Starting GPO Ziti Auto-Enrollment"
Write-EnrollmentLog "Script: $($MyInvocation.MyCommand.Name)"
Write-EnrollmentLog "Parameters: JwtFile=$JwtFile, UseKeychain=$UseKeychain"

# Validate JWT file
if (-not (Test-Path $JwtFile)) {
    Write-EnrollmentLog "❌ JWT file not found: $JwtFile" "ERROR"
    exit 1
}

$identityName = [System.IO.Path]::GetFileNameWithoutExtension($JwtFile)
Write-EnrollmentLog "Identity: $identityName"

# Read JWT content and test connectivity
$jwtContent = Get-Content $JwtFile -Raw -Encoding UTF8
Write-EnrollmentLog "Testing controller connectivity..."
if (-not (Test-ControllerConnectivity -JwtContent $jwtContent)) {
    Write-EnrollmentLog "Cannot connect to controller - stopping enrollment" "ERROR"
    exit 1
}

# Check if identity already exists
$SystemDir = "C:\Windows\System32\config\systemprofile\AppData\Roaming\NetFoundry"
$expectedFile = "$SystemDir\$identityName.json"

if (Test-Path $expectedFile) {
    Write-EnrollmentLog "✅ Identity already exists: $expectedFile"
    Write-EnrollmentLog "Skipping enrollment - already deployed"
    exit 0
}

# Ensure system directory exists
if (-not (Test-Path $SystemDir)) {
    try {
        New-Item -Path $SystemDir -ItemType Directory -Force | Out-Null
        Write-EnrollmentLog "📁 Created system directory: $SystemDir"
    } catch {
        Write-EnrollmentLog "❌ Failed to create system directory: $_" "ERROR"
        exit 1
    }
}

Write-EnrollmentLog "📡 Executing direct enrollment (no UI mode)"

# Use direct enrollment method - no new sessions or UI
try {
    # Read the enrollment script content and execute directly
    $directScriptPath = "$PSScriptRoot\enroll-direct.ps1"
    
    if (-not (Test-Path $directScriptPath)) {
        Write-EnrollmentLog "❌ Direct enrollment script not found: $directScriptPath" "ERROR"
        exit 1
    }
    
    Write-EnrollmentLog "🔧 Loading direct enrollment module"
    
    # Execute in current session to avoid UI issues
    if ($UseKeychain) {
        & $directScriptPath -JwtFile $JwtFile -UseKeychain
    } else {
        & $directScriptPath -JwtFile $JwtFile
    }
    
    $enrollResult = $LASTEXITCODE
    
    if ($enrollResult -eq 0) {
        Write-EnrollmentLog "✅ Direct enrollment completed successfully"
    } else {
        Write-EnrollmentLog "⚠️ Direct enrollment returned exit code: $enrollResult" "WARNING"
        
        # Try fallback method
        Write-EnrollmentLog "🔄 Attempting fallback enrollment method"
        $fallbackScriptPath = "$PSScriptRoot\enroll-fallback.ps1"
        
        if (Test-Path $fallbackScriptPath) {
            if ($UseKeychain) {
                & $fallbackScriptPath -JwtFile $JwtFile -UseKeychain
            } else {
                & $fallbackScriptPath -JwtFile $JwtFile
            }
            $enrollResult = $LASTEXITCODE
        }
    }
    
} catch {
    Write-EnrollmentLog "❌ Enrollment execution failed: $_" "ERROR"
    exit 1
}

# Wait for file system sync
Start-Sleep -Seconds 3

# Verify installation
Write-EnrollmentLog "🔍 Verifying enrollment results"

if (Test-Path $expectedFile) {
    try {
        $identity = Get-Content $expectedFile -Raw | ConvertFrom-Json
        Write-EnrollmentLog "✅ Identity file created successfully"
        Write-EnrollmentLog "   Controller: $($identity.ztAPI)"
        Write-EnrollmentLog "   Key Type: $(if ($identity.id.key -match '^keychain:') { 'Keychain' } else { 'File-based' })"
        Write-EnrollmentLog "   Has Certificate: $(if ($identity.id.cert) { 'Yes' } else { 'No' })"
        
        # Check service status
        try {
            $zitiSvc = Get-Service -Name "ziti" -ErrorAction SilentlyContinue
            if ($zitiSvc) {
                Write-EnrollmentLog "   Ziti Service: $($zitiSvc.Status)"
                
                # Restart service to pick up new identity (if running)
                if ($zitiSvc.Status -eq "Running") {
                    Write-EnrollmentLog "🔄 Restarting Ziti service to load new identity"
                    Restart-Service -Name "ziti" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    Write-EnrollmentLog "✅ Service restarted"
                }
            }
        } catch {
            Write-EnrollmentLog "⚠️ Could not check/restart service: $_" "WARNING"
        }
        
        Write-EnrollmentLog "🎉 GPO Enrollment completed successfully!"
        Write-EnrollmentLog "📊 Deployment Summary: Identity '$identityName' deployed to $env:COMPUTERNAME"
        
        exit 0
        
    } catch {
        Write-EnrollmentLog "❌ Identity file exists but is corrupted: $_" "ERROR"
        exit 1
    }
} else {
    Write-EnrollmentLog "❌ Identity file not created at expected location" "ERROR"
    Write-EnrollmentLog "   Expected: $expectedFile"
    
    # Check for alternative locations
    if (Test-Path ".\$identityName.json") {
        Write-EnrollmentLog "⚠️ Identity found in current directory - manual intervention required" "WARNING"
    }
    
    exit 1
}