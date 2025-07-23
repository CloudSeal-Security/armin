# Ziti Auto-Enrollment MVP - Quick Start Guide

> **Ready-to-Deploy Package** - Complete automated enrollment solution with controller connectivity testing and comprehensive logging

## ⚡ Fastest Start (30 seconds)

### Windows Users
```cmd
REM Double-click or run:
enroll.bat your-identity.jwt

REM For secure enterprise deployment:
enroll.bat your-identity.jwt -UseKeychain
```

### PowerShell Users
```powershell
# Basic enrollment
.\enroll.ps1 -JwtFile "your-identity.jwt"

# Secure enterprise enrollment
.\enroll.ps1 -JwtFile "your-identity.jwt" -UseKeychain

# Interactive mode (guided setup)
.\enroll.ps1 -Interactive

# Quick verification
.\enroll.ps1 -Verify -IdentityName "your-identity"
```

## 📁 What's in This Package

```
ziti-auto-enrollment-mvp/
├── enroll.ps1                        # [MAIN] PowerShell entry point (defaults to GPO mode)
├── README.md                         # This guide
├── QUICK-START.md                    # Quick reference
├── docs/                             # Complete documentation
├── core/                             # Main enrollment scripts
│   ├── enroll-gpo.ps1                   # [DEFAULT] GPO mode with connectivity testing
│   ├── enroll-identity.ps1               # Interactive mode
│   ├── enroll-direct.ps1                # Direct Named Pipe implementation
│   └── enroll-fallback.ps1               # Pure PowerShell fallback
├── logs/                             # Auto-generated log files
│   └── [timestamp]_[jwt-name].log        # Timestamped logs with JWT filename
├── verification/                     # Testing tools
├── support/                          # Diagnostic tools
├── ui/                               # User interfaces
└── advanced/                         # C# source & advanced tools
```

## 🎯 Common Use Cases

### 1. Individual User Enrollment
```powershell
.\enroll.ps1 -JwtFile "my-identity.jwt"
```

### 2. Enterprise Secure Enrollment
```powershell
.\enroll.ps1 -JwtFile "corporate-identity.jwt" -UseKeychain
```

### 3. Batch Processing Multiple Identities
```powershell
Get-ChildItem *.jwt | ForEach-Object {
    .\enroll.ps1 -JwtFile $_.Name -UseKeychain
}
```

### 4. Interactive Guided Setup
```powershell
.\enroll.ps1 -Interactive
```

### 5. Verification & Troubleshooting
```powershell
# Quick check
.\enroll.ps1 -Verify -IdentityName "my-identity"

# Full diagnostics
.\support\diagnose-issues.ps1

# Auto-fix common issues
.\support\fix-issues.ps1
```

## 🏢 Enterprise Deployment

### GPO Deployment (Recommended)
```batch
REM Recommended: Use main entry point (defaults to GPO mode with full logging)
powershell -ExecutionPolicy Bypass -File "\\server\share\ziti-enrollment\enroll.ps1" -JwtFile "\\server\share\identities\%COMPUTERNAME%.jwt" -UseKeychain

REM Direct: Use GPO-specific script
powershell -ExecutionPolicy Bypass -File "\\server\share\ziti-enrollment\core\enroll-gpo.ps1" -JwtFile "\\server\share\identities\%COMPUTERNAME%.jwt" -UseKeychain
```

**新特性**：
- **自動連線測試**: JWT 解析後自動測試控制器連線
- **完整日誌記錄**: 自動產生 `[timestamp]_[jwt-filename].log`
- **多層連線測試**: PowerShell HTTP → WebClient → TCP 連線測試
- **無表情符號**: 移除所有不必要的 emoji，提高相容性

### SCCM Application Deployment
- **Install Command**: `powershell -ExecutionPolicy Bypass -File "enroll.ps1" -JwtFile "identity.jwt" -UseKeychain`
- **Detection Method**: Check for identity file in system profile
- **Success Codes**: 0
- **Restart Behavior**: No restart required

### Manual Distribution
1. Copy entire `ziti-auto-enrollment-mvp` folder to target machines
2. Place JWT files in the same directory
3. Run `enroll.bat` or use PowerShell commands above

## 🔧 Troubleshooting

### Identity Not Appearing in UI
```powershell
.\support\restart-ui.ps1
```

### Connection Issues
```powershell
.\support\diagnose-issues.ps1
```

### Enrollment Failures
```powershell
# Check logs first (auto-generated with timestamp and JWT name)
Get-Content logs\*.log | Select-Object -Last 20

# Try alternative methods:
.\core\enroll-direct.ps1 -JwtFile "identity.jwt"
.\core\enroll-fallback.ps1 -JwtFile "identity.jwt"
```

### Verification Failed
```powershell
# Comprehensive testing:
.\verification\test-comprehensive.ps1 -JwtFile "identity.jwt" -ShowDetails
```

## 📖 Need More Help?

- **Complete Documentation**: `docs\README.md`
- **Enterprise Deployment**: `docs\DEPLOYMENT-GUIDE.md` (中文)
- **Technical Details**: `docs\TECHNICAL-CONVERSION-GUIDE.md`
- **C# Compilation**: `docs\BUILD-STANDALONE.md`

## ✅ Success Indicators

After enrollment, you should see:
- ✅ Identity file created in system directory
- ✅ Identity appears in Ziti Desktop Edge UI
- ✅ Controller connection established
- ✅ Services become available

## 🔐 Security Features

- **File Storage**: Traditional file-based private keys (default)
- **Keychain Storage**: Windows Certificate Store integration (enterprise)
- **TPM Support**: Hardware security module compatibility
- **Code Signing**: All executables are signed and validated

---

**🎉 Ready to Deploy!** This package is production-ready and includes everything needed for enterprise Ziti identity deployment.