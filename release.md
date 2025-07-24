# Release Notes

### 1. **版本資訊**

- 產品名稱: Z-Gate Armin
- 版本號碼: v1.0.0
- 發佈日期: 2025-07-24
- 發佈類型: Initial Publish

---

### 2. **概覽**

- 初始與最終版本，且後續不會更新

---

### 3. 主要功能

- Armin Z-Gate Console 統一管理
- 透過 Services, Configuation, Policy 設定服務隱藏
- 透過syslog查看traffic log
- 透過Powershell腳本 Auto Enroll Identity
- Commander, Identity 憑證由 eCloudSeal 簽發

---

### 4. **已知問題（Known Issues）**

---

- 尚無 Commander HA
- UI 需 Reflash (F5) 才正常
- Router憑證置換會產生UI燈號未亮的bug，因此先拿掉
- Windows Agent 安裝包尚未完成
- IOS, macOS Agent 尚未完成
- 尚無 身分驗證功能
- 整合其他廠商非常困難

---

### 5. 部署**說明（Deployment）**

- 部署建議環境
    - OS: Ubuntu Server 22.04 LTS
    - CPU: 4 core
    - Memry: 8 GB
    - Storage: 60 GB
- 交付內容
    - zgate_offline.rar
        - add_syslog：啟用syslog相關腳本與說明
        - auto_enroll：identity auto enroll的powershell腳本與相關說明
        - console：原生ZAC安裝包(.deb)與AZGC patch
        - controller：zgate controller安裝包 (.deb)
        - pki_change：憑證置換腳本與相關設定檔
        - router：zgate router安裝包 (.deb)
        - zgate：zgate 相關elf檔
        - install.sh：安裝腳本
        - uninstall.sh：安裝腳本

---