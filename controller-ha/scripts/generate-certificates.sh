#!/bin/bash

#
# OpenZiti Controller HA 憑證生成腳本
# 生成包含 SPIFFE ID 的控制器憑證
#

set -euo pipefail

# 預設配置
TRUST_DOMAIN="${TRUST_DOMAIN:-ziti.example.com}"
PKI_ROOT="${PKI_ROOT:-/var/lib/ziti-controller/pki}"
CA_NAME="${CA_NAME:-ca}"
INTERMEDIATE_NAME="${INTERMEDIATE_NAME:-intermediate}"

# 控制器節點配置
declare -A CONTROLLERS=(
    ["controller1"]="controller1.example.com:192.168.1.11"
    ["controller2"]="controller2.example.com:192.168.1.12"
    ["controller3"]="controller3.example.com:192.168.1.13"
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

check_ziti_cli() {
    if ! command -v ziti &> /dev/null; then
        log_error "ziti CLI 未找到，請先安裝 OpenZiti"
        exit 1
    fi
    log_info "ziti CLI 版本: $(ziti version)"
}

create_root_ca() {
    log_info "建立根 CA..."
    
    if [[ -f "${PKI_ROOT}/${CA_NAME}/certs/${CA_NAME}.cert" ]]; then
        log_warn "根 CA 已存在，跳過建立"
        return 0
    fi

    mkdir -p "${PKI_ROOT}"
    
    ziti pki create ca \
        --pki-root "${PKI_ROOT}" \
        --ca-file "${CA_NAME}" \
        --ca-name "OpenZiti Controller HA Root CA"
    
    log_info "根 CA 建立完成"
}

create_intermediate_ca() {
    log_info "建立中間 CA..."
    
    if [[ -f "${PKI_ROOT}/${INTERMEDIATE_NAME}/certs/${INTERMEDIATE_NAME}.cert" ]]; then
        log_warn "中間 CA 已存在，跳過建立"
        return 0
    fi

    ziti pki create intermediate \
        --pki-root "${PKI_ROOT}" \
        --ca-name "${CA_NAME}" \
        --intermediate-file "${INTERMEDIATE_NAME}" \
        --intermediate-name "OpenZiti Controller HA Intermediate CA"
    
    log_info "中間 CA 建立完成"
}

create_controller_certificates() {
    local controller_id="$1"
    local dns_ip="$2"
    
    IFS=':' read -r dns_name ip_addr <<< "$dns_ip"
    
    log_info "為 ${controller_id} 建立憑證..."
    log_info "  DNS: ${dns_name}"
    log_info "  IP: ${ip_addr}"
    log_info "  SPIFFE ID: spiffe://${TRUST_DOMAIN}/controller/${controller_id}"
    
    # 檢查憑證是否已存在
    if [[ -f "${PKI_ROOT}/${INTERMEDIATE_NAME}/certs/${controller_id}.chain.pem" ]]; then
        log_warn "${controller_id} 憑證已存在，跳過建立"
        return 0
    fi
    
    # 建立伺服器憑證（含 SPIFFE ID）
    ziti pki create server \
        --pki-root "${PKI_ROOT}" \
        --ca-name "${INTERMEDIATE_NAME}" \
        --server-file "${controller_id}" \
        --dns "localhost,${dns_name}" \
        --ip "127.0.0.1,::1,${ip_addr}" \
        --spiffe-id "spiffe://${TRUST_DOMAIN}/controller/${controller_id}"
    
    # 建立客戶端憑證（使用相同的私鑰）
    ziti pki create client \
        --pki-root "${PKI_ROOT}" \
        --ca-name "${INTERMEDIATE_NAME}" \
        --key-file "${controller_id}" \
        --client-file "${controller_id}-client"
    
    log_info "${controller_id} 憑證建立完成"
}

verify_certificates() {
    log_info "驗證憑證..."
    
    for controller_id in "${!CONTROLLERS[@]}"; do
        local cert_file="${PKI_ROOT}/${INTERMEDIATE_NAME}/certs/${controller_id}.chain.pem"
        
        if [[ ! -f "$cert_file" ]]; then
            log_error "${controller_id} 憑證檔案不存在: $cert_file"
            continue
        fi
        
        # 檢查 SPIFFE ID
        local spiffe_id=$(openssl x509 -in "$cert_file" -noout -text | grep -o "spiffe://[^,]*" | head -1)
        local expected_spiffe="spiffe://${TRUST_DOMAIN}/controller/${controller_id}"
        
        if [[ "$spiffe_id" == "$expected_spiffe" ]]; then
            log_info "✓ ${controller_id} SPIFFE ID 正確: $spiffe_id"
        else
            log_error "✗ ${controller_id} SPIFFE ID 不正確: $spiffe_id (期望: $expected_spiffe)"
        fi
    done
}

show_certificate_info() {
    log_info "憑證資訊摘要:"
    echo "========================================"
    echo "PKI 根目錄: ${PKI_ROOT}"
    echo "信任域: ${TRUST_DOMAIN}"
    echo "根 CA: ${CA_NAME}"
    echo "中間 CA: ${INTERMEDIATE_NAME}"
    echo ""
    echo "控制器憑證:"
    for controller_id in "${!CONTROLLERS[@]}"; do
        local dns_ip="${CONTROLLERS[$controller_id]}"
        IFS=':' read -r dns_name ip_addr <<< "$dns_ip"
        echo "  ${controller_id}:"
        echo "    DNS: ${dns_name}"
        echo "    IP: ${ip_addr}"
        echo "    SPIFFE ID: spiffe://${TRUST_DOMAIN}/controller/${controller_id}"
    done
    echo "========================================"
}

main() {
    log_info "OpenZiti Controller HA 憑證生成開始"
    
    # 檢查必要工具
    check_ziti_cli
    
    # 顯示配置資訊
    show_certificate_info
    
    # 建立 CA
    create_root_ca
    create_intermediate_ca
    
    # 建立控制器憑證
    for controller_id in "${!CONTROLLERS[@]}"; do
        create_controller_certificates "$controller_id" "${CONTROLLERS[$controller_id]}"
    done
    
    # 驗證憑證
    verify_certificates
    
    log_info "憑證生成完成！"
    log_info "PKI 目錄: ${PKI_ROOT}"
    log_info "請將憑證分發到對應的控制器節點"
}

# 執行主函數
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi