#!/bin/bash

#
# OpenZiti Controller HA 叢集初始化腳本
# 初始化第一個控制器節點並建立 HA 叢集
#

set -euo pipefail

# 預設配置
CONTROLLER_ID="${CONTROLLER_ID:-controller1}"
CONTROLLER_FQDN="${CONTROLLER_FQDN:-controller1.example.com}"
TRUST_DOMAIN="${TRUST_DOMAIN:-ziti.example.com}"
CONFIG_FILE="${CONFIG_FILE:-/var/lib/ziti-controller/config.yml}"
DATA_DIR="${DATA_DIR:-/var/lib/ziti-controller}"
LOG_DIR="${LOG_DIR:-/var/log/ziti-controller}"

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

check_requirements() {
    log_info "檢查系統要求..."
    
    # 檢查 ziti CLI
    if ! command -v ziti &> /dev/null; then
        log_error "ziti CLI 未找到，請先安裝 OpenZiti"
        exit 1
    fi
    
    # 檢查執行權限
    if [[ $EUID -ne 0 ]]; then
        log_error "此腳本需要 root 權限執行"
        exit 1
    fi
    
    # 檢查配置檔案
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "配置檔案不存在: $CONFIG_FILE"
        exit 1
    fi
    
    log_info "系統要求檢查通過"
}

prepare_directories() {
    log_info "準備必要目錄..."
    
    # 建立資料目錄
    mkdir -p "$DATA_DIR"/{raft,backups}
    mkdir -p "$LOG_DIR"
    
    # 設定權限
    chown -R ziti:ziti "$DATA_DIR"
    chown -R ziti:ziti "$LOG_DIR"
    
    log_info "目錄準備完成"
}

verify_certificates() {
    log_info "驗證 PKI 憑證..."
    
    local pki_dir="$DATA_DIR/pki"
    local controller_cert="$pki_dir/intermediate/certs/${CONTROLLER_ID}.chain.pem"
    local controller_key="$pki_dir/intermediate/keys/${CONTROLLER_ID}.key"
    local ca_cert="$pki_dir/ca/certs/ca.cert"
    
    # 檢查憑證檔案
    for cert_file in "$controller_cert" "$controller_key" "$ca_cert"; do
        if [[ ! -f "$cert_file" ]]; then
            log_error "憑證檔案不存在: $cert_file"
            exit 1
        fi
    done
    
    # 驗證 SPIFFE ID
    local spiffe_id=$(openssl x509 -in "$controller_cert" -noout -text | grep -o "spiffe://[^,]*" | head -1)
    local expected_spiffe="spiffe://${TRUST_DOMAIN}/controller/${CONTROLLER_ID}"
    
    if [[ "$spiffe_id" == "$expected_spiffe" ]]; then
        log_info "✓ SPIFFE ID 驗證通過: $spiffe_id"
    else
        log_error "✗ SPIFFE ID 不正確: $spiffe_id (期望: $expected_spiffe)"
        exit 1
    fi
    
    log_info "憑證驗證通過"
}

backup_existing_data() {
    log_info "備份現有資料..."
    
    local backup_dir="$DATA_DIR/backups/pre-ha-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 備份現有的 ctrl.db
    if [[ -f "$DATA_DIR/ctrl.db" ]]; then
        cp "$DATA_DIR/ctrl.db" "$backup_dir/"
        log_info "已備份現有資料庫到: $backup_dir/ctrl.db"
    fi
    
    # 備份配置檔案
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$backup_dir/config.yml.backup"
        log_info "已備份配置檔案到: $backup_dir/config.yml.backup"
    fi
}

stop_existing_controller() {
    log_info "停止現有控制器服務..."
    
    if systemctl is-active --quiet ziti-controller; then
        systemctl stop ziti-controller
        log_info "控制器服務已停止"
    else
        log_info "控制器服務未在運行"
    fi
}

initialize_ha_cluster() {
    log_info "初始化 HA 叢集..."
    
    # 使用 ziti agent 初始化第一個節點
    log_info "初始化第一個控制器節點..."
    
    sudo -u ziti ziti agent controller init \
        --ctrl-address "${CONTROLLER_FQDN}:6262" \
        --ctrl-advertised-address "${CONTROLLER_FQDN}:6262" \
        --config "$CONFIG_FILE" || {
        log_error "叢集初始化失敗"
        exit 1
    }
    
    log_info "HA 叢集初始化完成"
}

start_controller_service() {
    log_info "啟動控制器服務..."
    
    # 啟用並啟動服務
    systemctl enable ziti-controller
    systemctl start ziti-controller
    
    # 等待服務啟動
    sleep 10
    
    # 檢查服務狀態
    if systemctl is-active --quiet ziti-controller; then
        log_info "✓ 控制器服務啟動成功"
    else
        log_error "✗ 控制器服務啟動失敗"
        systemctl status ziti-controller
        exit 1
    fi
}

verify_cluster() {
    log_info "驗證叢集狀態..."
    
    # 等待服務完全就緒
    sleep 15
    
    # 檢查叢集狀態
    if ziti agent cluster members 2>/dev/null; then
        log_info "✓ 叢集狀態正常"
    else
        log_warn "叢集狀態檢查失敗，可能需要等待更長時間"
    fi
    
    # 檢查控制器列表
    if ziti fabric list controllers 2>/dev/null; then
        log_info "✓ 控制器列表獲取成功"
    else
        log_warn "控制器列表獲取失敗"
    fi
}

show_next_steps() {
    log_info "初始化完成！後續步驟:"
    echo "========================================"
    echo "1. 檢查叢集狀態:"
    echo "   ziti agent cluster members"
    echo "   ziti fabric list controllers"
    echo ""
    echo "2. 加入其他控制器節點:"
    echo "   在其他節點上執行 join-cluster.sh"
    echo ""
    echo "3. 檢查服務狀態:"
    echo "   systemctl status ziti-controller"
    echo "   tail -f /var/log/ziti-controller/${CONTROLLER_ID}.log"
    echo ""
    echo "4. 訪問管理介面:"
    echo "   https://${CONTROLLER_FQDN}:8441"
    echo "========================================"
}

main() {
    log_info "OpenZiti Controller HA 叢集初始化開始"
    log_info "控制器: $CONTROLLER_ID ($CONTROLLER_FQDN)"
    log_info "信任域: $TRUST_DOMAIN"
    
    # 檢查要求
    check_requirements
    
    # 準備環境
    prepare_directories
    verify_certificates
    backup_existing_data
    
    # 停止現有服務
    stop_existing_controller
    
    # 初始化叢集
    initialize_ha_cluster
    
    # 啟動服務
    start_controller_service
    
    # 驗證叢集
    verify_cluster
    
    # 顯示後續步驟
    show_next_steps
    
    log_info "叢集初始化完成！"
}

# 執行主函數
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi