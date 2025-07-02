#!/bin/bash

#
# OpenZiti Controller HA 健康檢查腳本
# 檢查叢集狀態、節點健康和服務可用性
#

set -euo pipefail

# 預設配置
CONTROLLERS=(
    "controller1.example.com:8441"
    "controller2.example.com:8441"
    "controller3.example.com:8441"
)

RAFT_ENDPOINTS=(
    "controller1.example.com:6262"
    "controller2.example.com:6262"
    "controller3.example.com:6262"
)

OUTPUT_FORMAT="${OUTPUT_FORMAT:-table}"  # table, json, simple
CHECK_TIMEOUT="${CHECK_TIMEOUT:-10}"
NAGIOS_MODE="${NAGIOS_MODE:-false}"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Nagios 退出碼
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

log_info() {
    if [[ "$NAGIOS_MODE" != "true" ]]; then
        echo -e "${GREEN}[INFO]${NC} $1"
    fi
}

log_warn() {
    if [[ "$NAGIOS_MODE" != "true" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_error() {
    if [[ "$NAGIOS_MODE" != "true" ]]; then
        echo -e "${RED}[ERROR]${NC} $1"
    fi
}

log_debug() {
    if [[ "$NAGIOS_MODE" != "true" && "${DEBUG:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

show_usage() {
    echo "用法: $0 [選項]"
    echo ""
    echo "選項:"
    echo "  -h, --help          顯示此說明"
    echo "  --format FORMAT     輸出格式 (table|json|simple) [預設: table]"
    echo "  --timeout SECONDS   檢查超時時間 [預設: 10]"
    echo "  --nagios           Nagios 監控模式"
    echo "  --check TYPE       指定檢查類型 (all|cluster|controllers|api)"
    echo ""
    echo "環境變數:"
    echo "  DEBUG=true         啟用除錯輸出"
    echo ""
    echo "範例:"
    echo "  $0 --format json"
    echo "  $0 --nagios --check cluster"
}

check_controller_api() {
    local endpoint="$1"
    local result=""
    
    log_debug "檢查控制器 API: $endpoint"
    
    if curl -k -s --connect-timeout "$CHECK_TIMEOUT" \
       "https://$endpoint/health" > /dev/null 2>&1; then
        result="OK"
    else
        result="FAILED"
    fi
    
    echo "$result"
}

check_controller_management() {
    local endpoint="$1"
    local result=""
    
    log_debug "檢查控制器管理 API: $endpoint"
    
    # 嘗試獲取版本資訊
    if curl -k -s --connect-timeout "$CHECK_TIMEOUT" \
       "https://$endpoint/edge/management/v1/version" > /dev/null 2>&1; then
        result="OK"
    else
        result="FAILED"
    fi
    
    echo "$result"
}

get_cluster_leader() {
    log_debug "獲取叢集領導者"
    
    if command -v ziti &> /dev/null; then
        ziti agent cluster leader 2>/dev/null | grep -o "controller[0-9]" || echo "UNKNOWN"
    else
        echo "UNKNOWN"
    fi
}

get_cluster_members() {
    log_debug "獲取叢集成員"
    
    if command -v ziti &> /dev/null; then
        ziti agent cluster members 2>/dev/null || echo "FAILED"
    else
        echo "FAILED"
    fi
}

check_raft_connectivity() {
    local endpoint="$1"
    local result=""
    
    log_debug "檢查 RAFT 連通性: $endpoint"
    
    # 簡單的 TCP 連接測試
    if timeout "$CHECK_TIMEOUT" bash -c "</dev/tcp/${endpoint%:*}/${endpoint#*:}" 2>/dev/null; then
        result="OK"
    else
        result="FAILED"
    fi
    
    echo "$result"
}

check_all_controllers() {
    local results=()
    local healthy_count=0
    local total_count=${#CONTROLLERS[@]}
    
    log_info "檢查所有控制器..."
    
    for controller in "${CONTROLLERS[@]}"; do
        local api_status=$(check_controller_api "$controller")
        local mgmt_status=$(check_controller_management "$controller")
        
        if [[ "$api_status" == "OK" && "$mgmt_status" == "OK" ]]; then
            ((healthy_count++))
            results+=("$controller:HEALTHY")
        else
            results+=("$controller:UNHEALTHY")
        fi
    done
    
    # 返回結果
    echo "healthy_count:$healthy_count"
    echo "total_count:$total_count"
    printf '%s\n' "${results[@]}"
}

check_cluster_status() {
    log_info "檢查叢集狀態..."
    
    local leader=$(get_cluster_leader)
    local members=$(get_cluster_members)
    local raft_healthy=0
    local raft_total=${#RAFT_ENDPOINTS[@]}
    
    # 檢查 RAFT 連通性
    for endpoint in "${RAFT_ENDPOINTS[@]}"; do
        if [[ $(check_raft_connectivity "$endpoint") == "OK" ]]; then
            ((raft_healthy++))
        fi
    done
    
    echo "leader:$leader"
    echo "raft_healthy:$raft_healthy"
    echo "raft_total:$raft_total"
    echo "members:$members"
}

output_table_format() {
    local controller_results=("$@")
    
    echo "================================================"
    echo "OpenZiti Controller HA 健康檢查報告"
    echo "檢查時間: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "================================================"
    
    # 控制器狀態
    echo ""
    echo "控制器狀態:"
    echo "----------------------------------------"
    printf "%-30s %-10s\n" "控制器" "狀態"
    echo "----------------------------------------"
    
    for result in "${controller_results[@]}"; do
        if [[ "$result" =~ ^([^:]+):(.+)$ ]]; then
            local controller="${BASH_REMATCH[1]}"
            local status="${BASH_REMATCH[2]}"
            
            if [[ "$status" == "HEALTHY" ]]; then
                printf "%-30s ${GREEN}%-10s${NC}\n" "$controller" "$status"
            else
                printf "%-30s ${RED}%-10s${NC}\n" "$controller" "$status"
            fi
        fi
    done
    
    # 叢集狀態
    echo ""
    echo "叢集狀態:"
    echo "----------------------------------------"
    local cluster_info=$(check_cluster_status)
    
    local leader=$(echo "$cluster_info" | grep "leader:" | cut -d: -f2)
    local raft_healthy=$(echo "$cluster_info" | grep "raft_healthy:" | cut -d: -f2)
    local raft_total=$(echo "$cluster_info" | grep "raft_total:" | cut -d: -f2)
    
    printf "%-20s %s\n" "領導者:" "$leader"
    printf "%-20s %s/%s\n" "RAFT 節點:" "$raft_healthy" "$raft_total"
    
    echo ""
    echo "建議:"
    if [[ $raft_healthy -ge 2 ]]; then
        echo "✓ 叢集狀態良好，可正常提供服務"
    elif [[ $raft_healthy -eq 1 ]]; then
        echo "⚠ 叢集處於風險狀態，建議儘快修復故障節點"
    else
        echo "✗ 叢集不可用，需要立即修復"
    fi
}

output_json_format() {
    local controller_results=("$@")
    local cluster_info=$(check_cluster_status)
    
    # 解析叢集資訊
    local leader=$(echo "$cluster_info" | grep "leader:" | cut -d: -f2)
    local raft_healthy=$(echo "$cluster_info" | grep "raft_healthy:" | cut -d: -f2)
    local raft_total=$(echo "$cluster_info" | grep "raft_total:" | cut -d: -f2)
    
    # 構建 JSON
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"cluster\": {"
    echo "    \"leader\": \"$leader\","
    echo "    \"raft_healthy\": $raft_healthy,"
    echo "    \"raft_total\": $raft_total"
    echo "  },"
    echo "  \"controllers\": ["
    
    local first=true
    for result in "${controller_results[@]}"; do
        if [[ "$result" =~ ^([^:]+):(.+)$ ]]; then
            local controller="${BASH_REMATCH[1]}"
            local status="${BASH_REMATCH[2]}"
            
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            
            echo -n "    {"
            echo -n "\"endpoint\": \"$controller\", "
            echo -n "\"status\": \"$status\""
            echo -n "}"
        fi
    done
    
    echo ""
    echo "  ]"
    echo "}"
}

nagios_check() {
    local check_type="${1:-all}"
    local exit_code=$OK
    local message=""
    
    case "$check_type" in
        "cluster")
            local cluster_info=$(check_cluster_status)
            local raft_healthy=$(echo "$cluster_info" | grep "raft_healthy:" | cut -d: -f2)
            local raft_total=$(echo "$cluster_info" | grep "raft_total:" | cut -d: -f2)
            
            if [[ $raft_healthy -eq $raft_total && $raft_healthy -ge 2 ]]; then
                message="OK - 叢集健康，RAFT 節點 $raft_healthy/$raft_total"
                exit_code=$OK
            elif [[ $raft_healthy -ge 2 ]]; then
                message="WARNING - 叢集部分故障，RAFT 節點 $raft_healthy/$raft_total"
                exit_code=$WARNING
            else
                message="CRITICAL - 叢集故障，RAFT 節點 $raft_healthy/$raft_total"
                exit_code=$CRITICAL
            fi
            ;;
        "controllers")
            local controller_check=$(check_all_controllers)
            local healthy_count=$(echo "$controller_check" | grep "healthy_count:" | cut -d: -f2)
            local total_count=$(echo "$controller_check" | grep "total_count:" | cut -d: -f2)
            
            if [[ $healthy_count -eq $total_count ]]; then
                message="OK - 所有控制器健康 $healthy_count/$total_count"
                exit_code=$OK
            elif [[ $healthy_count -ge 2 ]]; then
                message="WARNING - 部分控制器故障 $healthy_count/$total_count"
                exit_code=$WARNING
            else
                message="CRITICAL - 控制器嚴重故障 $healthy_count/$total_count"
                exit_code=$CRITICAL
            fi
            ;;
        *)
            # 綜合檢查
            local controller_check=$(check_all_controllers)
            local cluster_info=$(check_cluster_status)
            
            local healthy_count=$(echo "$controller_check" | grep "healthy_count:" | cut -d: -f2)
            local total_count=$(echo "$controller_check" | grep "total_count:" | cut -d: -f2)
            local raft_healthy=$(echo "$cluster_info" | grep "raft_healthy:" | cut -d: -f2)
            local raft_total=$(echo "$cluster_info" | grep "raft_total:" | cut -d: -f2)
            
            if [[ $healthy_count -eq $total_count && $raft_healthy -eq $raft_total ]]; then
                message="OK - HA 叢集完全健康"
                exit_code=$OK
            elif [[ $healthy_count -ge 2 && $raft_healthy -ge 2 ]]; then
                message="WARNING - HA 叢集部分故障"
                exit_code=$WARNING
            else
                message="CRITICAL - HA 叢集嚴重故障"
                exit_code=$CRITICAL
            fi
            ;;
    esac
    
    echo "$message"
    exit $exit_code
}

main() {
    local check_type="all"
    
    # 處理命令列參數
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --timeout)
                CHECK_TIMEOUT="$2"
                shift 2
                ;;
            --nagios)
                NAGIOS_MODE="true"
                shift
                ;;
            --check)
                check_type="$2"
                shift 2
                ;;
            *)
                log_error "未知選項: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Nagios 模式
    if [[ "$NAGIOS_MODE" == "true" ]]; then
        nagios_check "$check_type"
        exit $?
    fi
    
    # 一般模式
    log_info "開始 OpenZiti Controller HA 健康檢查"
    
    # 檢查控制器
    local controller_check=$(check_all_controllers)
    local controller_results=()
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^[^:]+:(HEALTHY|UNHEALTHY)$ ]]; then
            controller_results+=("$line")
        fi
    done <<< "$controller_check"
    
    # 輸出結果
    case "$OUTPUT_FORMAT" in
        "json")
            output_json_format "${controller_results[@]}"
            ;;
        "simple")
            for result in "${controller_results[@]}"; do
                echo "$result"
            done
            check_cluster_status
            ;;
        "table"|*)
            output_table_format "${controller_results[@]}"
            ;;
    esac
}

# 執行主函數
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi