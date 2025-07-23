# ziti log

建立者: erlichlin
建立時間: 2025年6月10日 上午10:52
最後編輯者: erlichlin
最後更新時間: 2025年6月23日 下午4:15

# 背景

```bash
sudo vi /var/lib/private/ziti-controller/config.yml
```

```
events:
  jsonLogger:
    subscriptions:
      - type: fabric.circuits
        interval: 5s
    handler:
      type: file
      format: json
      path: events.log
```

```bash
sudo mkdir -p /opt/openziti/scripts /var/lib/private/ziti-controller/log
sudo touch /opt/openziti/scripts/convert_circuits.sh
sudo chmod 750 /opt/openziti/scripts/convert_circuits.sh
```

必要套件
1. **`inotifywait`** 工具來監控檔案變化
2. jq 

```bash
sudo apt install jq -y
sudo apt install inotify-tools -y
```

```bash
**sudo vi /opt/openziti/scripts/convert_circuits.sh**
```

```bash
_header
CEF:Version = CEF:0
Device Vendor = eCloudseal
Device Product = Z-Gate
Device Version = 1.1.18
Signature ID = %circuit_id
Name = %event_type
Severity = 5

datetime = %timestamp //收到與活動相關的事件的時間。 = 
cid = %client_name	//可唯一識別產生事件的裝置名稱。
cip	= %client_ip //產生事件的裝置 IPv4 位址。
rid = %router_name //與事件相關聯的來源進程標識碼。
rip = %router_ip //事件在IP網路中參考的來源，作為IPv4位址。
rpt = %router_port //來源埠號碼。
vid = %service_name //事件相關聯的目的地進程標識碼。
vip = %service_ip //事件在IP網路中參考的目的地IpV4位址。
vpt = %service_port //目的地連接埠。
```

```bash
#!/bin/bash

# 來源檔案和輸出檔案
INPUT_LOG="/var/lib/private/ziti-controller/events.log"
OUTPUT_LOG="/var/lib/private/ziti-controller/log/circuit.log"
PROCESSED_IDS_LOG="/tmp/ziti_processed_ids.log"

# Ziti登入權証
ZITI_CTRL_EDGE_API="https://localhost:1280"
ZITI_USER="admin"
ZITI_PASSWORD="admin"

# 確保輸出目錄存在
mkdir -p "$(dirname "$OUTPUT_LOG")"
touch "$PROCESSED_IDS_LOG"

# 初始化Ziti登入 (帶自動重試)
ziti_edge_login() {
    while true; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 正在登入Ziti Edge..."
        if ziti edge login "${ZITI_CTRL_EDGE_API}" -u "${ZITI_USER}" -p "${ZITI_PASSWORD}" --yes; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 登入成功"
            break
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 登入失敗，10秒後重試..."
            sleep 10
        fi
    done
}

# 執行Ziti命令 (帶自動登入重試)
ziti_cmd_with_retry() {
    local cmd="$@"
    local retry_count=0
    
    while [[ $retry_count -lt 3 ]]; do
        # 執行命令
        result=$(eval "$cmd" 2>/dev/null)
        exit_code=$?
        
        # 檢查是否因登入過期失敗
        if [[ $exit_code -ne 0 ]] || [[ -z "$result" ]]; then
            ((retry_count++))
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 命令執行失敗，重新登入 (嘗試 $retry_count)"
            ziti_edge_login
            continue
        fi
        
        # 輸出結果
        echo "$result"
        return 0
    done
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 錯誤: 命令重試3次仍失敗: $cmd"
    return 1
}

# 快取API Sessions資料 (identityId -> ipAddress)
declare -A api_session_ips

# 載入API Sessions IP資訊 (帶自動重試)
load_api_session_ips() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 正在載入API Sessions IP資訊..."
    
    # 清空快取
    unset api_session_ips
    declare -gA api_session_ips
    
    # 使用帶重試的ziti命令 (明確添加limit參數)
    local api_sessions_json=$(ziti_cmd_with_retry "ziti edge list api-sessions 'limit 99999' -j")
    
    # 使用jq解析並填充快取
    while IFS=" " read -r identity_id ip_address; do
        [[ -n "$identity_id" && -n "$ip_address" ]] && api_session_ips["$identity_id"]="$ip_address"
    done < <(echo "$api_sessions_json" | jq -r '.data[]? | "\(.identityId) \(.ipAddress)"')
}

# 獲取客戶端真實IP
get_client_real_ip() {
    local client_id="$1"
    [[ -n "${api_session_ips[$client_id]}" ]] && echo "${api_session_ips[$client_id]}"
}

# 檢查是否已處理過該條目
is_processed() {
    local circuit_id="$1"
    local event_type="$2"
    grep -qF "${circuit_id}_${event_type}" "$PROCESSED_IDS_LOG"
    return $?
}

# 標記為已處理
mark_processed() {
    local circuit_id="$1"
    local event_type="$2"
    echo "${circuit_id}_${event_type}" >> "$PROCESSED_IDS_LOG"
}

# 查詢Ziti實體名稱 (帶緩存和重試)
query_ziti_entity() {
    local entity_type="$1"
    local entity_id="$2"
    
    # 特殊處理空ID情況
    [[ -z "$entity_id" ]] && echo "unknown" && return
    
    # 緩存查詢結果
    local cache_file="/tmp/ziti_${entity_type}_cache.json"
    local cache_age=300  # 5分鐘緩存
    
    # 如果緩存不存在或過期，重新查詢 (明確添加limit參數)
    if [[ ! -f "$cache_file" ]] || (( $(date +%s) - $(stat -c %Y "$cache_file") > cache_age )); then
        case "$entity_type" in
            "identity")
                ziti_cmd_with_retry "ziti edge list identities 'limit 99999' -j" > "$cache_file"
                ;;
            "edge-router")
                ziti_cmd_with_retry "ziti edge list edge-routers 'limit 99999' -j" > "$cache_file"
                ;;
            "service")
                ziti_cmd_with_retry "ziti fabric list services 'limit 99999' -j" > "$cache_file"
                ;;
        esac
        
        # 檢查緩存是否成功生成
        [[ ! -s "$cache_file" ]] && rm -f "$cache_file"
    fi
    
    # 從緩存中查詢
    if [[ -f "$cache_file" ]]; then
        jq -r --arg id "$entity_id" '.data[]? | select(.id == $id) | .name // "unknown"' "$cache_file"
    else
        echo "unknown"
    fi
}

# 處理單行日誌
process_line() {
    local line="$1"
    
    # 解析JSON字段
    circuit_id=$(echo "$line" | jq -r '.circuit_id?')
    event_type=$(echo "$line" | jq -r '.event_type?')
    timestamp=$(echo "$line" | jq -r '.timestamp?' | sed 's/\.[0-9]*//' | sed 's/+[0-9]*:[0-9]*//' | sed 's/T/ /')
    client_id=$(echo "$line" | jq -r '.tags.clientId?')
    service_id=$(echo "$line" | jq -r '.tags.serviceId?')
    router_id=$(echo "$line" | jq -r '.tags.hostId?')
    
    # 檢查必要字段
    [[ -z "$circuit_id" || -z "$event_type" ]] && return
    
    # 檢查是否已處理過
    if is_processed "$circuit_id" "$event_type"; then
        return
    fi
    
    # 直接獲取已分開的地址信息
    src_ip_port=$(echo "$line" | jq -r '.path.terminator_local_addr?')
    dst_ip_port=$(echo "$line" | jq -r '.path.terminator_remote_addr?')
    
    src_ip=$(echo "$src_ip_port" | cut -d: -f1)
    src_port=$(echo "$src_ip_port" | cut -d: -f2)
    dst_ip=$(echo "$dst_ip_port" | cut -d: -f1)
    dst_port=$(echo "$dst_ip_port" | cut -d: -f2)
    
    # 查詢相關名稱 (使用帶緩存和重試的查詢)
    client_name=$(query_ziti_entity "identity" "$client_id")
    router_name=$(query_ziti_entity "edge-router" "$router_id")
    service_name=$(query_ziti_entity "service" "$service_id")
    
    # 獲取客戶端真實IP
    client_real_ip=$(get_client_real_ip "$client_id")
    
    # 生成CEF格式日誌
    cef_header="CEF:0|eCloudseal|Z-Gate|1.1.18|${circuit_id}|${event_type}|5"
    
    # CEF擴展字段 (確保所有字段都有值)
    cef_extension=""
    cef_extension+="datetime=\"${timestamp}\" "
    cef_extension+="cid=${client_name} "
    [[ -n "$client_real_ip" ]] && cef_extension+="cip=${client_real_ip} "
    cef_extension+="rid=${router_name} "
    cef_extension+="rip=${src_ip} "
    cef_extension+="rpt=${src_port} "
    cef_extension+="vid=${service_name} "
    cef_extension+="vip=${dst_ip} "
    cef_extension+="vpt=${dst_port}"
    
    # 寫入輸出文件
    (
      flock -x 200
      echo "${cef_header}|${cef_extension}" >> "$OUTPUT_LOG"
      mark_processed "$circuit_id" "$event_type"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 已處理電路: ${circuit_id} (cid:${client_name} rid:${router_name} sid:${service_name})"
    ) 200>"$OUTPUT_LOG.lock"
}

# 主處理函數
main_processor() {
    # 初始登入
    ziti_edge_login
    
    # 載入初始API Sessions
    load_api_session_ips
    
    # 處理現有的日誌內容
    grep '"namespace":"fabric.circuits"' "$INPUT_LOG" | while read -r line; do
        process_line "$line"
    done
    
    # 主循環 (每5分鐘刷新API Sessions)
    while true; do
        # 監控新日誌條目 (300秒超時)
        inotifywait -e modify -t 300 "$INPUT_LOG" 2>/dev/null || true
        
        # 刷新API Sessions
        load_api_session_ips
        
        # 處理新增的日誌內容
        grep '"namespace":"fabric.circuits"' "$INPUT_LOG" | while read -r line; do
            process_line "$line"
        done
    done
}

# 啟動主處理器
main_processor
```

做成服務開機運行

```bash
sudo vi /etc/systemd/system/zgate.log.service
```

```
[Unit]
Description=Z-Gate Log Converter
BindsTo=ziti-controller.service
After=network-online.target ziti-controller.service
Requires=ziti-controller.service
PartOf=ziti-controller.service

[Service]
Type=exec
ExecStart=/opt/openziti/scripts/convert_circuits.sh
Restart=on-failure
RestartSec=10s
User=root
WorkingDirectory=/opt/openziti/scripts
StandardOutput=journal
StandardError=journal

# 資源限制 (根據實際情況調整)
# MemoryLimit=200M
# CPUQuota=50%

# 日誌限制
LogRateLimitIntervalSec=30s
LogRateLimitBurst=500

[Install]
WantedBy=multi-user.target
```

```bash
sudo chmod +x /opt/openziti/scripts/convert_circuits.sh
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now zgate.log.service
sudo systemctl restart --now zgate.log.service
```

```bash
sudo systemctl restart --now ziti-controller.service
sudo systemctl restart --now ziti-router.service
```

send to rsyslog server 192.168.111.99:514

```bash
#!/bin/bash

# 來源檔案和輸出檔案
INPUT_LOG="/var/lib/private/ziti-controller/events.log"
OUTPUT_LOG="/var/lib/private/ziti-controller/circuit_log/circuit.log"
TMP_LOG="/tmp/ziti_circuit_tmp.log"

# Logserver設定
LOGSERVER_IP="192.168.111.99"
LOGSERVER_PORT="514"

# Ziti登入權証
ZITI_CTRL_EDGE_API="https://cmd.ad.example.vm:1280"
ZITI_USER="admin"
ZITI_PASSWORD="admin"

# 確保輸出目錄存在
mkdir -p "$(dirname "$OUTPUT_LOG")"

echo "正在登入Ziti Edge..."
ziti edge login "${ZITI_CTRL_EDGE_API}" -u "${ZITI_USER}" -p "${ZITI_PASSWORD}" --yes

# 初始化檔案
# > "$OUTPUT_LOG"
# > "$TMP_LOG"

# 宣告關聯陣列來追蹤已處理的電路
declare -A processed_circuits

# 快取API Sessions資料 (identityId -> ipAddress)
declare -A api_session_ips

# 載入API Sessions IP資訊
load_api_session_ips() {
    echo "正在載入API Sessions IP資訊..."
    local api_sessions_json=$(ziti edge list api-sessions -j)
    
    # 使用jq解析並填充快取
    while read -r identity_id ip_address; do
        [[ -n "$identity_id" && -n "$ip_address" ]] && api_session_ips["$identity_id"]="$ip_address"
    done < <(echo "$api_sessions_json" | jq -r '.data[] | "\(.identityId) \(.ipAddress)"')
}

# 獲取客戶端真實IP
get_client_real_ip() {
    local client_id="$1"
    echo "${api_session_ips[$client_id]}"
}

# 發送日誌到遠端logserver
send_to_logserver() {
    local message="$1"
    # 使用logger發送，設置適當的facility和priority
    logger -n "$LOGSERVER_IP" -P "$LOGSERVER_PORT" -t "Ziti-Circuit" -p local4.info "$message"
    
    # 或者直接使用netcat (如果logger不可用)
    # echo "$message" | nc -u -w1 "$LOGSERVER_IP" "$LOGSERVER_PORT"
}

# 處理單行日誌
process_line() {
    local line="$1"
    
    # 解析JSON字段
    circuit_id=$(echo "$line" | jq -r '.circuit_id')
    event_type=$(echo "$line" | jq -r '.event_type')
    timestamp=$(echo "$line" | jq -r '.timestamp' | sed 's/+08:00//' | cut -d. -f1 | sed 's/T/ /')
    client_id=$(echo "$line" | jq -r '.tags.clientId')
    service_id=$(echo "$line" | jq -r '.service_id')
    router_id=$(echo "$line" | jq -r '.path.nodes[0]')
    
    # 組合唯一識別碼 (電路ID + 事件類型)
    local unique_id="${circuit_id}_${event_type}"
    
    # 檢查是否已處理過
    if [[ -z "${processed_circuits[$unique_id]}" ]]; then
        # 標記為已處理
        processed_circuits["$unique_id"]=1
        
        # 直接獲取已分開的地址信息
        src_ip_port=$(echo "$line" | jq -r '.path.terminator_local_addr')
        dst_ip_port=$(echo "$line" | jq -r '.path.terminator_remote_addr')
        
        src_ip=$(echo "$src_ip_port" | cut -d: -f1)
        src_port=$(echo "$src_ip_port" | cut -d: -f2)
        dst_ip=$(echo "$dst_ip_port" | cut -d: -f1)
        dst_port=$(echo "$dst_ip_port" | cut -d: -f2)
        
        # 查詢相關名稱
        client_name=$(ziti edge list identities -j | jq -r --arg id "$client_id" '.data[] | select(.id == $id) | .name')
        router_name=$(ziti edge list edge-routers -j | jq -r --arg id "$router_id" '.data[] | select(.id == $id) | .name')
        service_name=$(ziti fabric list services -j | jq -r --arg id "$service_id" '.data[] | select(.id == $id) | .name')
        
        # 獲取客戶端真實IP
        client_real_ip=$(get_client_real_ip "$client_id")
        
        # 生成CEF格式日誌
        cef_header="CEF:0|eCloudseal|Z-Gate|1.1.18|${circuit_id}|${event_type}|5"
        
        # CEF擴展字段
        cef_extension=""
        cef_extension+="rt=\"${timestamp}\" "
        cef_extension+="deviceExternalId=${client_name} "
        [[ -n "$client_real_ip" ]] && cef_extension+="dvc=${client_real_ip} "
        cef_extension+="spid=${router_name} "
        cef_extension+="src=${src_ip} "
        cef_extension+="spt=${src_port} "
        cef_extension+="dpid=${service_name} "
        cef_extension+="dst=${dst_ip} "
        cef_extension+="dpt=${dst_port}"
        
        # 完整的CEF日誌
        cef_log="${cef_header}|${cef_extension}"
        
        # 寫入臨時日誌文件
        echo "${cef_log}" >> "$TMP_LOG"
        
        # 使用flock確保寫入輸出的原子性
        (
          flock -x 200
          # 檢查最終輸出文件中是否已存在相同條目
          if ! grep -qF "${cef_log}" "$OUTPUT_LOG"; then
            echo "${cef_log}" >> "$OUTPUT_LOG"
            # 發送到遠端logserver
            send_to_logserver "${cef_log}"
          fi
        ) 200>"$OUTPUT_LOG.lock"
    fi
}

# 處理現有日誌內容
process_existing_logs() {
    grep '"namespace":"fabric.circuits"' "$INPUT_LOG" | while read -r line; do
        process_line "$line"
    done
}

# 先載入API Sessions IP資訊
load_api_session_ips

# 先處理現有的日誌內容
process_existing_logs

# 使用inotifywait監控檔案變化
echo "開始監控 $INPUT_LOG 的變化..."
inotifywait -m -e modify "$INPUT_LOG" | while read -r directory event filename; do
    # 每小時重新載入一次API Sessions資料
    if (( $(date +%s) % 3600 == 0 )); then
        load_api_session_ips
    fi
    
    # 獲取新增的行
    new_lines=$(tail -n1 "$INPUT_LOG")
    
    # 檢查是否包含circuits命名空間
    if echo "$new_lines" | grep -q '"namespace":"fabric.circuits"'; then
        process_line "$new_lines"
    fi
done
```

修改rsyslog.conf

```bash
sudo vi /etc/rsyslog.conf
```

```
$ModLoad imudp
$UDPServerRun 514

$template RawFormat,"%msg%\n"
*.* @192.168.111.99:514;RawFormat
```

```bash
sudo systemctl restart rsyslog
```

修改server rsyslog.conf

```bash
sudo vi /etc/rsyslog.conf
```

```
$ModLoad imudp
$UDPServerRun 514

$template CEFFormat,"/var/log/ziti-cef/%$YEAR%-%$MONTH%-%$DAY%.log"
local4.* ?CEFFormat
```

```bash
sudo mkdir -p /var/log/ziti-cef
sudo chown syslog:syslog /var/log/ziti-cef
sudo systemctl restart rsyslog
```
