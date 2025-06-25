# OpenZiti 管理控制台 (ZAC) 與離線部署包

中文版 | [English](./README.md)

本專案包含兩個主要元件，用於 OpenZiti 網路管理：
- **ziti-console**：基於網頁的管理控制台，用於管理 OpenZiti 網路
- **zgate_offline**：OpenZiti 基礎設施的離線部署包

## 🚀 快速開始

### 開發環境
```bash
# 安裝相依套件
npm install

# 啟動開發伺服器
npm start
# 存取位址：http://localhost:4200
```

### 離線安裝
```bash
cd zgate_offline
sudo ./install.sh
```

## 📋 目錄

- [功能特色](#功能特色)
- [架構說明](#架構說明)
- [安裝指南](#安裝指南)
- [開發指南](#開發指南)
- [建置說明](#建置說明)
- [部署方式](#部署方式)
- [API 文件](#api-文件)
- [疑難排解](#疑難排解)
- [貢獻指南](#貢獻指南)
- [授權資訊](#授權資訊)

## ✨ 功能特色

### Ziti 控制台 (ZAC)
- **全方位管理**：管理身分、服務、政策、路由器和設定
- **即時視覺化**：使用 D3.js 呈現網路拓撲和服務地圖
- **多重部署模式**：支援 SPA 和 Node.js 伺服器模式
- **OAuth2/OIDC 支援**：企業級身分驗證整合
- **響應式設計**：支援桌面和行動裝置
- **資料匯出**：將設定和報告匯出為 CSV 格式
- **進階篩選**：複雜的搜尋和篩選功能
- **批次操作**：對多個實體執行大量操作

### 離線部署包
- **完整 OpenZiti 堆疊**：控制器、路由器和控制台元件
- **版本資訊**：OpenZiti 1.5.4、控制台 3.12.4
- **自動化安裝**：中文安裝腳本
- **備份工具**：資料庫和 PKI 備份工具
- **自動註冊**：路由器自動註冊支援
- **控制台修補檔**：預先建置的客製化控制台 (console_patch.tar)

## 🏗 架構說明

### 控制台結構

```
ziti-console/
├── projects/
│   ├── ziti-console-lib/        # 可重用的 Angular 函式庫
│   │   └── src/lib/
│   │       ├── pages/           # 頁面元件
│   │       │   ├── identities/  # 身分管理
│   │       │   ├── services/    # 服務設定
│   │       │   ├── policies/    # 政策管理
│   │       │   └── routers/     # 路由器管理
│   │       ├── features/        # 可重用的 UI 元件
│   │       │   ├── data-table/  # 進階資料表格
│   │       │   ├── visualizer/  # 網路視覺化工具
│   │       │   └── widgets/     # 表單小工具
│   │       ├── services/        # API 服務
│   │       │   ├── ziti-controller-data.service.ts
│   │       │   └── settings.service.ts
│   │       └── assets/          # 靜態資源
│   └── app-ziti-console/        # 主應用程式
│       └── src/
│           ├── app/             # 應用程式元件
│           ├── environments/    # 環境設定
│           └── assets/          # 應用程式專屬資源
├── docker-images/               # Docker 設定
│   ├── zac/                     # 主控制台映像檔
│   └── ziti-console-assets/     # 純資源映像檔
└── zgate_offline/               # 離線部署
    ├── controller/              # 控制器 .deb 套件
    ├── router/                  # 路由器 .deb 套件
    ├── console/                 # 控制台 .deb 套件
    ├── backup/                  # 備份工具
    └── install.sh              # 安裝腳本
```

### 技術堆疊

- **前端框架**：Angular 16 搭配 TypeScript
- **UI 元件**：PrimeNG、Angular Material
- **資料視覺化**：D3.js、Chart.js、Leaflet
- **狀態管理**：RxJS
- **樣式設計**：SCSS、CSS Grid、Flexbox
- **後端**（Node 模式）：Express.js、Helmet.js
- **建置工具**：Angular CLI、ng-packagr、Webpack
- **測試工具**：Jasmine、Karma
- **CI/CD**：Bitbucket Pipelines、Docker

## 📦 安裝指南

### 系統需求

- **Node.js**：16.x 版本或更高
- **npm**：8.x 版本或更高
- **Angular CLI**：16.x 版本
- **Git**：用於複製儲存庫
- **Docker**（選用）：用於容器化部署

### 開發環境設定

```bash
# 複製儲存庫
git clone <repository-url>
cd armin

# 安裝相依套件（自動建置函式庫）
npm install

# 啟動開發伺服器
npm start

# 存取應用程式
# 預設：http://localhost:4200
# 自訂設定：http://localhost:4200?controllerAPI=https://your-controller:8441
```

### 環境設定

編輯環境設定檔：
```typescript
// src/environments/environment.ts
export const environment = {
  production: false,
  apiPath: '/edge/management/v1',
  // 在此新增您的自訂設定
};
```

### 離線安裝（Linux）

離線套件支援 Ubuntu/Debian 系統：

```bash
# 進入離線套件目錄
cd zgate_offline

# 設定執行權限
chmod +x install.sh uninstall.sh

# 執行安裝（需要 sudo 權限）
sudo ./install.sh

# 依照互動式提示進行：
# 1. 安裝 OpenZiti 控制器
# 2. 設定控制器參數
# 3. 安裝 OpenZiti 路由器
# 4. 設定路由器註冊
# 5. 安裝管理控制台
```

## 💻 開發指南

### 開發伺服器

```bash
# 使用預設設定啟動
npm start

# 啟動並監視函式庫變更
npm run start:watch

# 使用特定設定啟動
ng serve ziti-console --configuration development
```

### 程式碼產生器

```bash
# 產生新元件
ng generate component features/my-component --project=ziti-console-lib

# 產生新服務
ng generate service services/my-service --project=ziti-console-lib

# 產生新頁面
ng generate component pages/my-page --project=ziti-console-lib
```

### 監視模式

用於函式庫開發：
```bash
# 終端機 1：監視函式庫變更
npm run watch:lib

# 終端機 2：執行應用程式
npm start
```

### 程式碼風格

專案使用：
- **ESLint** 進行程式碼檢查
- **Prettier** 進行程式碼格式化
- **TypeScript** 嚴格模式（部分例外）

```bash
# 執行檢查
npm run lint

# 修正檢查問題
npm run lint:fix
```

### 測試

```bash
# 執行單元測試
npm test

# 執行測試並產生覆蓋率報告
npm run test:coverage

# 以監視模式執行測試
npm run test:watch

# 執行端對端測試（如有設定）
npm run e2e
```

## 🔨 建置說明

### 建置指令

```bash
# 建置所有內容（函式庫 + 兩種應用程式設定）
npm run build

# 僅建置函式庫
ng build ziti-console-lib

# 建置 SPA 版本（建議用於生產環境）
ng build ziti-console --configuration production

# 建置 Node.js 伺服器版本
ng build ziti-console-node

# 使用自訂基礎路徑建置
./build.sh /my/base/path

# 建置並包含原始碼對應
ng build ziti-console --source-map
```

### 建置輸出

- **函式庫**：`dist/ziti-console-lib/`
- **SPA 應用程式**：`dist/app-ziti-console/`
- **Node 應用程式**：`dist/app-ziti-console-node/`

### Docker 建置

```bash
# 建置 Docker 映像檔
npm run docker:build

# 使用自訂標籤建置
docker build -t my-registry/ziti-console:latest .

# 建置多平台映像檔
docker buildx build --platform linux/amd64,linux/arm64 -t ziti-console:latest .
```

## 🚀 部署方式

### 方式 1：靜態檔案（SPA - 建議）

適合 CDN 部署或靜態網頁託管：

```bash
# 建置生產版本
ng build ziti-console --configuration production

# 部署 dist/app-ziti-console/ 中的檔案
# nginx 範例：
cp -r dist/app-ziti-console/* /var/www/html/

# AWS S3 範例：
aws s3 sync dist/app-ziti-console/ s3://my-bucket/ --delete
```

### 方式 2：Node.js 伺服器

適用於需要伺服器端功能的環境：

```bash
# 建置 Node.js 版本
ng build ziti-console-node

# 安裝生產相依套件
cd dist/app-ziti-console-node
npm install --production

# 執行伺服器
node server.js

# 使用 PM2 執行
pm2 start server.js --name ziti-console

# 使用環境變數執行
ZAC_SERVER_PORT=8080 ZAC_NODE_MODULES_ROOT=./node_modules node server.js
```

### 方式 3：Docker 容器

```bash
# 使用 Docker 執行
docker run -d \
  --name ziti-console \
  -p 1408:1408 \
  -e ZAC_SERVER_PORT=1408 \
  -e ZITI_CTRL_ADVERTISED_HOST=controller.example.com \
  -e ZITI_CTRL_ADVERTISED_PORT=8441 \
  openziti/zac:latest

# 使用 Docker Compose 執行
docker-compose up -d
```

### 方式 4：Kubernetes

```yaml
# Kubernetes 部署範例
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ziti-console
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ziti-console
  template:
    metadata:
      labels:
        app: ziti-console
    spec:
      containers:
      - name: ziti-console
        image: openziti/zac:latest
        ports:
        - containerPort: 1408
        env:
        - name: ZAC_SERVER_PORT
          value: "1408"
```

### 方式 5：OpenZiti 控制器整合

作為 OpenZiti 控制器的一部分部署：

```bash
# 複製控制台檔案到控制器的靜態目錄
cp -r dist/app-ziti-console/* /opt/openziti/controller/static/

# 透過控制器 URL 存取
# https://controller.example.com:8441/zac/
```

## 📡 API 文件

### API 端點

控制台與 OpenZiti Edge API 通訊：

- **管理 API**：`/edge/management/v1/*`
  - 身分：`/identities`
  - 服務：`/services`
  - 政策：`/service-policies`、`/edge-router-policies`
  - 路由器：`/edge-routers`、`/transit-routers`

- **客戶端 API**：`/edge/client/v1/*`
  - 工作階段：`/sessions`
  - 服務：`/services`

### 身分驗證

控制台支援多種身分驗證方法：

1. **使用者名稱/密碼**：預設身分驗證
2. **憑證**：mTLS 身分驗證
3. **外部 JWT**：第三方 JWT 權杖
4. **OAuth2/OIDC**：企業 SSO 整合

### API 設定

```typescript
// 設定 API 端點
const settings = {
  protocol: 'https',
  host: 'controller.example.com',
  port: 8441,
  apiPath: '/edge/management/v1'
};
```

## 📦 建立 console_patch.tar

`console_patch.tar` 檔案包含用於離線部署的客製化 OpenZiti 管理控制台。以下是建立方法：

### 步驟 1：建置控制台

```bash
# 進入 ziti-console 目錄
cd ziti-console

# 安裝相依套件
npm install

# 建置生產版本
ng build ziti-console --configuration production
```

### 步驟 2：準備修補檔目錄

```bash
# 使用建置輸出建立修補檔目錄
mkdir -p console_patch
cp -r dist/app-ziti-console/* console_patch/

# 新增自訂資源（選用）
# 例如，替換為自訂品牌：
# cp your-logo.png console_patch/assets/Z-Gate_Logo.png
# cp your-license.json console_patch/assets/license_number.json
```

### 步驟 3：建立 Tar 壓縮檔

```bash
# 建立 tar 檔案
tar -cf console_patch.tar console_patch/

# 移至離線套件目錄
mv console_patch.tar zgate_offline/console/

# 清理
rm -rf console_patch
```

### 包含內容

console_patch.tar 包含：
- **建置的 Angular 應用程式**：最佳化的生產建置
- **自訂品牌**：標誌和主題客製化
- **授權設定**：部署專屬設定
- **所有相依項目**：打包的 JavaScript、CSS 和資源

### 安裝時的使用方式

離線安裝程式（`install.sh`）會：
1. 解壓縮 console_patch.tar
2. 移除位於 `/opt/openziti/share/console` 的預設控制台
3. 將客製化控制台複製到安裝目錄
4. 重新啟動 ziti-controller 服務

## 🔧 疑難排解

### 常見問題

#### 建置錯誤

```bash
# 清除快取並重新建置
rm -rf node_modules dist
npm install
npm run build

# 修正對等相依性問題
npm install --legacy-peer-deps
```

#### 執行時錯誤

1. **CORS 問題**：確保控制器允許控制台來源
2. **憑證錯誤**：將控制器憑證加入信任存放區
3. **API 連線**：驗證控制器是否可存取

#### 開發問題

```bash
# 連接埠已被使用
# 終止佔用 4200 連接埠的程序
lsof -ti:4200 | xargs kill -9

# 建置時記憶體不足
export NODE_OPTIONS="--max-old-space-size=4096"
npm run build
```

### 偵錯模式

啟用偵錯記錄：
```typescript
// 在瀏覽器控制台中
localStorage.setItem('debug', 'true');
location.reload();
```

## 🤝 貢獻指南

歡迎貢獻！請遵循以下指南：

### 開發流程

1. Fork 儲存庫
2. 建立功能分支（`git checkout -b feature/amazing-feature`）
3. 提交變更（`git commit -m 'Add amazing feature'`）
4. 推送到分支（`git push origin feature/amazing-feature`）
5. 開啟 Pull Request

### 編碼標準

- 遵循 Angular 風格指南
- 使用 TypeScript 嚴格模式
- 為新功能撰寫單元測試
- 視需要更新文件
- 為公開 API 新增 JSDoc 註解

### 提交慣例

遵循慣例式提交：
```
feat: 新增功能
fix: 修正元件中的錯誤
docs: 更新 README
style: 格式化程式碼
refactor: 重構服務
test: 新增單元測試
chore: 更新相依套件
```

### 測試要求

- 維持 >80% 的程式碼覆蓋率
- 所有測試必須通過
- 為新功能新增測試
- 為修改的程式碼更新測試

## 📄 授權資訊

[授權資訊 - 請在此加入您的授權]

## 🆘 支援

- **文件**：[OpenZiti 文件](https://openziti.io)
- **問題**：[GitHub Issues](https://github.com/openziti/ziti-console/issues)
- **社群**：[OpenZiti Discourse](https://openziti.discourse.group)
- **安全性**：將安全問題回報至 security@openziti.org

## 🔗 相關專案

- [OpenZiti](https://github.com/openziti/ziti)：零信任網路軟體
- [OpenZiti Controller](https://github.com/openziti/ziti/tree/main/controller)：網路控制器
- [OpenZiti Router](https://github.com/openziti/ziti/tree/main/router)：邊緣和轉運路由器
- [OpenZiti SDK](https://github.com/openziti/sdk-golang)：OpenZiti 的 Go SDK

## 📊 版本歷史

- **目前版本**：控制台 3.12.4、OpenZiti 1.5.4
- **Angular 版本**：16.x
- **Node.js 支援**：16.x 及更高版本

---

由 OpenZiti 社群用 ❤️ 製作