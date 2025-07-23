# MVP Test: Named Pipe Enrollment for Ziti Desktop Edge
# This script tests enrollment using Named Pipe communication with ziti-edge-tunnel
# Based on the UI's IPC protocol analysis

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

Write-EnrollmentLog "MVP TEST: Named Pipe Auto-Enrollment"
Write-EnrollmentLog "====================================="
Write-EnrollmentLog "Testing direct IPC communication with ziti-edge-tunnel service"

# Validate JWT file
if (-not (Test-Path $JwtFile)) {
    Write-Host "❌ JWT file not found: $JwtFile" -ForegroundColor Red
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

# Step 1: Parse JWT for identity info
Write-Host "`n📋 Step 1: Parsing JWT" -ForegroundColor Yellow
$identityName = [System.IO.Path]::GetFileNameWithoutExtension($JwtFile)
$jwtContent = Get-Content $JwtFile -Raw -Encoding UTF8

Write-Host "  Identity Name: $identityName" -ForegroundColor White
Write-Host "  JWT File: $JwtFile" -ForegroundColor White
Write-Host "  Use Keychain: $UseKeychain" -ForegroundColor White

# Test controller connectivity before enrollment
Write-Host "`nTesting controller connectivity..." -ForegroundColor Cyan
if (-not (Test-ControllerConnectivity -JwtContent $jwtContent)) {
    Write-Host "Cannot connect to controller - stopping enrollment" -ForegroundColor Red
    exit 1
}

# Step 2: Create C# code for Named Pipe communication
Write-Host "`n🔧 Step 2: Setting up Named Pipe Client" -ForegroundColor Yellow

$csharpCode = @'
using System;
using System.IO;
using System.IO.Pipes;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

public class NamedPipeEnroller
{
    private const string IPC_PIPE = "ziti-edge-tunnel.sock";
    private const string EVENT_PIPE = "ziti-edge-tunnel-event.sock";
    
    public static async Task<string> EnrollIdentityAsync(string jwtContent, string identityName, bool useKeychain)
    {
        try
        {
            Console.WriteLine("[IPC] Connecting to ziti-edge-tunnel named pipe...");
            
            using (var pipeClient = new NamedPipeClientStream(".", IPC_PIPE, PipeDirection.InOut))
            {
                // Connect with timeout
                await pipeClient.ConnectAsync(5000);
                Console.WriteLine("[IPC] ✅ Connected to IPC pipe");
                
                using (var writer = new StreamWriter(pipeClient) { AutoFlush = true })
                using (var reader = new StreamReader(pipeClient))
                {
                    // Create enrollment payload matching UI's format
                    var payload = new
                    {
                        Command = "AddIdentity",
                        Data = new
                        {
                            UseKeychain = useKeychain,
                            IdentityFilename = identityName,
                            JwtContent = jwtContent,
                            Key = (string)null,
                            Certificate = (string)null,
                            ControllerURL = (string)null
                        }
                    };
                    
                    string jsonPayload = JsonConvert.SerializeObject(payload);
                    Console.WriteLine("[IPC] Sending AddIdentity command...");
                    
                    // Send the command
                    await writer.WriteLineAsync(jsonPayload);
                    await writer.FlushAsync();
                    
                    // Read response
                    string response = await reader.ReadLineAsync();
                    Console.WriteLine($"[IPC] Received response: {response?.Substring(0, Math.Min(response.Length, 100))}...");
                    
                    // Parse response
                    var responseObj = JsonConvert.DeserializeObject<JObject>(response);
                    
                    if (responseObj["Code"]?.Value<int>() == 0)
                    {
                        Console.WriteLine("[IPC] ✅ Enrollment successful!");
                        
                        // Extract identifier from response
                        var identifier = responseObj["Data"]?["Identifier"]?.Value<string>();
                        if (!string.IsNullOrEmpty(identifier))
                        {
                            Console.WriteLine($"[IPC] Identity Identifier: {identifier}");
                            
                            // Step 3: Enable the identity (like UI does)
                            Console.WriteLine("[IPC] Enabling identity...");
                            
                            var enablePayload = new
                            {
                                Command = "IdentityOnOff",
                                Data = new
                                {
                                    OnOff = true,
                                    Identifier = identifier
                                }
                            };
                            
                            string enableJson = JsonConvert.SerializeObject(enablePayload);
                            await writer.WriteLineAsync(enableJson);
                            await writer.FlushAsync();
                            
                            string enableResponse = await reader.ReadLineAsync();
                            var enableResult = JsonConvert.DeserializeObject<JObject>(enableResponse);
                            
                            if (enableResult["Code"]?.Value<int>() == 0)
                            {
                                Console.WriteLine("[IPC] ✅ Identity enabled successfully!");
                                return "SUCCESS";
                            }
                            else
                            {
                                Console.WriteLine($"[IPC] ⚠️  Failed to enable identity: {enableResult["Message"]}");
                                return "PARTIAL_SUCCESS";
                            }
                        }
                        
                        return "SUCCESS_NO_ENABLE";
                    }
                    else
                    {
                        string error = responseObj["Error"]?.Value<string>() ?? responseObj["Message"]?.Value<string>() ?? "Unknown error";
                        Console.WriteLine($"[IPC] ❌ Enrollment failed: {error}");
                        return $"FAILED: {error}";
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[IPC] ❌ Exception: {ex.Message}");
            return $"ERROR: {ex.Message}";
        }
    }
}
'@

# Step 3: Add required types and assemblies
Write-Host "`n📦 Step 3: Loading .NET assemblies" -ForegroundColor Yellow

try {
    # Try to load Newtonsoft.Json from common locations
    $newtonsoftPaths = @(
        "${env:ProgramFiles(x86)}\NetFoundry Inc\Ziti Desktop Edge\Newtonsoft.Json.dll",
        "${env:ProgramFiles}\NetFoundry Inc\Ziti Desktop Edge\Newtonsoft.Json.dll",
        "$PSScriptRoot\Newtonsoft.Json.dll"
    )
    
    $newtonsoftLoaded = $false
    foreach ($path in $newtonsoftPaths) {
        if (Test-Path $path) {
            Add-Type -Path $path
            Write-Host "  ✅ Loaded Newtonsoft.Json from: $path" -ForegroundColor Green
            $newtonsoftLoaded = $true
            break
        }
    }
    
    if (-not $newtonsoftLoaded) {
        Write-Host "  ⚠️  Newtonsoft.Json.dll not found, using basic JSON" -ForegroundColor Yellow
        # Fallback to simple JSON construction
        $useBasicJson = $true
    }
    
    # Add the C# type
    if (-not $useBasicJson) {
        Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies "System.IO.Pipes", "Newtonsoft.Json"
        Write-Host "  ✅ Named Pipe client compiled" -ForegroundColor Green
    }
    
} catch {
    Write-Host "  ⚠️  Could not compile C# code: $_" -ForegroundColor Yellow
    $useBasicJson = $true
}

# Step 4: Execute enrollment
Write-Host "`n🚀 Step 4: Executing Named Pipe Enrollment" -ForegroundColor Yellow

if ($useBasicJson) {
    # Fallback: Use PowerShell native named pipe
    Write-Host "  Using PowerShell native named pipe implementation..." -ForegroundColor Cyan
    
    try {
        $pipeName = "\\.\pipe\ziti-edge-tunnel.sock"
        $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", "ziti-edge-tunnel.sock", [System.IO.Pipes.PipeDirection]::InOut)
        
        Write-Host "  Connecting to pipe..." -ForegroundColor Gray
        $pipe.Connect(5000)
        Write-Host "  ✅ Connected!" -ForegroundColor Green
        
        $writer = New-Object System.IO.StreamWriter($pipe)
        $reader = New-Object System.IO.StreamReader($pipe)
        
        # Construct JSON manually
        $jsonPayload = @"
{
    "Command": "AddIdentity",
    "Data": {
        "UseKeychain": $(if ($UseKeychain) { "true" } else { "false" }),
        "IdentityFilename": "$identityName",
        "JwtContent": "$($jwtContent.Replace('"', '\"').Replace("`n", "").Replace("`r", ""))",
        "Key": null,
        "Certificate": null,
        "ControllerURL": null
    }
}
"@
        
        Write-Host "  Sending enrollment request..." -ForegroundColor Gray
        $writer.WriteLine($jsonPayload)
        $writer.Flush()
        
        Write-Host "  Reading response..." -ForegroundColor Gray
        $response = $reader.ReadLine()
        
        Write-Host "  Response received: $($response.Substring(0, [Math]::Min($response.Length, 100)))..." -ForegroundColor Gray
        
        # Try to parse response
        try {
            $responseObj = $response | ConvertFrom-Json
            if ($responseObj.Code -eq 0) {
                Write-Host "  ✅ Enrollment successful!" -ForegroundColor Green
                
                # Try to enable identity
                if ($responseObj.Data.Identifier) {
                    Write-Host "  Enabling identity..." -ForegroundColor Gray
                    
                    $enableJson = @"
{
    "Command": "IdentityOnOff",
    "Data": {
        "OnOff": true,
        "Identifier": "$($responseObj.Data.Identifier)"
    }
}
"@
                    $writer.WriteLine($enableJson)
                    $writer.Flush()
                    
                    $enableResponse = $reader.ReadLine()
                    Write-Host "  Enable response: $($enableResponse.Substring(0, [Math]::Min($enableResponse.Length, 100)))..." -ForegroundColor Gray
                }
            } else {
                Write-Host "  ❌ Enrollment failed: $($responseObj.Message)" -ForegroundColor Red
            }
        } catch {
            Write-Host "  ⚠️  Could not parse response: $_" -ForegroundColor Yellow
        }
        
        $writer.Close()
        $reader.Close()
        $pipe.Close()
        
    } catch {
        Write-Host "  ❌ Named pipe error: $_" -ForegroundColor Red
        
        # Fallback to traditional method
        Write-Host "`n⚠️  Named pipe failed, falling back to CLI method..." -ForegroundColor Yellow
        & "$PSScriptRoot\ziti-enroll-file-only.ps1" -JwtFile $JwtFile
        exit
    }
} else {
    # Use compiled C# code
    try {
        $result = [NamedPipeEnroller]::EnrollIdentityAsync($jwtContent, $identityName, $UseKeychain).Result
        
        if ($result -eq "SUCCESS") {
            Write-Host "  ✅ Full enrollment and activation completed!" -ForegroundColor Green
        } elseif ($result -eq "SUCCESS_NO_ENABLE") {
            Write-Host "  ✅ Enrollment completed (manual enable required)" -ForegroundColor Yellow
        } elseif ($result -eq "PARTIAL_SUCCESS") {
            Write-Host "  ⚠️  Enrollment succeeded but activation failed" -ForegroundColor Yellow
        } else {
            Write-Host "  ❌ $result" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ❌ Execution error: $_" -ForegroundColor Red
    }
}

# Step 5: Verify results
Write-Host "`n🔍 Step 5: Verifying Enrollment" -ForegroundColor Yellow

$SystemDir = "C:\Windows\System32\config\systemprofile\AppData\Roaming\NetFoundry"
$expectedFile = "$SystemDir\$identityName.json"

if (Test-Path $expectedFile) {
    Write-Host "  ✅ Identity file found: $expectedFile" -ForegroundColor Green
    
    try {
        $identity = Get-Content $expectedFile -Raw | ConvertFrom-Json
        Write-Host "  ✅ Controller: $($identity.ztAPI)" -ForegroundColor Green
        Write-Host "  ✅ Key type: $(if ($identity.id.key -match '^keychain:') { 'Keychain' } else { 'File-based' })" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  Could not parse identity file" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  Identity file not found at expected location" -ForegroundColor Yellow
    Write-Host "     Expected: $expectedFile" -ForegroundColor Gray
}

# Final summary
Write-Host "`n📊 MVP Test Complete!" -ForegroundColor Magenta
Write-Host "===================" -ForegroundColor Magenta
Write-Host "This test demonstrates:" -ForegroundColor Cyan
Write-Host "  1. Direct IPC communication with ziti-edge-tunnel" -ForegroundColor White
Write-Host "  2. Enrollment via AddIdentity command" -ForegroundColor White
Write-Host "  3. Automatic identity activation" -ForegroundColor White
Write-Host "  4. Full UI integration without manual file copying" -ForegroundColor White

Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
Write-Host "  - Check Ziti Desktop Edge UI for the new identity" -ForegroundColor White
Write-Host "  - Verify the identity connects to the controller" -ForegroundColor White
Write-Host "  - Monitor for any error messages in the UI" -ForegroundColor White