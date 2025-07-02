# 更新 CA

- [更新 CA](#更新-ca)
  - [步驟](#步驟)
  - [caReplace.sh 腳本](#careplacesh-腳本)
    - [腳本參數](#腳本參數)
    - [腳本流程](#腳本流程)

## 步驟

1. 設定 CA 的設定檔

    更改 `caCfg.yaml` 的參數，調整為理想的 CA 設定，基本結構如下：

    ```yaml
    type: # root 或是 intermediate 或是 server 或是 client
    cert: # 證書路徑
    private_key: # 私鑰路徑
    csr: # 簽名請求路徑
    is_ca: # 是否為可簽發其他證書的 CA
    organization: # 組織名稱
    common_name: # 通用名稱
    validity_years: # 有效期間 - 年
    validity_month: # 有效期間 - 月
    validity_day: # 有效期間 - 日
    ```

2. 設定欲替換的 CA 路徑

    設定 `caPath.yaml` 的參數，調整為理想的 CA 路徑，基本結構如下：

    ```yaml
    ca:
        root:
            cert: # 根證書路徑
            key: # 根私鑰路徑
        intermediate:
            cert: # 中間證書路徑
            key: # 中間私鑰路徑
            chain: # 中間鏈路徑
        client:
            cert: # 客戶端證書路徑
            key: # 客戶端私鑰路徑
            chain: # 客戶端鏈路徑
        server:
            cert: # 伺服器證書路徑
            key: # 伺服器私鑰路徑
            chain: # 伺服器鏈路徑
    ```

3. 執行腳本

    執行腳本 `caReplace.sh`，預設使用 `./caPath.yaml` 進行替換，若要使用其他路徑，請在執行腳本時傳入其他路徑。

    ```bash
    ./caReplace.sh [caPath.yaml 路徑]
    ```

## caReplace.sh 腳本

### 腳本參數

- `caPath.yaml` 路徑（預設為 `./caPath.yaml`）

### 腳本流程

1. 使用 `cert-go` 產生自簽 CA
2. 獲取 CA 路徑並顯示檔案路徑
3. 替換 CA，替換後由 cert-go 產生的 CA 檔案會被複製到 `/var/lib/private/ziti-controller/pki` 目錄下，可刪除由 cert-go 產生的 CA 檔案
4. 停用 renew CA（`/opt/openziti/etc/controller/service.env` 中的 `ZITI_AUTO_RENEW_CERTS` 設為 `false`）
5. 重新啟動 ziti-controller

