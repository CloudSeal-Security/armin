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