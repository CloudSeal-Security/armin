# OpenZiti Controller HA 實作

基於 SDS 文件實作的 OpenZiti Controller 高可用性解決方案。

## 📁 目錄結構

```
controller-ha/
├── scripts/                    # 自動化腳本
│   ├── generate-certificates.sh   # PKI 憑證生成（含 SPIFFE ID）
│   ├── generate-config.sh         # 配置檔案生成
│   ├── init-cluster.sh           # 叢集初始化
│   ├── join-cluster.sh           # 節點加入叢集
│   ├── update-router-config.sh   # Router 多控制器配置
│   ├── health-check.sh           # 健康檢查
│   └── monitor-cluster.sh        # 持續監控
├── templates/                  # 配置模板
│   ├── controller-config.yml.template  # 控制器配置模板
│   └── router-config.yml.template      # Router 配置模板
├── configs/                    # 生成的配置檔案（執行時建立）
├── docs/                      # 文檔
│   └── deployment-guide.md    # 部署指南
└── README.md                  # 本檔案
```

## 🚀 快速開始

### 1. 生成憑證

```bash
cd scripts
export TRUST_DOMAIN="ziti.example.com"
sudo ./generate-certificates.sh
```

### 2. 生成配置

```bash
export TRUST_DOMAIN="ziti.example.com"
./generate-config.sh
```

### 3. 初始化叢集

```bash
export CONTROLLER_ID="controller1"
export CONTROLLER_FQDN="controller1.example.com"
sudo ./init-cluster.sh
```

### 4. 加入其他節點

在第二、三個節點上：

```bash
export CONTROLLER_ID="controller2"  # 或 controller3
export CONTROLLER_FQDN="controller2.example.com"  # 相應調整
export PRIMARY_CONTROLLER="controller1.example.com"
sudo ./join-cluster.sh
```

### 5. 驗證叢集

```bash
./health-check.sh
```

## 📋 核心特性

### ✅ RAFT 共識協議
- 3 節點叢集，容忍 1 個節點故障
- 自動領導者選舉和故障切換
- 分散式資料一致性

### ✅ SPIFFE ID 支援
- 控制器憑證包含 SPIFFE ID
- 符合 OpenZiti HA 要求
- 自動憑證驗證

### ✅ 多控制器 Router 支援
- Router 連接所有控制器
- 自動故障切換
- 負載分散

### ✅ 健康檢查與監控
- 即時叢集狀態檢查
- 多種輸出格式（table, json, simple）
- Nagios 整合支援
- 持續監控與警報

### ✅ 自動化部署
- 一鍵憑證生成
- 配置檔案模板化
- 腳本化部署流程

## 🔧 配置說明

### 環境變數

| 變數 | 說明 | 預設值 |
|------|------|--------|
| `TRUST_DOMAIN` | SPIFFE 信任域 | `ziti.example.com` |
| `CONTROLLER_ID` | 控制器識別碼 | `controller1` |
| `CONTROLLER_FQDN` | 控制器 FQDN | `controller1.example.com` |
| `PKI_ROOT` | PKI 根目錄 | `/var/lib/ziti-controller/pki` |

### 控制器節點配置

預設配置三個控制器節點：
- `controller1.example.com` (192.168.1.11)
- `controller2.example.com` (192.168.1.12)
- `controller3.example.com` (192.168.1.13)

### 網路埠號

- `6262/tcp`: RAFT 通訊
- `8440/tcp`: 控制平面
- `8441/tcp`: 管理 API
- `10000/tcp`: 管理介面

## 📚 詳細文檔

完整的部署指南請參考：[deployment-guide.md](docs/deployment-guide.md)

## 🔍 故障排除

### 檢查叢集狀態

```bash
# 叢集成員
ziti agent cluster members

# 領導者
ziti agent cluster leader

# 控制器列表
ziti fabric list controllers
```

### 常見問題

1. **SPIFFE ID 錯誤**
   - 檢查憑證中的 SPIFFE ID 格式
   - 確認 `TRUST_DOMAIN` 設定正確

2. **網路連通性**
   - 檢查防火牆設定
   - 確認 DNS 解析正確

3. **時間同步**
   - 確保所有節點時間同步
   - 使用 NTP 服務

## 📊 監控

### 健康檢查

```bash
# 表格格式
./health-check.sh

# JSON 格式
./health-check.sh --format json

# Nagios 模式
./health-check.sh --nagios
```

### 持續監控

```bash
# 啟動監控
./monitor-cluster.sh start

# 檢查狀態
./monitor-cluster.sh status

# 停止監控
./monitor-cluster.sh stop
```

## 🔒 安全考量

- 所有控制器間通訊使用 mTLS
- SPIFFE ID 用於身份驗證
- 定期憑證輪換
- 網路存取控制

## 📝 版本資訊

- **OpenZiti**: 1.5.4+
- **Console**: 3.12.4
- **架構**: 3 節點 RAFT 叢集
- **支援平台**: Ubuntu 20.04+, CentOS 8+

## 🤝 貢獻

歡迎提交 Issues 和 Pull Requests 來改善此實作。

## 📄 授權

遵循 OpenZiti 專案的授權條款。