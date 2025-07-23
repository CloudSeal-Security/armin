# Fixed PowerShell Wrapper for Auto-Enrollment MVP
# Handles pipe reconnection and better response parsing

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

Write-EnrollmentLog "Auto-Enrollment MVP Launcher (Fixed)"
Write-EnrollmentLog "====================================="

# Validate JWT file
if (-not (Test-Path $JwtFile)) {
    Write-EnrollmentLog "JWT file not found: $JwtFile" "ERROR"
    exit 1
}

# Fixed C# code with better error handling
$csharpCode = @'
using System;
using System.IO;
using System.IO.Pipes;
using System.Text;
using System.Threading.Tasks;
using System.Text.RegularExpressions;

public class SimpleJsonBuilder
{
    public static string BuildEnrollmentJson(string identityName, string jwtContent, bool useKeychain)
    {
        // Escape JWT content for JSON
        string escapedJwt = jwtContent
            .Replace("\\", "\\\\")
            .Replace("\"", "\\\"")
            .Replace("\n", "")
            .Replace("\r", "")
            .Replace("\t", "");
        
        return string.Format(@"{{
    ""Command"": ""AddIdentity"",
    ""Data"": {{
        ""UseKeychain"": {0},
        ""IdentityFilename"": ""{1}"",
        ""JwtContent"": ""{2}"",
        ""Key"": null,
        ""Certificate"": null,
        ""ControllerURL"": null
    }}
}}", useKeychain.ToString().ToLower(), identityName, escapedJwt);
    }
    
    public static string BuildEnableJson(string identifier)
    {
        return string.Format(@"{{
    ""Command"": ""IdentityOnOff"",
    ""Data"": {{
        ""OnOff"": true,
        ""Identifier"": ""{0}""
    }}
}}", identifier);
    }
}

public class AutoEnrollMVP
{
    private const string IPC_PIPE = "ziti-edge-tunnel.sock";
    
    public static async Task<bool> EnrollIdentity(string jwtContent, string identityName, bool useKeychain)
    {
        Console.WriteLine("[MVP] Starting enrollment process...");
        bool enrollmentSuccess = false;
        string enrolledIdentifier = null;
        
        // Step 1: Enrollment
        try
        {
            using (var pipeClient = new NamedPipeClientStream(".", IPC_PIPE, PipeDirection.InOut))
            {
                Console.WriteLine("[MVP] Connecting for enrollment...");
                await pipeClient.ConnectAsync(5000);
                Console.WriteLine("[MVP] ✅ Connected to IPC pipe");
                
                using (var writer = new StreamWriter(pipeClient) { AutoFlush = true })
                using (var reader = new StreamReader(pipeClient))
                {
                    // Send enrollment command
                    Console.WriteLine("[MVP] Sending AddIdentity command...");
                    string enrollJson = SimpleJsonBuilder.BuildEnrollmentJson(identityName, jwtContent, useKeychain);
                    
                    await writer.WriteLineAsync(enrollJson);
                    
                    // Read response
                    Console.WriteLine("[MVP] Reading response...");
                    string response = await reader.ReadLineAsync();
                    
                    if (string.IsNullOrEmpty(response))
                    {
                        Console.WriteLine("[MVP] ❌ Empty response received");
                        return false;
                    }
                    
                    Console.WriteLine("[MVP] Response: " + response.Substring(0, Math.Min(response.Length, 200)) + "...");
                    
                    // Check for success
                    if (response.Contains("\"Success\":true") || response.Contains("\"Code\":0") || response.Contains("\"Code\": 0"))
                    {
                        Console.WriteLine("[MVP] ✅ Enrollment successful!");
                        enrollmentSuccess = true;
                        
                        // Try multiple patterns to extract identifier
                        var patterns = new string[] {
                            "\"Identifier\"\\s*:\\s*\"([^\"]+)\"",
                            "\"identifier\"\\s*:\\s*\"([^\"]+)\"",
                            "\"Id\"\\s*:\\s*\"([^\"]+)\"",
                            "\"id\"\\s*:\\s*\"([^\"]+)\""
                        };
                        
                        foreach (var pattern in patterns)
                        {
                            var match = Regex.Match(response, pattern);
                            if (match.Success)
                            {
                                enrolledIdentifier = match.Groups[1].Value;
                                Console.WriteLine("[MVP] Found identifier: " + enrolledIdentifier);
                                break;
                            }
                        }
                        
                        if (string.IsNullOrEmpty(enrolledIdentifier))
                        {
                            Console.WriteLine("[MVP] ⚠️  Could not extract identifier from response");
                            Console.WriteLine("[MVP] Will skip activation step");
                        }
                    }
                    else
                    {
                        Console.WriteLine("[MVP] ❌ Enrollment failed");
                        return false;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine("[MVP] ❌ Enrollment error: " + ex.Message);
            return false;
        }
        
        // If enrollment succeeded but no identifier, still consider it success
        if (enrollmentSuccess && string.IsNullOrEmpty(enrolledIdentifier))
        {
            Console.WriteLine("[MVP] ⚠️  Enrollment succeeded but cannot activate (no identifier)");
            return true;
        }
        
        // Step 2: Enable identity (separate connection)
        if (enrollmentSuccess && !string.IsNullOrEmpty(enrolledIdentifier))
        {
            try
            {
                // Wait a moment before reconnecting
                await Task.Delay(1000);
                
                using (var pipeClient = new NamedPipeClientStream(".", IPC_PIPE, PipeDirection.InOut))
                {
                    Console.WriteLine("[MVP] Reconnecting for activation...");
                    await pipeClient.ConnectAsync(5000);
                    Console.WriteLine("[MVP] ✅ Connected for activation");
                    
                    using (var writer = new StreamWriter(pipeClient) { AutoFlush = true })
                    using (var reader = new StreamReader(pipeClient))
                    {
                        Console.WriteLine("[MVP] Enabling identity: " + enrolledIdentifier);
                        string enableJson = SimpleJsonBuilder.BuildEnableJson(enrolledIdentifier);
                        
                        await writer.WriteLineAsync(enableJson);
                        
                        string enableResponse = await reader.ReadLineAsync();
                        Console.WriteLine("[MVP] Enable response: " + 
                            (enableResponse != null ? enableResponse.Substring(0, Math.Min(enableResponse.Length, 200)) : "null") + "...");
                        
                        if (enableResponse != null && (enableResponse.Contains("\"Code\":0") || enableResponse.Contains("\"Code\": 0")))
                        {
                            Console.WriteLine("[MVP] ✅ Identity enabled!");
                        }
                        else
                        {
                            Console.WriteLine("[MVP] ⚠️  Failed to enable identity");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("[MVP] ⚠️  Activation error: " + ex.Message);
                Console.WriteLine("[MVP] Identity was enrolled but may need manual activation");
            }
        }
        
        return enrollmentSuccess;
    }
}
'@

# Compile and load the type
try {
    Write-EnrollmentLog "Compiling C# code..."
    Add-Type -TypeDefinition $csharpCode -Language CSharp -ErrorAction Stop
    Write-EnrollmentLog "Code compiled successfully"
} catch {
    Write-EnrollmentLog "Failed to compile: $_" "ERROR"
    exit 1
}

# JWT Decoding and URI Test Function
function Test-ControllerConnectivity {
    param([string]$JwtContent)
    
    try {
        # Split JWT into parts
        $jwtParts = $JwtContent.Trim().Split('.')
        if ($jwtParts.Length -ne 3) {
            Write-Host "Invalid JWT format" -ForegroundColor Red
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
            Write-Host "No controller URL found in JWT" -ForegroundColor Red
            return $false
        }
        
        Write-Host "Controller URL: $controllerUrl" -ForegroundColor White
        
        # Test connectivity
        Write-Host "Testing connectivity..." -ForegroundColor Yellow
        try {
            # For PowerShell 5.1 compatibility - ignore certificate errors
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            
            $response = Invoke-RestMethod -Uri "$controllerUrl" -Method Get -TimeoutSec 10
            Write-Host "Controller responding: $($response.data.version)" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "Controller not responding: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        } finally {
            # Reset certificate validation
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
        
    } catch {
        Write-Host "JWT decode error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Read JWT content
Write-EnrollmentLog "Reading JWT file..."
$jwtContent = Get-Content $JwtFile -Raw -Encoding UTF8
$identityName = [System.IO.Path]::GetFileNameWithoutExtension($JwtFile)

# Test controller connectivity before enrollment
Write-EnrollmentLog "Testing controller connectivity..."
if (-not (Test-ControllerConnectivity -JwtContent $jwtContent)) {
    Write-EnrollmentLog "Cannot connect to controller - stopping enrollment" "ERROR"
    exit 1
}

Write-EnrollmentLog "Identity name: $identityName"
Write-EnrollmentLog "Use keychain: $UseKeychain"

# Execute enrollment
Write-EnrollmentLog "Executing enrollment..."
try {
    $result = [AutoEnrollMVP]::EnrollIdentity($jwtContent, $identityName, $UseKeychain).Result
    
    if ($result) {
        Write-EnrollmentLog "Enrollment completed!"
        
        # Wait for file to be created
        Start-Sleep -Seconds 2
        
        # Verify the identity file exists
        $SystemDir = "C:\Windows\System32\config\systemprofile\AppData\Roaming\NetFoundry"
        $expectedFile = "$SystemDir\$identityName.json"
        
        Write-EnrollmentLog "Verifying installation..."
        if (Test-Path $expectedFile) {
            Write-EnrollmentLog "Identity file found: $expectedFile"
            
            # Try to read and display basic info
            try {
                $identity = Get-Content $expectedFile -Raw | ConvertFrom-Json
                Write-Host "   Controller: $($identity.ztAPI)" -ForegroundColor Gray
                Write-Host "   Key type: $(if ($identity.id.key -match '^keychain:') { 'Keychain' } else { 'File-based' })" -ForegroundColor Gray
                
                # Additional verification
                if ($identity.id.cert) {
                    Write-Host "   Certificate: Present" -ForegroundColor Gray
                } else {
                    Write-Host "   Certificate: Missing" -ForegroundColor Red
                }
                
            } catch {
                Write-Host "   (Could not parse identity file)" -ForegroundColor Gray
            }
        } else {
            Write-Host "Identity file not found at expected location" -ForegroundColor Yellow
            Write-Host "   Checking alternative locations..." -ForegroundColor Gray
            
            # Check current directory
            if (Test-Path ".\$identityName.json") {
                Write-Host "   Found in current directory - manual installation required" -ForegroundColor Yellow
            }
        }
        
        # Additional verification steps
        Write-Host "`nChecking service status..." -ForegroundColor Yellow
        try {
            $service = Get-Service -Name "ziti" -ErrorAction SilentlyContinue
            if ($service) {
                Write-Host "   Ziti Service: $($service.Status)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "   Could not check service status" -ForegroundColor Gray
        }
        
        Write-Host "`nNext steps:" -ForegroundColor Cyan
        Write-Host "   1. Open Ziti Desktop Edge UI" -ForegroundColor White
        Write-Host "   2. Look for identity: $identityName" -ForegroundColor White
        Write-Host "   3. If not visible, restart the UI:" -ForegroundColor White
        Write-Host "      - Right-click system tray icon → Exit" -ForegroundColor Gray
        Write-Host "      - Start Ziti Desktop Edge again" -ForegroundColor Gray
        
    } else {
        Write-EnrollmentLog "Enrollment failed!" "ERROR"
        Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
        Write-Host "   1. Check if JWT has already been used" -ForegroundColor White
        Write-Host "   2. Verify ziti service is running:" -ForegroundColor White
        Write-Host "      Get-Service ziti" -ForegroundColor Gray
        Write-Host "   3. Try the fallback script:" -ForegroundColor White
        Write-Host "      .\ziti-enroll-file-only.ps1 -JwtFile `"$JwtFile`"" -ForegroundColor Gray
    }
} catch {
    Write-EnrollmentLog "Execution error: $_" "ERROR"
    Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Gray
}

Write-EnrollmentLog "MVP test complete."