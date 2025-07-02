# Software Design Specification (SDS) - Controller HA

## 1. 概述

### 1.1 目的
本文件描述 OpenZiti Controller 高可用性（HA）功能的軟體設計規格，使用 RAFT 共識協議實現 3 節點叢集，確保系統在控制器故障時能夠自動切換，保持服務連續性。

### 1.2 範圍
- 實作 3 節點 RAFT 叢集
- 共用 PKI 憑證架構
- Router 多控制器連線支援
- 自動故障切換機制

### 1.3 參考文件
- OpenZiti HA Overview: https://openziti.io/docs/reference/ha/overview
- OpenZiti HA Bootstrapping: https://openziti.io/docs/reference/ha/bootstrapping/overview

## 2. 系統架構

### 2.1 HA 架構
採用 RAFT 共識協議的分散式架構：
- 3 個控制器節點組成叢集（1 Leader + 2 Followers）
- 可容忍 1 個節點故障
- 自動領導者選舉和故障切換

### 2.2 元件關係
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

## 3. 設計細節

### 3.1 啟動配置

#### 3.1.1 第一個控制器（初始化叢集）

修改 `/var/lib/ziti-controller/config.yml`：

```yaml
# 信任域配置（SPIFFE 必需）
trustDomain: ziti.example.com

# 控制平面配置
ctrl:
  listener: tls:0.0.0.0:6262
  options:
    advertiseAddress: tls:controller1.example.com:6262

# RAFT 配置
raft:
  # 資料目錄
  dataDir: /var/lib/ziti-controller/raft
  
  # 最小叢集大小
  minClusterSize: 3
  
  # 啟動模式
  bootstrapMembers:
    - controller1.example.com:6262

# 命令通道（用於節點間通訊）
commandRateLimiter:
  enabled: true
  maxQueued: 100
```

初始化命令：
```bash
# 使用現有 PKI 初始化第一個節點
ziti agent controller init \
  --ctrl-address controller1.example.com:6262 \
  --ctrl-advertised-address controller1.example.com:6262
```

#### 3.1.2 加入其他控制器

第二、三個控制器配置：

```yaml
ctrl:
  listener: tls:0.0.0.0:6262
  options:
    advertiseAddress: tls:controller2.example.com:6262  # 或 controller3

raft:
  dataDir: /var/lib/ziti-controller/raft
```

加入叢集命令：
```bash
# 在 controller2 上執行
ziti agent controller join \
  controller1.example.com:6262 \
  --ctrl-address controller2.example.com:6262 \
  --ctrl-advertised-address controller2.example.com:6262

# 在 controller3 上執行  
ziti agent controller join \
  controller1.example.com:6262 \
  --ctrl-address controller3.example.com:6262 \
  --ctrl-advertised-address controller3.example.com:6262
```

### 3.2 PKI 憑證配置

#### 3.2.1 SPIFFE ID 要求
Controller HA **必須**使用 SPIFFE ID。所有控制器憑證都需要包含 SPIFFE ID。

SPIFFE ID 格式：
```
spiffe://<trust domain>/controller/<controller id>
```

#### 3.2.2 憑證架構
```bash
# 所有節點共用相同的 CA 和中間憑證
/var/lib/ziti-controller/pki/
├── ca/                    # 根 CA（所有節點相同）
├── intermediate/          # 中間 CA（所有節點相同）
└── controller/           # 控制器憑證（每個節點不同，含 SPIFFE ID）
    ├── server.cert       # 伺服器憑證
    └── server.key        # 伺服器私鑰
```

#### 3.2.3 憑證生成
設定信任域並生成憑證（在第一個節點）：

```bash
# 設定信任域
export TRUST_DOMAIN="ziti.example.com"

# 為 controller1 生成憑證（含 SPIFFE ID）
ziti pki create server \
  --pki-root /var/lib/ziti-controller/pki \
  --ca-name intermediate \
  --server-file controller1 \
  --dns "controller1.example.com" \
  --ip "192.168.1.11" \
  --spiffe-id "spiffe://${TRUST_DOMAIN}/controller/controller1"

# 為 controller2 生成憑證
ziti pki create server \
  --pki-root /var/lib/ziti-controller/pki \
  --ca-name intermediate \
  --server-file controller2 \
  --dns "controller2.example.com" \
  --ip "192.168.1.12" \
  --spiffe-id "spiffe://${TRUST_DOMAIN}/controller/controller2"

# 為 controller3 生成憑證
ziti pki create server \
  --pki-root /var/lib/ziti-controller/pki \
  --ca-name intermediate \
  --server-file controller3 \
  --dns "controller3.example.com" \
  --ip "192.168.1.13" \
  --spiffe-id "spiffe://${TRUST_DOMAIN}/controller/controller3"
```

#### 3.2.4 對 Router 和 Identity 的影響
- **Router**：不需要 SPIFFE ID，使用標準憑證即可
- **Identity**：不受影響，維持原有認證方式
- **控制器間通訊**：使用 SPIFFE ID 進行 mTLS 認證

### 3.3 Router 連線配置

Router 需要連接所有控制器，修改 Router 配置：

```yaml
# /var/lib/ziti-router/config.yml
ctrl:
  endpoints:
    - tls:controller1.example.com:8440
    - tls:controller2.example.com:8440
    - tls:controller3.example.com:8440
```

### 3.4 Web 管理介面配置

每個控制器的 Web 配置：

```yaml
web:
  - name: all-apis-localhost
    bindPoints:
      - interface: 0.0.0.0:8441
        address: controller1.example.com:8441  # 根據節點調整
    apis:
      - binding: fabric
      - binding: edge-management
        options:
          corsAllowedOrigins:
            - https://controller1.example.com:8441
            - https://controller2.example.com:8441
            - https://controller3.example.com:8441
      - binding: edge-client
```

### 3.5 故障切換機制

RAFT 自動處理故障切換：
1. 心跳檢測節點狀態（預設 150-300ms）
2. 超時觸發選舉（預設 1-2 秒）
3. 新 Leader 自動接管服務
4. Router 自動重新連線

## 4. 部署步驟

### 4.1 準備工作
1. 準備 3 台伺服器
2. 確保時間同步（NTP）
3. 配置防火牆規則：
   - 6262/tcp：RAFT 通訊
   - 8440/tcp：控制平面
   - 8441/tcp：管理 API

### 4.2 部署流程
1. 在第一個節點安裝並初始化
2. 複製 PKI 憑證到其他節點
3. 在其他節點安裝並加入叢集
4. 驗證叢集狀態
5. 更新 Router 配置
6. 測試故障切換

### 4.3 驗證命令
```bash
# 檢查叢集狀態
ziti fabric list controllers

# 檢查 RAFT 狀態
ziti agent cluster members

# 檢查領導者
ziti agent cluster leader
```

## 5. 監控與維護

### 5.1 健康檢查
- 監控端點：`https://[controller]:8441/health`
- RAFT 指標：`/metrics` 端點
- 日誌位置：`/var/log/ziti/controller.log`

### 5.2 維護操作
- 節點維護：先轉移領導者
- 憑證更新：滾動更新各節點
- 配置變更：通過 API 或重啟服務

## 6. 限制與注意事項

### 6.1 限制
- 最少需要 3 個節點維持 HA
- 跨地域部署需考慮延遲（建議 < 10ms）
- Circuit 綁定特定控制器，故障時需重建

### 6.2 注意事項
- Beta 功能，持續改進中
- 首次部署建議在測試環境驗證
- 定期備份 RAFT 資料目錄

## 7. 安全考量

- 節點間通訊使用 mTLS
- 共用 CA 需要安全保管
- 定期輪換憑證
- 限制 RAFT 端口存取

## 8. 效能影響

- 寫入操作需要多數節點確認
- 讀取操作不需協調，效能不受影響
- 網路延遲直接影響共識效能

## 9. 結論

此設計實現了 OpenZiti Controller 的完整 HA 功能，使用官方推薦的 RAFT 共識協議，提供自動故障切換能力，確保服務高可用性。配置變更集中在 config.yml 和啟動命令，符合最小改動原則。