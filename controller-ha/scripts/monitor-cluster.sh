#!/bin/bash

#
# OpenZiti Controller HA 持續監控腳本
# 持續監控叢集狀態並記錄日誌
#

set -euo pipefail

# 預設配置
MONITOR_INTERVAL="${MONITOR_INTERVAL:-60}"  # 監控間隔（秒）
LOG_FILE="${LOG_FILE:-/var/log/ziti-controller/ha-monitor.log}"
PID_FILE="${PID_FILE:-/var/run/ziti-ha-monitor.pid}"
MAX_LOG_SIZE="${MAX_LOG_SIZE:-10485760}"  # 10MB
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
ALERT_EMAIL="${ALERT_EMAIL:-}"

# 健康檢查腳本路徑
HEALTH_CHECK_SCRIPT="$(dirname "$0")/health-check.sh"

# 狀態追蹤
LAST_CLUSTER_STATUS=""
LAST_CONTROLLER_COUNT=0
ALERT_COOLDOWN=300  # 5分鐘警報冷卻時間
LAST_ALERT_TIME=0

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_with_timestamp() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log_with_timestamp "INFO" "$1"
}

log_warn() {
    log_with_timestamp "WARN" "$1"
}

log_error() {
    log_with_timestamp "ERROR" "$1"
}

show_usage() {
    echo "用法: $0 [選項] {start|stop|status|restart}"
    echo ""
    echo "選項:"
    echo "  -h, --help          顯示此說明"
    echo "  -i, --interval SEC  監控間隔秒數 [預設: 60]"
    echo "  -l, --log FILE      日誌檔案路徑 [預設: /var/log/ziti-controller/ha-monitor.log]"
    echo "  --webhook URL       警報 Webhook URL"
    echo "  --email ADDRESS     警報電子郵件地址"
    echo ""
    echo "動作:"
    echo "  start              啟動監控"
    echo "  stop               停止監控"
    echo "  status             顯示監控狀態"
    echo "  restart            重啟監控"
    echo ""
    echo "環境變數:"
    echo "  MONITOR_INTERVAL   監控間隔 [預設: 60]"
    echo "  LOG_FILE           日誌檔案 [預設: /var/log/ziti-controller/ha-monitor.log]"
    echo "  ALERT_WEBHOOK      警報 Webhook URL"
    echo "  ALERT_EMAIL        警報電子郵件"
}

check_requirements() {
    # 檢查健康檢查腳本
    if [[ ! -x "$HEALTH_CHECK_SCRIPT" ]]; then
        log_error "健康檢查腳本不存在或無執行權限: $HEALTH_CHECK_SCRIPT"
        exit 1
    fi
    
    # 檢查日誌目錄
    local log_dir=$(dirname "$LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir"
        log_info "建立日誌目錄: $log_dir"
    fi
    
    # 檢查 PID 目錄
    local pid_dir=$(dirname "$PID_FILE")
    if [[ ! -d "$pid_dir" ]]; then
        mkdir -p "$pid_dir"
        log_info "建立 PID 目錄: $pid_dir"
    fi
}

rotate_log() {
    if [[ -f "$LOG_FILE" ]]; then
        local log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        
        if [[ $log_size -gt $MAX_LOG_SIZE ]]; then
            log_info "輪轉日誌檔案 (大小: $log_size bytes)"
            mv "$LOG_FILE" "${LOG_FILE}.old"
            touch "$LOG_FILE"
        fi
    fi
}

send_alert() {
    local subject="$1"
    local message="$2"
    local current_time=$(date +%s)
    
    # 檢查警報冷卻時間
    if [[ $((current_time - LAST_ALERT_TIME)) -lt $ALERT_COOLDOWN ]]; then
        log_info "警報在冷卻期間，跳過發送"
        return 0
    fi
    
    LAST_ALERT_TIME=$current_time
    
    # 發送 Webhook 警報
    if [[ -n "$ALERT_WEBHOOK" ]]; then
        local payload=$(cat <<EOF
{
    "text": "$subject",
    "attachments": [
        {
            "color": "danger",
            "fields": [
                {
                    "title": "詳細資訊",
                    "value": "$message",
                    "short": false
                },
                {
                    "title": "時間",
                    "value": "$(date)",
                    "short": true
                }
            ]
        }
    ]
}
EOF
        )
        
        if curl -s -X POST -H "Content-Type: application/json" \
           -d "$payload" "$ALERT_WEBHOOK" > /dev/null; then
            log_info "Webhook 警報已發送"
        else
            log_error "Webhook 警報發送失敗"
        fi
    fi
    
    # 發送電子郵件警報
    if [[ -n "$ALERT_EMAIL" ]] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
        log_info "電子郵件警報已發送到: $ALERT_EMAIL"
    fi
}

analyze_cluster_status() {
    local health_output="$1"
    local current_status=""
    local current_healthy=0
    local current_total=0
    
    # 解析健康檢查輸出
    if echo "$health_output" | grep -q "healthy_count:"; then
        current_healthy=$(echo "$health_output" | grep "healthy_count:" | cut -d: -f2)
        current_total=$(echo "$health_output" | grep "total_count:" | cut -d: -f2)
    fi
    
    # 判斷狀態
    if [[ $current_healthy -eq $current_total && $current_healthy -ge 3 ]]; then
        current_status="HEALTHY"
    elif [[ $current_healthy -ge 2 ]]; then
        current_status="DEGRADED"
    else
        current_status="CRITICAL"
    fi
    
    # 檢查狀態變化
    if [[ "$current_status" != "$LAST_CLUSTER_STATUS" ]]; then
        log_info "叢集狀態變化: $LAST_CLUSTER_STATUS -> $current_status"
        
        case "$current_status" in
            "HEALTHY")
                log_info "叢集已恢復健康狀態"
                if [[ "$LAST_CLUSTER_STATUS" == "CRITICAL" || "$LAST_CLUSTER_STATUS" == "DEGRADED" ]]; then
                    send_alert "OpenZiti HA 叢集已恢復" "叢集已恢復到健康狀態，所有控制器正常運行"
                fi
                ;;
            "DEGRADED")
                log_warn "叢集處於降級狀態"
                send_alert "OpenZiti HA 叢集降級" "叢集處於降級狀態，部分控制器不可用 ($current_healthy/$current_total)"
                ;;
            "CRITICAL")
                log_error "叢集處於危險狀態"
                send_alert "OpenZiti HA 叢集危險" "叢集處於危險狀態，大部分控制器不可用 ($current_healthy/$current_total)"
                ;;
        esac
        
        LAST_CLUSTER_STATUS="$current_status"
    fi
    
    # 檢查控制器數量變化
    if [[ $current_healthy -ne $LAST_CONTROLLER_COUNT ]]; then
        log_info "健康控制器數量變化: $LAST_CONTROLLER_COUNT -> $current_healthy"
        LAST_CONTROLLER_COUNT=$current_healthy
    fi
}

monitor_loop() {
    log_info "開始監控 OpenZiti HA 叢集"
    log_info "監控間隔: ${MONITOR_INTERVAL}秒"
    log_info "日誌檔案: $LOG_FILE"
    
    while true; do
        # 輪轉日誌
        rotate_log
        
        # 執行健康檢查
        local health_output=""
        if health_output=$("$HEALTH_CHECK_SCRIPT" --format simple 2>&1); then
            log_info "健康檢查完成"
            analyze_cluster_status "$health_output"
        else
            log_error "健康檢查失敗: $health_output"
            send_alert "OpenZiti HA 監控警報" "健康檢查腳本執行失敗"
        fi
        
        # 等待下次檢查
        sleep "$MONITOR_INTERVAL"
    done
}

start_monitor() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "監控已在運行 (PID: $(cat "$PID_FILE"))"
        exit 1
    fi
    
    log_info "啟動 HA 監控程序"
    
    # 在背景執行監控
    nohup bash -c "
        echo \$\$ > '$PID_FILE'
        exec '$0' --internal-monitor
    " > /dev/null 2>&1 &
    
    local monitor_pid=$!
    sleep 2
    
    if kill -0 "$monitor_pid" 2>/dev/null; then
        echo "監控已啟動 (PID: $monitor_pid)"
    else
        echo "監控啟動失敗"
        exit 1
    fi
}

stop_monitor() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "停止 HA 監控程序 (PID: $pid)"
            kill "$pid"
            rm -f "$PID_FILE"
            echo "監控已停止"
        else
            echo "監控程序不存在"
            rm -f "$PID_FILE"
        fi
    else
        echo "監控未在運行"
    fi
}

show_monitor_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "監控正在運行 (PID: $pid)"
            echo "日誌檔案: $LOG_FILE"
            echo "最後幾行日誌:"
            tail -5 "$LOG_FILE" 2>/dev/null || echo "無法讀取日誌檔案"
        else
            echo "監控程序已死亡"
            rm -f "$PID_FILE"
        fi
    else
        echo "監控未在運行"
    fi
}

main() {
    local action=""
    local internal_monitor=false
    
    # 處理命令列參數
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -i|--interval)
                MONITOR_INTERVAL="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            --webhook)
                ALERT_WEBHOOK="$2"
                shift 2
                ;;
            --email)
                ALERT_EMAIL="$2"
                shift 2
                ;;
            --internal-monitor)
                internal_monitor=true
                shift
                ;;
            start|stop|status|restart)
                action="$1"
                shift
                ;;
            *)
                echo "未知選項: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 檢查要求
    check_requirements
    
    # 內部監控模式
    if [[ "$internal_monitor" == "true" ]]; then
        monitor_loop
        exit 0
    fi
    
    # 執行動作
    case "$action" in
        "start")
            start_monitor
            ;;
        "stop")
            stop_monitor
            ;;
        "status")
            show_monitor_status
            ;;
        "restart")
            stop_monitor
            sleep 2
            start_monitor
            ;;
        "")
            echo "請指定動作: start|stop|status|restart"
            show_usage
            exit 1
            ;;
        *)
            echo "未知動作: $action"
            show_usage
            exit 1
            ;;
    esac
}

# 執行主函數
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi