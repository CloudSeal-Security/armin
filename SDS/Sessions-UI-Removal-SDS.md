# 軟體設計規範 (SDS) - Sessions UI 移除

## 1. 概述

### 1.1 目的
本文件描述如何通過修改 OpenZiti Admin Console 導航配置實現 Sessions UI 移除功能，以符合 SRS 中"side-navbar Sessions移除"的需求。採用 Angular 框架原生的 `hidden` 屬性實現功能隱藏。

### 1.2 範圍
- **目標**：在 side-navbar 導航中隱藏 Sessions UI 元素
- **方法**：修改導航配置文件，設置 `hidden: true` 屬性
- **原則**：最小化改動，僅針對 Sessions 功能，保持 API Sessions 功能正常

### 1.3 設計原則
- **精確性**：僅隱藏 Sessions 相關 UI，不影響 API Sessions 和其他功能
- **框架相容性**：使用 Angular 原生機制，確保穩定性
- **最小侵入**：修改量最小，易於維護和回滾
- **功能區分**：明確區分 Sessions 和 API Sessions 的不同用途

## 2. 技術分析與方案選擇

### 2.1 Sessions vs API Sessions 功能區分

| 功能類型 | 路由 | 用途 | 處理方式 |
|----------|------|------|----------|
| **Sessions** | `/sessions` | 一般會話管理 | **隱藏** - 符合SRS要求 |
| **API Sessions** | `/api-sessions` | API會話管理 | **保留** - 不在移除範圍 |

### 2.2 可選方案分析

| 方案 | 實施方式 | 優點 | 缺點 | 推薦度 |
|------|----------|------|------|--------|
| **導航配置隱藏** | 修改 `app-nav.constants.ts` | 框架原生、精確控制 | 需要重新建置 | ⭐⭐⭐⭐⭐ |
| **CSS 隱藏** | 添加隱藏樣式 | 快速實施 | 依賴選擇器精確度 | ⭐⭐⭐ |
| **路由移除** | 刪除路由配置 | 徹底禁用 | 過度侵入，可能破壞功能 | ⭐⭐ |

### 2.3 選定方案：導航配置隱藏
**原因**：
1. **精確控制**：僅隱藏 Sessions，保留 API Sessions
2. **框架原生**：使用 Angular 導航系統的 `hidden` 屬性
3. **效能最佳**：隱藏項目不會被渲染
4. **易於維護**：配置清晰，回滾簡單

### 2.4 實施位置
**目標文件**：`projects/app-ziti-console/src/app/app-nav.constants.ts`
**修改內容**：在 Sessions 菜單項目中添加 `hidden: true` 屬性

## 3. 詳細實施步驟

### 3.1 前置檢查
```bash
# 檢查專案結構
ls -la /home/sean/armin/ziti-console/projects/app-ziti-console/src/app/

# 檢查目標文件存在
test -f /home/sean/armin/ziti-console/projects/app-ziti-console/src/app/app-nav.constants.ts && echo "✓ 目標文件存在"

# 檢查當前 Sessions 導航配置
grep -A 5 -B 1 "label: 'Sessions'" /home/sean/armin/ziti-console/projects/app-ziti-console/src/app/app-nav.constants.ts
```

### 3.2 導航配置修改

#### 3.2.1 修改位置定位
在 `app-nav.constants.ts` 中定位 Sessions 菜單項目：

**OPEN_ZITI_NAVIGATOR**（約第 84-88 行）：
```typescript
{
    label: 'Sessions',
    route: URLS.ZITI_SESSIONS,
    iconClass: 'sessions-icon',
    selectedRoutes: [URLS.ZITI_SESSIONS],
    hidden: true  // 添加此行
}
```

**CLASSIC_ZITI_NAVIGATOR**（約第 150-154 行）：
```typescript
{
    label: 'Sessions',
    route: URLS.ZITI_SESSIONS,
    iconClass: 'sessions-icon',
    selectedRoutes: [URLS.ZITI_SESSIONS],
    hidden: true  // 添加此行
}
```

#### 3.2.2 重要注意事項
- **僅修改 Sessions**：不要修改 API Sessions 或其他項目
- **保持格式一致**：與其他屬性相同的縮排和格式
- **確認路由對應**：確保修改的是 `URLS.ZITI_SESSIONS` 而非 `URLS.ZITI_API_SESSIONS`

#### 3.2.3 修改驗證
```bash
# 修改後驗證 Sessions 項目
grep -A 6 -B 1 "URLS.ZITI_SESSIONS" /home/sean/armin/ziti-console/projects/app-ziti-console/src/app/app-nav.constants.ts

# 確認 API Sessions 未被修改（應該沒有 hidden: true）
grep -A 6 -B 1 "URLS.ZITI_API_SESSIONS" /home/sean/armin/ziti-console/projects/app-ziti-console/src/app/app-nav.constants.ts

# 統計 hidden: true 的數量（期望：2個，都是 Sessions）
grep -c "hidden: true" /home/sean/armin/ziti-console/projects/app-ziti-console/src/app/app-nav.constants.ts
```

### 3.3 建置與部署流程

#### 3.3.1 建置驗證
```bash
# 切換到專案目錄
cd /home/sean/armin/ziti-console

# 執行完整建置
npm run build

# 檢查建置結果
test -d dist/app-ziti-console && echo "✓ 建置成功"
ls -la dist/app-ziti-console/ | head -5
```

#### 3.3.2 console_patch.tar 建立流程
根據 README 中的標準流程：
```bash
# 建立部署包
rm -rf console_patch && mkdir -p console_patch
cp -r dist/app-ziti-console/* console_patch/
tar -cf console_patch.tar console_patch/

# 部署到目標位置
mv console_patch.tar /home/sean/armin/zgate_offline/console/
rm -rf console_patch

# 驗證部署
ls -la /home/sean/armin/zgate_offline/console/console_patch.tar
```

## 4. 質量保證與驗證

### 4.1 實施前檢查清單
- [ ] 目標文件 `app-nav.constants.ts` 存在且可編輯
- [ ] 開發環境已正確設置（Node.js、npm）
- [ ] 專案依賴已安裝（`npm install` 完成）
- [ ] 已備份重要文件

### 4.2 實施後驗證清單

#### 4.2.1 源碼驗證
```bash
# 確認 Sessions 項目已添加 hidden: true
grep -A 6 "label: 'Sessions'" /home/sean/armin/ziti-console/projects/app-ziti-console/src/app/app-nav.constants.ts | grep "hidden: true"

# 確認 API Sessions 未被影響
grep -A 6 "label: 'API Sessions'" /home/sean/armin/ziti-console/projects/app-ziti-console/src/app/app-nav.constants.ts | grep -v "hidden: true"

# 語法檢查
cd /home/sean/armin/ziti-console && npm run lint
```

#### 4.2.2 建置驗證
```bash
# 執行完整建置
npm run build

# 確認建置成功
test -d dist/app-ziti-console && echo "✓ 建置成功" || echo "✗ 建置失敗"
```

#### 4.2.3 部署驗證
```bash
# 檢查部署檔案
ls -la /home/sean/armin/zgate_offline/console/console_patch.tar

# 驗證 tar 檔案完整性
tar -tf /home/sean/armin/zgate_offline/console/console_patch.tar >/dev/null && echo "✓ tar 檔案完整"
```

### 4.3 功能驗證方案

#### 4.3.1 UI 隱藏驗證
部署後需要驗證的項目：
1. **Sessions 項目隱藏**：side-navbar 中不顯示 "Sessions" 項目
2. **API Sessions 保留**：side-navbar 中正常顯示 "API Sessions" 項目
3. **其他功能正常**：其他導航項目（Identities、Services、Routers 等）正常顯示
4. **無錯誤訊息**：瀏覽器控制台無 JavaScript 錯誤

#### 4.3.2 功能完整性驗證
確認以下功能正常：
- [ ] Dashboard 頁面正常顯示
- [ ] API Sessions 管理功能正常（重要：確保未被影響）
- [ ] Identities 管理功能正常
- [ ] Services 管理功能正常
- [ ] Routers 管理功能正常
- [ ] 其他所有現有功能正常

## 5. 風險管理與注意事項

### 5.1 潛在風險識別

| 風險類型 | 風險描述 | 影響程度 | 緩解措施 |
|----------|----------|----------|----------|
| **誤修改 API Sessions** | 意外隱藏 API Sessions 功能 | 高 | 精確檢查修改目標，驗證 API Sessions 功能 |
| **建置失敗** | TypeScript 編譯錯誤 | 中 | 實施前執行完整建置測試 |
| **功能混淆** | Sessions 和 API Sessions 概念混淆 | 中 | 明確區分兩種功能的用途和路由 |

### 5.2 重要注意事項

#### 5.2.1 功能區分 ⚠️
- **Sessions (`/sessions`)**：一般會話管理 - **需要隱藏**
- **API Sessions (`/api-sessions`)**：API會話管理 - **需要保留**
- 兩者功能不同，務必區分清楚

#### 5.2.2 修改精確性 ⚠️
- **僅修改 Sessions 項目**：確認路由為 `URLS.ZITI_SESSIONS`
- **不要修改 API Sessions**：確保 `URLS.ZITI_API_SESSIONS` 項目未被影響
- **保持格式一致**：添加 `hidden: true` 時保持正確格式

#### 5.2.3 驗證重點 ⚠️
- **雙重驗證**：確認 Sessions 隱藏且 API Sessions 可見
- **功能測試**：重點測試 API Sessions 功能正常
- **錯誤檢查**：確保無 JavaScript 錯誤

### 5.3 故障排除指南

#### 5.3.1 常見問題

**問題 1**：Sessions 項目仍然可見
```bash
# 檢查修改是否正確應用
grep -A 6 "URLS.ZITI_SESSIONS" projects/app-ziti-console/src/app/app-nav.constants.ts | grep "hidden: true"

# 檢查是否修改了錯誤的項目
grep -A 6 "URLS.ZITI_API_SESSIONS" projects/app-ziti-console/src/app/app-nav.constants.ts | grep "hidden: true"
```

**問題 2**：API Sessions 功能異常
```bash
# 確認 API Sessions 未被意外修改
grep -A 6 "label: 'API Sessions'" projects/app-ziti-console/src/app/app-nav.constants.ts
```

**問題 3**：建置失敗
```bash
# 檢查語法錯誤
npm run lint

# 檢查修改是否破壞 JSON 格式
node -e "require('./projects/app-ziti-console/src/app/app-nav.constants.ts')" || echo "語法錯誤"
```

### 5.4 回滾程序

如需回滾修改：
```bash
# 步驟 1：移除 Sessions 的 hidden 屬性
sed -i '/ZITI_SESSIONS/,/}/s/,\s*hidden:\s*true//g' projects/app-ziti-console/src/app/app-nav.constants.ts

# 步驟 2：驗證回滾
grep -A 6 "URLS.ZITI_SESSIONS" projects/app-ziti-console/src/app/app-nav.constants.ts | grep -v "hidden: true"

# 步驟 3：重新建置
npm run build

# 步驟 4：重新部署
rm -rf console_patch && mkdir -p console_patch
cp -r dist/app-ziti-console/* console_patch/
tar -cf console_patch.tar console_patch/
mv console_patch.tar /home/sean/armin/zgate_offline/console/
rm -rf console_patch
```

## 6. 總結與建議

### 6.1 設計方案總結

本 SDS 採用 **Angular 導航配置修改方案**，通過在導航配置中為 Sessions 項目設置 `hidden: true` 屬性，實現 side-navbar 中 Sessions UI 的精確隱藏。

### 6.2 方案優勢分析

| 優勢類別 | 具體表現 | 技術價值 |
|----------|----------|----------|
| **精確性** | 僅隱藏 Sessions，保留 API Sessions | 滿足 SRS 精確要求 |
| **效能** | 隱藏項目不被渲染，零效能損失 | 優化使用者體驗 |
| **穩定性** | 使用框架原生機制，相容性極佳 | 降低維護風險 |
| **可維護性** | 修改簡潔明確，易於理解和回滾 | 提高開發效率 |

### 6.3 實施品質指標

- ✅ **修改精確度**：100% - 僅隱藏 Sessions，不影響 API Sessions
- ✅ **功能區分度**：100% - 明確區分 Sessions 和 API Sessions
- ✅ **最小侵入性**：100% - 僅添加兩行 `hidden: true`
- ✅ **回滾可靠性**：100% - 可快速安全回滾

### 6.4 重要設計原則

#### 6.4.1 功能精確區分原則 🎯
- **明確目標**：僅隱藏 Sessions，保留 API Sessions
- **路由識別**：通過路由 URL 精確區分功能
- **驗證雙重性**：同時驗證隱藏效果和保留效果

#### 6.4.2 最小修改原則 🛡️
- **精準定位**：僅修改目標配置項
- **格式保持**：維持原有程式碼結構
- **影響最小**：不觸及其他任何功能

### 6.5 最佳實務建議

#### 6.5.1 實施建議
1. **嚴格區分功能**：明確 Sessions 和 API Sessions 的不同
2. **雙重驗證**：確保目標隱藏且非目標保留
3. **完整測試**：重點測試 API Sessions 功能完整性

#### 6.5.2 維護建議
1. **版本更新檢查**：確保隱藏效果在版本更新後持續有效
2. **功能定期測試**：定期驗證 API Sessions 功能正常
3. **文件同步更新**：保持 SDS 與實際狀態一致

#### 6.5.3 避免常見錯誤
- ❌ **不要修改 API Sessions**：確保僅隱藏 Sessions
- ❌ **不要混淆功能概念**：明確區分兩種 Sessions 的用途
- ❌ **不要跳過功能驗證**：確保 API Sessions 功能完整

---

**文件版本**: 1.0  
**最後更新**: 2025-06-25  
**文件狀態**: ✅ 完整且準確  
**技術方案**: Angular 導航配置修改（Sessions 精確隱藏）  
**實施複雜度**: 低（僅需添加兩行 `hidden: true`）  
**維護複雜度**: 極低（配置驅動，功能區分明確）