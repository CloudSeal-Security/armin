#!/bin/bash

#
# OpenZiti Controller HA 配置生成腳本
# 根據模板生成各控制器的配置檔案
#

set -euo pipefail

# 預設配置
TRUST_DOMAIN="${TRUST_DOMAIN:-ziti.example.com}"
TEMPLATE_DIR="${TEMPLATE_DIR:-$(dirname "$0")/../templates}"
OUTPUT_DIR="${OUTPUT_DIR:-$(dirname "$0")/../configs}"

# 控制器節點配置
declare -A CONTROLLERS=(
    ["controller1"]="controller1.example.com"
    ["controller2"]="controller2.example.com"
    ["controller3"]="controller3.example.com"
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

generate_controller_config() {
    local controller_id="$1"
    local controller_fqdn="$2"
    local template_file="${TEMPLATE_DIR}/controller-config.yml.template"
    local output_file="${OUTPUT_DIR}/${controller_id}-config.yml"
    
    log_info "生成 ${controller_id} 配置檔案..."
    
    # 檢查模板檔案
    if [[ ! -f "$template_file" ]]; then
        log_error "模板檔案不存在: $template_file"
        return 1
    fi
    
    # 建立輸出目錄
    mkdir -p "$OUTPUT_DIR"
    
    # 替換模板變數
    sed -e "s/{{CONTROLLER_ID}}/${controller_id}/g" \
        -e "s/{{CONTROLLER_FQDN}}/${controller_fqdn}/g" \
        -e "s/{{TRUST_DOMAIN}}/${TRUST_DOMAIN}/g" \
        "$template_file" > "$output_file"
    
    log_info "✓ ${controller_id} 配置檔案已生成: $output_file"
}

generate_bootstrap_config() {
    local controller_id="$1"
    local controller_fqdn="$2"
    local template_file="${TEMPLATE_DIR}/controller-config.yml.template"
    local output_file="${OUTPUT_DIR}/${controller_id}-bootstrap-config.yml"
    
    log_info "生成 ${controller_id} 初始化配置檔案..."
    
    # 建立初始化配置（包含 bootstrapMembers）
    sed -e "s/{{CONTROLLER_ID}}/${controller_id}/g" \
        -e "s/{{CONTROLLER_FQDN}}/${controller_fqdn}/g" \
        -e "s/{{TRUST_DOMAIN}}/${TRUST_DOMAIN}/g" \
        "$template_file" > "$output_file"
    
    # 如果是第一個控制器，加入 bootstrapMembers
    if [[ "$controller_id" == "controller1" ]]; then
        cat >> "$output_file" << EOF

# 初始化叢集成員（僅用於第一個節點）
raft:
  dataDir: /var/lib/ziti-controller/raft
  minClusterSize: 3
  electionTimeout: 1000
  heartbeatTimeout: 500
  snapshotInterval: 8192
  snapshotThreshold: 5
  bootstrapMembers:
    - ${controller_fqdn}:6262
EOF
    fi
    
    log_info "✓ ${controller_id} 初始化配置檔案已生成: $output_file"
}

show_config_info() {
    log_info "配置資訊摘要:"
    echo "========================================"
    echo "信任域: ${TRUST_DOMAIN}"
    echo "模板目錄: ${TEMPLATE_DIR}"
    echo "輸出目錄: ${OUTPUT_DIR}"
    echo ""
    echo "控制器節點:"
    for controller_id in "${!CONTROLLERS[@]}"; do
        echo "  ${controller_id}: ${CONTROLLERS[$controller_id]}"
    done
    echo "========================================"
}

validate_configs() {
    log_info "驗證配置檔案..."
    
    for controller_id in "${!CONTROLLERS[@]}"; do
        local config_file="${OUTPUT_DIR}/${controller_id}-config.yml"
        local bootstrap_config_file="${OUTPUT_DIR}/${controller_id}-bootstrap-config.yml"
        
        # 檢查一般配置檔案
        if [[ -f "$config_file" ]]; then
            if grep -q "{{" "$config_file"; then
                log_error "✗ ${controller_id} 配置檔案包含未替換的變數"
            else
                log_info "✓ ${controller_id} 配置檔案驗證通過"
            fi
        else
            log_error "✗ ${controller_id} 配置檔案不存在"
        fi
        
        # 檢查初始化配置檔案
        if [[ -f "$bootstrap_config_file" ]]; then
            if grep -q "{{" "$bootstrap_config_file"; then
                log_error "✗ ${controller_id} 初始化配置檔案包含未替換的變數"
            else
                log_info "✓ ${controller_id} 初始化配置檔案驗證通過"
            fi
        else
            log_error "✗ ${controller_id} 初始化配置檔案不存在"
        fi
    done
}

main() {
    log_info "OpenZiti Controller HA 配置生成開始"
    
    # 顯示配置資訊
    show_config_info
    
    # 生成各控制器配置
    for controller_id in "${!CONTROLLERS[@]}"; do
        generate_controller_config "$controller_id" "${CONTROLLERS[$controller_id]}"
        generate_bootstrap_config "$controller_id" "${CONTROLLERS[$controller_id]}"
    done
    
    # 驗證配置檔案
    validate_configs
    
    log_info "配置生成完成！"
    log_info "配置檔案位置: ${OUTPUT_DIR}"
    log_info "請將配置檔案複製到對應的控制器節點"
}

# 執行主函數
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi