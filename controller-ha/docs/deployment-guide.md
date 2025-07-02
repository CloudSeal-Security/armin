# OpenZiti Controller HA 部署指南

## 概述

本文件提供 OpenZiti Controller HA 的完整部署指南，包括環境準備、憑證生成、叢集初始化和驗證步驟。

## 部署架構

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Controller 1 │◄───► Controller 2 │◄───► Controller 3 │
│   (Leader)   │    │  (Follower)  │    │  (Follower)  │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                    │
       └───────────────────┴────────────────────┘
                           │
                    ┌──────▼──────┐
                    │   Routers   │
                    └─────────────┘
```

## 先決條件

### 硬體要求
- **控制器節點**: 3 台伺服器
  - CPU: 2+ 核心
  - RAM: 4GB+
  - 磁碟: 20GB+ SSD
  - 網路: 1Gbps+

### 軟體要求
- Ubuntu 20.04+ 或 CentOS 8+
- OpenZiti 1.5.4+
- NTP 時間同步
- 防火牆配置

### 網路要求
```
埠號配置:
- 6262/tcp: RAFT 通訊
- 8440/tcp: 控制平面
- 8441/tcp: 管理 API
- 10000/tcp: 管理介面
```

## 部署步驟

### 步驟 1: 環境準備

在所有三個節點上執行：

```bash
# 更新系統
sudo apt update && sudo apt upgrade -y

# 安裝必要套件
sudo apt install -y curl wget gnupg2 software-properties-common ntp

# 設定時間同步
sudo systemctl enable --now ntp

# 設定主機名稱
sudo hostnamectl set-hostname controller1  # 根據節點調整
```

### 步驟 2: 安裝 OpenZiti

在所有節點上安裝：

```bash
# 使用現有的 zgate_offline 套件
cd /path/to/zgate_offline
sudo ./install.sh
# 選擇 "Commander" 選項
```

### 步驟 3: 生成 PKI 憑證

在第一個節點上執行：

```bash
# 設定環境變數
export TRUST_DOMAIN="ziti.example.com"
export PKI_ROOT="/var/lib/ziti-controller/pki"

# 執行憑證生成腳本
cd controller-ha/scripts
sudo ./generate-certificates.sh
```

憑證將生成在 `/var/lib/ziti-controller/pki/` 目錄下。

### 步驟 4: 分發憑證

將 PKI 憑證複製到其他節點：

```bash
# 在第一個節點上執行
for node in controller2.example.com controller3.example.com; do
    rsync -avz /var/lib/ziti-controller/pki/ $node:/var/lib/ziti-controller/pki/
done
```

### 步驟 5: 生成配置檔案

```bash
# 設定環境變數
export TRUST_DOMAIN="ziti.example.com"

# 生成所有節點的配置
./generate-config.sh
```

配置檔案將生成在 `configs/` 目錄下。

### 步驟 6: 部署配置檔案

將配置檔案複製到對應節點：

```bash
# Controller 1
sudo cp configs/controller1-bootstrap-config.yml /var/lib/ziti-controller/config.yml

# Controller 2
scp configs/controller2-config.yml controller2.example.com:/tmp/
ssh controller2.example.com "sudo mv /tmp/controller2-config.yml /var/lib/ziti-controller/config.yml"

# Controller 3
scp configs/controller3-config.yml controller3.example.com:/tmp/
ssh controller3.example.com "sudo mv /tmp/controller3-config.yml /var/lib/ziti-controller/config.yml"
```

### 步驟 7: 初始化叢集

在第一個節點上執行：

```bash
# 設定環境變數
export CONTROLLER_ID="controller1"
export CONTROLLER_FQDN="controller1.example.com"
export TRUST_DOMAIN="ziti.example.com"

# 初始化叢集
sudo ./init-cluster.sh
```

### 步驟 8: 加入其他節點

在第二個節點上：

```bash
# 設定環境變數
export CONTROLLER_ID="controller2"
export CONTROLLER_FQDN="controller2.example.com"
export PRIMARY_CONTROLLER="controller1.example.com"

# 加入叢集
sudo ./join-cluster.sh
```

在第三個節點上：

```bash
# 設定環境變數
export CONTROLLER_ID="controller3"
export CONTROLLER_FQDN="controller3.example.com"
export PRIMARY_CONTROLLER="controller1.example.com"

# 加入叢集
sudo ./join-cluster.sh
```

### 步驟 9: 驗證叢集

```bash
# 檢查叢集狀態
ziti agent cluster members

# 檢查控制器列表
ziti fabric list controllers

# 檢查領導者
ziti agent cluster leader

# 檢查服務狀態
sudo systemctl status ziti-controller
```

### 步驟 10: 更新 Router 配置

在所有 Router 節點上執行：

```bash
# 設定環境變數
export ROUTER_ID="edge-router-1"
export ROUTER_FQDN="router1.example.com"

# 更新 Router 配置
sudo ./update-router-config.sh
```

## 驗證與測試

### 基本功能測試

```bash
# 測試 API 連線
curl -k https://controller1.example.com:8441/health
curl -k https://controller2.example.com:8441/health
curl -k https://controller3.example.com:8441/health

# 測試管理介面
curl -k https://controller1.example.com:8441/edge/management/v1/version
```

### 故障切換測試

```bash
# 停止主控制器
sudo systemctl stop ziti-controller

# 檢查自動故障切換
ziti agent cluster leader

# 檢查服務可用性
curl -k https://controller2.example.com:8441/health
```

### 健康檢查

```bash
# 執行健康檢查
./health-check.sh

# JSON 格式輸出
./health-check.sh --format json

# Nagios 模式
./health-check.sh --nagios
```

## 監控設定

### 啟動持續監控

```bash
# 啟動監控程序
./monitor-cluster.sh start

# 檢查監控狀態
./monitor-cluster.sh status

# 停止監控
./monitor-cluster.sh stop
```

### 設定警報

```bash
# Webhook 警報
export ALERT_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# 電子郵件警報
export ALERT_EMAIL="admin@example.com"

# 重啟監控以套用設定
./monitor-cluster.sh restart
```

## 維護操作

### 憑證更新

```bash
# 重新生成憑證
sudo ./generate-certificates.sh

# 重啟服務
sudo systemctl restart ziti-controller
```

### 新增節點

參考步驟 8，使用 `join-cluster.sh` 腳本。

### 移除節點

```bash
# 在要移除的節點上停止服務
sudo systemctl stop ziti-controller

# 在其他節點上檢查叢集狀態
ziti agent cluster members
```

### 備份與還原

```bash
# 備份 RAFT 資料
sudo tar -czf raft-backup-$(date +%Y%m%d).tar.gz /var/lib/ziti-controller/raft/

# 備份憑證
sudo tar -czf pki-backup-$(date +%Y%m%d).tar.gz /var/lib/ziti-controller/pki/
```

## 故障排除

### 常見問題

1. **憑證問題**
   ```bash
   # 檢查憑證有效性
   openssl x509 -in /var/lib/ziti-controller/pki/intermediate/certs/controller1.chain.pem -noout -text
   
   # 驗證 SPIFFE ID
   openssl x509 -in /var/lib/ziti-controller/pki/intermediate/certs/controller1.chain.pem -noout -text | grep -i spiffe
   ```

2. **網路連通性**
   ```bash
   # 測試 RAFT 端口
   telnet controller2.example.com 6262
   
   # 測試 API 端口
   telnet controller2.example.com 8441
   ```

3. **時間同步**
   ```bash
   # 檢查時間差異
   ntpq -p
   
   # 強制同步
   sudo ntpdate -s time.nist.gov
   ```

### 日誌位置

- **控制器日誌**: `/var/log/ziti-controller/controller.log`
- **監控日誌**: `/var/log/ziti-controller/ha-monitor.log`
- **系統日誌**: `journalctl -u ziti-controller`

### 效能調優

```bash
# 調整 RAFT 參數
# 編輯 config.yml 中的 raft 區塊
raft:
  electionTimeout: 1000    # 降低以加快故障切換
  heartbeatTimeout: 500    # 降低以加快檢測
```

## 安全考量

- 定期輪換憑證
- 限制網路存取
- 啟用日誌監控
- 定期安全審計

## 支援

如有問題，請參考：
- OpenZiti 官方文件: https://openziti.io/docs
- 社群論壇: https://openziti.discourse.group
- GitHub Issues: https://github.com/openziti/ziti/issues