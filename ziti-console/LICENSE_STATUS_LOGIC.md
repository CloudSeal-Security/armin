# License Status Logic Documentation

## 許可證狀態判斷邏輯

### 1. 基本條件判斷順序

許可證狀態按照以下優先順序進行判斷：

1. **License Expired** - 許可證已過期
2. **License Not Active** - 許可證尚未生效
3. **Unlimited** - 無限制模式
4. **Limit Reached** - 超過限制數量
5. **Low Quota** - 剩餘數量少於5個
6. **Active** - 正常狀態

### 2. 詳細判斷條件

#### 2.1 License Expired
- 條件：當前時間 > end_date
- 狀態：`license-expired`
- 文字：`License Expired`

#### 2.2 License Not Active
- 條件：當前時間 < start_date
- 狀態：`license-not-started`
- 文字：`License Not Active`

#### 2.3 Unlimited
- 條件：`unlimited: true`
- 狀態：`license-unlimited`
- 文字：`Unlimited`
- 特殊顯示：身份數量顯示為 `∞`，時間顯示為 `Infinite Time`

#### 2.4 Limit Reached
- 條件：`currentCount >= maxCount`（當前數量等於或超過限制數量）
- 狀態：`license-limit-reached`
- 文字：`Limit Reached`
- 注意：當達到或超過限制時顯示，無法創建新身份

#### 2.5 Low Quota
- 條件：`remainingCount < 5 && currentCount < maxCount`（剩餘數量少於5個且未達到限制）
- 狀態：`license-warning`
- 文字：`Low Quota`
- 注意：只有當剩餘數量小於5且未達到限制時才顯示

#### 2.6 Active
- 條件：以上所有條件都不滿足
- 狀態：`license-ok`
- 文字：`Active`

### 3. 身份數量計算

#### 3.1 有效身份計算
- 排除 Router 類型的身份
- 排除名稱為 "Default Admin" 的身份
- 只計算其他類型的身份

#### 3.2 剩餘數量計算
```typescript
remainingCount = Math.max(0, maxCount - currentCount)
```

### 4. 身份創建限制

#### 4.1 無限制模式
- 只檢查時間限制（start_date 和 end_date）
- 不檢查數量限制

#### 4.2 有限制模式
- 檢查時間限制
- 檢查數量限制：當 `currentCount >= maxCount` 時阻止創建
- 當 `currentCount === maxCount` 時無法創建新身份

### 5. UI 顯示邏輯

#### 5.1 進度條
- 無限制模式：不顯示進度條
- 有限制模式：顯示使用百分比
- 計算公式：`(currentCount / maxCount) * 100`

#### 5.2 警告樣式
- 剩餘數量小於5時，Remaining 數值顯示警告樣式
- 狀態為 Low Quota 時，整個卡片顯示警告樣式

### 6. 自動更新機制

#### 6.1 事件驅動更新
許可證狀態會自動響應以下事件：
- **身份創建**：當新身份創建成功後，自動更新許可證狀態
- **身份刪除**：當身份刪除成功後，自動更新許可證狀態
- **身份更新**：當身份更新成功後，自動更新許可證狀態

#### 6.2 事件服務
- **服務**：`LicenseEventsService`
- **事件類型**：
  - `identity_created` - 身份創建事件
  - `identity_deleted` - 身份刪除事件
  - `identity_updated` - 身份更新事件

#### 6.3 監聽組件
以下組件會自動監聽許可證更新事件：
- `LicenseStatusComponent` - 主要許可證狀態組件
- `SideNavbarComponent` - 側邊欄許可證狀態

#### 6.4 更新流程
1. 用戶執行身份操作（創建/刪除/更新）
2. 操作成功後，觸發相應的許可證事件
3. 許可證狀態組件接收到事件
4. 組件自動刷新許可證信息（重新計算數量、狀態等）
5. UI 即時更新顯示

### 7. 測試案例

#### 7.1 正常情況
- 當前數量：7，限制：10，剩餘：3 → Low Quota
- 當前數量：5，限制：10，剩餘：5 → Active
- 當前數量：9，限制：10，剩餘：1 → Low Quota

#### 7.2 達到限制
- 當前數量：10，限制：10，剩餘：0 → Limit Reached（不可創建）

#### 7.3 超過限制
- 當前數量：11，限制：10，剩餘：0 → Limit Reached（不可創建）

#### 7.4 無限制模式
- unlimited: true → Unlimited（顯示 ∞ 符號）

#### 7.5 自動更新測試
- 創建身份後：許可證狀態立即更新
- 刪除身份後：許可證狀態立即更新
- 更新身份後：許可證狀態立即更新

### 8. 配置文件

許可證配置位於：`/assets/data/license_number.json`

```json
{
  "unlimited": false,
  "number": 10,
  "start_date": "2025-01-01",
  "end_date": "2025-12-31",
  "description": "Z-Gate License Configuration"
}
```

### 9. 組件位置

- 主要組件：`LicenseStatusComponent`
- 側邊欄組件：`SideNavbarComponent`
- 服務：`LicenseCheckService`
- 事件服務：`LicenseEventsService`

### 10. 相關文件

- `projects/ziti-console-lib/src/lib/services/license-check.service.ts`
- `projects/ziti-console-lib/src/lib/services/license-events.service.ts`
- `projects/ziti-console-lib/src/lib/features/license-status/license-status.component.ts`
- `projects/ziti-console-lib/src/lib/features/sidebars/side-navbar/side-navbar.component.ts`
- `projects/ziti-console-lib/src/lib/features/projectable-forms/identity/identity-form.service.ts`
- `projects/ziti-console-lib/src/lib/pages/identities/identities-page.component.ts` 