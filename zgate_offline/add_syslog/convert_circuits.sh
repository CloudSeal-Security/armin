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