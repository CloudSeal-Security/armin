# Z-Gate Console License Management

本項目實現了基於許可證的身份創建限制功能，支持有限制和無限制兩種模式。

## 功能特性

### 許可證模式
- **有限制模式** (`unlimited: false`): 根據配置的數量限制和時間範圍限制身份創建
- **無限制模式** (`unlimited: true`): 不限制身份數量，只檢查使用期限

### 身份限制
- 限制有效身份數量（排除 Router 類型和 Default Admin）
- 支持許可證使用期限檢查
- 實時顯示許可證狀態和使用情況

### 用戶界面
- 側邊導航欄顯示許可證狀態
- 進度條顯示使用情況（僅有限制模式）
- 狀態指示器顯示許可證狀態
- 無限制模式顯示無限符號 (∞)

## 配置文件

許可證配置位於 `projects/ziti-console-lib/src/lib/assets/data/license_number.json`:

```json
{
  "number": 100,
  "start_date": "2025-01-01",
  "end_date": "2025-12-31",
  "unlimited": false,
  "description": "Z-Gate console License Configuration"
}
```

### 配置參數

| 參數 | 類型 | 說明 |
|------|------|------|
| `number` | number | 最大允許的身份數量（僅在有限制模式下有效） |
| `start_date` | string | 許可證開始日期 (YYYY-MM-DD) |
| `end_date` | string | 許可證結束日期 (YYYY-MM-DD) |
| `unlimited` | boolean | 是否為無限制模式 |
| `description` | string | 許可證描述 |

## 使用模式

### 有限制模式 (`unlimited: false`)
- 顯示格式: `當前數量 / 最大數量` (例如: `50 / 100`)
- 顯示進度條和使用百分比
- 顯示剩餘數量
- 時間顯示: `開始日期 - 結束日期`

### 無限制模式 (`unlimited: true`)
- 顯示格式: `∞` (無限符號)
- 不顯示進度條
- 不顯示剩餘數量
- 時間顯示: `Infinite Time`

## 許可證狀態

### 狀態類型
- **Active**: 許可證有效且未達限制
- **Low Quota**: 剩餘數量少於等於 5
- **Limit Reached**: 已達到最大數量限制
- **License Expired**: 許可證已過期
- **License Not Active**: 許可證尚未開始
- **Unlimited**: 無限制模式

### 視覺指示
- 綠色: 正常狀態
- 橙色: 警告狀態（低配額）
- 紅色: 錯誤狀態（過期、達到限制）
- 黃色: 未開始狀態
- 藍色: 無限制模式

## 實現細節

### 核心服務
- `LicenseCheckService`: 許可證檢查邏輯
- `IdentitiesFormService`: 身份創建時的許可證驗證

### 組件
- `LicenseStatusComponent`: 許可證狀態顯示組件
- `SideNavbarComponent`: 側邊導航欄（包含許可證狀態）

### 檢查邏輯
1. **時間檢查**: 驗證當前時間是否在許可證有效期內
2. **數量檢查**: 統計有效身份數量（排除 Router 和 Default Admin）
3. **模式檢查**: 根據 `unlimited` 設置決定是否進行數量限制

## 測試

項目包含完整的單元測試：

```bash
# 運行許可證相關測試
npm test -- --include="**/license-check.service.spec.ts"
npm test -- --include="**/license-status.component.spec.ts"
```

## 部署

1. 更新 `license_number.json` 配置文件
2. 重新構建應用
3. 部署到目標環境

## 注意事項

- 許可證檢查在身份創建時進行
- Router 類型和 Default Admin 身份不計入限制
- 無限制模式仍會檢查使用期限
- 許可證狀態實時更新
- 支持動態配置更新（需要重新載入頁面） 