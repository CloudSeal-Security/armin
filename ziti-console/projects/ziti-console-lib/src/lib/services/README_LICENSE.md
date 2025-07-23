# Ziti Console License Management

## 概述

Ziti Console 現在支持軟體使用限制功能，包括身份數量限制和使用期限管理。

## 功能特性

### 1. 身份數量限制
- 根據許可證配置限制可創建的身份數量
- 自動排除 Router 類型和 Default Admin 身份
- 實時顯示當前使用量和剩餘配額

### 2. 使用期限管理
- 支持許可證開始日期和結束日期
- 自動檢查許可證是否過期或尚未開始
- 在許可證無效時阻止創建新身份

### 3. 許可證狀態顯示
- 在身份頁面顯示許可證狀態
- 包含使用量進度條和狀態指示器
- 提供詳細的許可證信息

## 配置

### 許可證配置文件

創建文件 `assets/data/license_number.json`：

```json
{
  "number": 100,
  "start_date": "2025-01-01",
  "end_date": "2025-04-30",
  "description": "Ziti Console License Configuration"
}
```

### 配置參數說明

- `number`: 允許創建的最大身份數量（不包括 Router 和 Default Admin）
- `start_date`: 許可證開始日期（YYYY-MM-DD 格式）
- `end_date`: 許可證結束日期（YYYY-MM-DD 格式）
- `description`: 許可證描述（可選）

## 使用方式

### 1. 自動檢查

系統會在以下情況自動進行許可證檢查：

- 用戶點擊創建身份按鈕時
- 提交身份創建表單時
- 頁面載入時（顯示許可證狀態）

### 2. 手動檢查

```typescript
import { LicenseCheckService } from './services/license-check.service';

constructor(private licenseCheckService: LicenseCheckService) {}

async checkLicense() {
  const result = await this.licenseCheckService.canCreateIdentity();
  if (result.canCreate) {
    // 允許創建身份
  } else {
    // 顯示錯誤信息
    console.log(result.reason);
  }
}
```

### 3. 獲取許可證信息

```typescript
// 獲取剩餘身份數量
const remaining = await this.licenseCheckService.getRemainingIdentitiesCount();

// 檢查許可證是否過期
const isExpired = this.licenseCheckService.isLicenseExpired();

// 檢查許可證是否尚未開始
const notStarted = this.licenseCheckService.isLicenseNotStarted();
```

## 組件使用

### LicenseStatusComponent

在模板中使用許可證狀態組件：

```html
<lib-license-status></lib-license-status>
```

該組件會自動顯示：
- 當前身份使用量
- 剩餘配額
- 許可證有效期
- 使用量進度條
- 許可證狀態指示器

## 錯誤處理

當許可證檢查失敗時，系統會：

1. 顯示錯誤消息給用戶
2. 阻止身份創建操作
3. 在控制台記錄詳細錯誤信息

### 常見錯誤情況

- **許可證過期**: "License has expired. License expired on 2025-04-30"
- **許可證未開始**: "License is not active yet. License starts from 2025-01-01"
- **數量限制**: "Maximum number of identities (100) reached. Current count: 100"
- **配置錯誤**: "Failed to verify identity count limit"

## 測試

運行許可證檢查服務的測試：

```bash
ng test --include="**/license-check.service.spec.ts"
```

## 注意事項

1. **Router 類型排除**: 系統自動排除 `typeId` 為 "Router" 或 `type.name` 為 "Router" 的身份
2. **Default Admin 排除**: 系統自動排除名稱為 "Default Admin" 的身份
3. **日期格式**: 許可證日期必須使用 YYYY-MM-DD 格式
4. **配置文件路徑**: 許可證配置文件必須位於 `assets/data/license_number.json`
5. **錯誤恢復**: 如果無法載入許可證配置，系統會使用預設配置

## 擴展

如需添加更多許可證檢查邏輯，可以：

1. 擴展 `LicenseCheckService` 類
2. 添加新的檢查方法
3. 修改 `canCreateIdentity` 方法以包含新的檢查邏輯
4. 更新許可證狀態組件以顯示新的信息 