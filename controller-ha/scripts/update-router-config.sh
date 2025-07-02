#!/bin/bash

#
# OpenZiti Router HA 配置更新腳本
# 更新 Router 配置以支援多控制器連線
#

set -euo pipefail

# 預設配置
ROUTER_ID="${ROUTER_ID:-edge-router-1}"
ROUTER_FQDN="${ROUTER_FQDN:-router1.example.com}"
ROUTER_CONFIG="${ROUTER_CONFIG:-/var/lib/ziti-router/config.yml}"
TEMPLATE_DIR="${TEMPLATE_DIR:-$(dirname "$0")/../templates}"
BACKUP_DIR="${BACKUP_DIR:-/var/lib/ziti-router/backups}"

# 控制器端點列表
CONTROLLER_ENDPOINTS=(
    "tls:controller1.example.com:8440"
    "tls:controller2.example.com:8440"
    "tls:controller3.example.com:8440"
)

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    echo "用法: $0 [選項]"
    echo ""
    echo "選項:"
    echo "  -h, --help          顯示此說明"
    echo "  --dry-run          僅顯示會執行的操作，不實際修改"
    echo "  --backup-only      僅備份現有配置，不進行更新"
    echo ""
    echo "環境變數:"
    echo "  ROUTER_ID          Router 識別碼 (預設: edge-router-1)"
    echo "  ROUTER_FQDN        Router FQDN (預設: router1.example.com)"
    echo "  ROUTER_CONFIG      Router 配置檔案路徑 (預設: /var/lib/ziti-router/config.yml)"
    echo ""
    echo "範例:"
    echo "  ROUTER_ID=my-router ROUTER_FQDN=router.example.com $0"
    echo "  $0 --dry-run"
}

check_requirements() {
    log_info "檢查系統要求..."
    
    # 檢查配置檔案
    if [[ ! -f "$ROUTER_CONFIG" ]]; then
        log_error "Router 配置檔案不存在: $ROUTER_CONFIG"
        exit 1
    fi
    
    # 檢查模板檔案
    local template_file="$TEMPLATE_DIR/router-config.yml.template"
    if [[ ! -f "$template_file" ]]; then
        log_error "模板檔案不存在: $template_file"
        exit 1
    fi
    
    # 檢查 yq 工具（用於 YAML 處理）
    if ! command -v yq &> /dev/null; then
        log_warn "yq 工具未找到，將使用 sed 進行配置更新"
    fi
    
    log_info "系統要求檢查通過"
}

backup_existing_config() {
    log_info "備份現有配置..."
    
    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/config-$(date +%Y%m%d-%H%M%S).yml"
    
    cp "$ROUTER_CONFIG" "$backup_file"
    log_info "配置已備份到: $backup_file"
}

check_current_config() {
    log_info "檢查現有配置..."
    
    # 檢查是否已經配置多控制器
    if grep -q "endpoints:" "$ROUTER_CONFIG"; then
        log_warn "配置檔案似乎已包含多控制器端點"
        
        # 顯示現有端點
        log_info "現有控制器端點:"
        grep -A 10 "endpoints:" "$ROUTER_CONFIG" | grep -E "^\s*-\s*tls:" || true
        
        read -p "是否要繼續更新配置？ (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "操作已取消"
            exit 0
        fi
    fi
}

generate_ha_config() {
    log_info "生成 HA 配置..."
    
    local template_file="$TEMPLATE_DIR/router-config.yml.template"
    local temp_config="/tmp/router-ha-config-$$.yml"
    
    # 替換模板變數
    sed -e "s/{{ROUTER_ID}}/${ROUTER_ID}/g" \
        -e "s/{{ROUTER_FQDN}}/${ROUTER_FQDN}/g" \
        "$template_file" > "$temp_config"
    
    echo "$temp_config"
}

update_controller_endpoints() {
    local config_file="$1"
    
    log_info "更新控制器端點配置..."
    
    # 如果有 yq，使用 yq 更新
    if command -v yq &> /dev/null; then
        update_with_yq "$config_file"
    else
        update_with_sed "$config_file"
    fi
}

update_with_yq() {
    local config_file="$1"
    
    log_info "使用 yq 更新配置..."
    
    # 清除現有的 ctrl 配置
    yq eval 'del(.ctrl)' -i "$config_file"
    
    # 添加新的 ctrl 配置
    yq eval '.ctrl.endpoints = []' -i "$config_file"
    
    # 添加控制器端點
    for endpoint in "${CONTROLLER_ENDPOINTS[@]}"; do
        yq eval ".ctrl.endpoints += [\"$endpoint\"]" -i "$config_file"
    done
    
    # 添加連線選項
    yq eval '.ctrl.options.connectTimeout = "5s"' -i "$config_file"
    yq eval '.ctrl.options.heartbeatInterval = "60s"' -i "$config_file"
    yq eval '.ctrl.options.reconnectInterval = "30s"' -i "$config_file"
    yq eval '.ctrl.options.maxRetries = 3' -i "$config_file"
}

update_with_sed() {
    local config_file="$1"
    
    log_info "使用 sed 更新配置..."
    
    # 建立臨時檔案
    local temp_file="/tmp/router-config-update-$$.yml"
    
    # 移除現有的 ctrl 區塊
    sed '/^ctrl:/,/^[a-zA-Z]/{ /^[a-zA-Z]/!d; /^ctrl:/d; }' "$config_file" > "$temp_file"
    
    # 添加新的 ctrl 配置
    cat >> "$temp_file" << EOF

# 控制器連線配置（HA 支援）
ctrl:
  endpoints:
EOF
    
    # 添加控制器端點
    for endpoint in "${CONTROLLER_ENDPOINTS[@]}"; do
        echo "    - $endpoint" >> "$temp_file"
    done
    
    # 添加連線選項
    cat >> "$temp_file" << EOF
  options:
    connectTimeout: 5s
    heartbeatInterval: 60s
    reconnectInterval: 30s
    maxRetries: 3
EOF
    
    # 替換原檔案
    mv "$temp_file" "$config_file"
}

validate_config() {
    local config_file="$1"
    
    log_info "驗證配置檔案..."
    
    # 檢查必要的欄位
    local required_fields=("ctrl" "identity" "listeners")
    for field in "${required_fields[@]}"; do
        if ! grep -q "^$field:" "$config_file"; then
            log_error "配置檔案缺少必要欄位: $field"
            return 1
        fi
    done
    
    # 檢查控制器端點
    local endpoint_count=$(grep -c "tls:controller.*:8440" "$config_file" || echo "0")
    if [[ $endpoint_count -lt 3 ]]; then
        log_warn "配置的控制器端點少於 3 個 (發現 $endpoint_count 個)"
    else
        log_info "✓ 配置了 $endpoint_count 個控制器端點"
    fi
    
    log_info "配置檔案驗證通過"
}

restart_router_service() {
    log_info "重啟 Router 服務..."
    
    if systemctl is-active --quiet ziti-router; then
        systemctl restart ziti-router
        sleep 5
        
        if systemctl is-active --quiet ziti-router; then
            log_info "✓ Router 服務重啟成功"
        else
            log_error "✗ Router 服務重啟失敗"
            systemctl status ziti-router
            return 1
        fi
    else
        log_warn "Router 服務未在運行，嘗試啟動..."
        systemctl start ziti-router
        sleep 5
        
        if systemctl is-active --quiet ziti-router; then
            log_info "✓ Router 服務啟動成功"
        else
            log_error "✗ Router 服務啟動失敗"
            return 1
        fi
    fi
}

show_completion_info() {
    log_info "Router HA 配置更新完成！"
    echo "========================================"
    echo "Router 資訊:"
    echo "  ID: $ROUTER_ID"
    echo "  FQDN: $ROUTER_FQDN"
    echo "  配置檔案: $ROUTER_CONFIG"
    echo ""
    echo "控制器端點:"
    for endpoint in "${CONTROLLER_ENDPOINTS[@]}"; do
        echo "  - $endpoint"
    done
    echo ""
    echo "檢查命令:"
    echo "  服務狀態: systemctl status ziti-router"
    echo "  日誌檢查: tail -f /var/log/ziti-router/${ROUTER_ID}.log"
    echo "  連線測試: ziti router list"
    echo "========================================"
}

main() {
    local dry_run=false
    local backup_only=false
    
    # 處理命令列參數
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --backup-only)
                backup_only=true
                shift
                ;;
            *)
                log_error "未知選項: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "OpenZiti Router HA 配置更新開始"
    log_info "Router: $ROUTER_ID ($ROUTER_FQDN)"
    
    # 檢查要求
    check_requirements
    
    # 備份現有配置
    backup_existing_config
    
    if [[ "$backup_only" == true ]]; then
        log_info "僅備份模式，操作完成"
        exit 0
    fi
    
    # 檢查現有配置
    check_current_config
    
    if [[ "$dry_run" == true ]]; then
        log_info "乾燥運行模式 - 將執行以下操作:"
        echo "1. 更新控制器端點為多控制器模式"
        echo "2. 添加 HA 連線選項"
        echo "3. 驗證配置檔案"
        echo "4. 重啟 Router 服務"
        exit 0
    fi
    
    # 更新配置
    update_controller_endpoints "$ROUTER_CONFIG"
    
    # 驗證配置
    validate_config "$ROUTER_CONFIG"
    
    # 重啟服務
    restart_router_service
    
    # 顯示完成資訊
    show_completion_info
    
    log_info "Router HA 配置更新完成！"
}

# 執行主函數
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi