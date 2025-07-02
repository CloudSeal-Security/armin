#!/bin/bash

#
# OpenZiti Controller HA 節點加入腳本
# 將第二、三個控制器節點加入現有的 HA 叢集
#

set -euo pipefail

# 預設配置
CONTROLLER_ID="${CONTROLLER_ID:-controller2}"
CONTROLLER_FQDN="${CONTROLLER_FQDN:-controller2.example.com}"
PRIMARY_CONTROLLER="${PRIMARY_CONTROLLER:-controller1.example.com}"
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

show_usage() {
    echo "用法: $0 [選項]"
    echo ""
    echo "環境變數:"
    echo "  CONTROLLER_ID       - 控制器識別碼 (預設: controller2)"
    echo "  CONTROLLER_FQDN     - 控制器 FQDN (預設: controller2.example.com)"
    echo "  PRIMARY_CONTROLLER  - 主控制器 FQDN (預設: controller1.example.com)"
    echo "  TRUST_DOMAIN        - 信任域 (預設: ziti.example.com)"
    echo "  CONFIG_FILE         - 配置檔案路徑 (預設: /var/lib/ziti-controller/config.yml)"
    echo ""
    echo "範例:"
    echo "  CONTROLLER_ID=controller3 CONTROLLER_FQDN=controller3.example.com $0"
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
        log_error "請先生成配置檔案或確認路徑正確"
        exit 1
    fi
    
    log_info "系統要求檢查通過"
}

verify_primary_controller() {
    log_info "驗證主控制器連線..."
    
    # 測試主控制器連線
    if ! curl -k -s --connect-timeout 10 "https://${PRIMARY_CONTROLLER}:8441/health" > /dev/null; then
        log_error "無法連接到主控制器: ${PRIMARY_CONTROLLER}:8441"
        log_error "請確認主控制器已啟動且網路連通"
        exit 1
    fi
    
    log_info "✓ 主控制器連線正常"
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
            log_error "請先複製 PKI 憑證到此節點"
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
    
    local backup_dir="$DATA_DIR/backups/pre-join-$(date +%Y%m%d-%H%M%S)"
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

join_ha_cluster() {
    log_info "加入 HA 叢集..."
    
    # 使用 ziti agent 加入叢集
    log_info "連接到主控制器並加入叢集..."
    
    sudo -u ziti ziti agent controller join \
        "${PRIMARY_CONTROLLER}:6262" \
        --ctrl-address "${CONTROLLER_FQDN}:6262" \
        --ctrl-advertised-address "${CONTROLLER_FQDN}:6262" \
        --config "$CONFIG_FILE" || {
        log_error "加入叢集失敗"
        exit 1
    }
    
    log_info "成功加入 HA 叢集"
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

verify_cluster_membership() {
    log_info "驗證叢集成員資格..."
    
    # 等待服務完全就緒
    sleep 15
    
    # 檢查叢集成員
    local retry_count=0
    local max_retries=6
    
    while [[ $retry_count -lt $max_retries ]]; do
        if ziti agent cluster members 2>/dev/null | grep -q "$CONTROLLER_ID"; then
            log_info "✓ 成功加入叢集，節點 ID: $CONTROLLER_ID"
            break
        else
            log_warn "尚未在叢集中看到此節點，重試中... ($((retry_count + 1))/$max_retries)"
            sleep 10
            ((retry_count++))
        fi
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        log_error "節點未成功加入叢集"
        exit 1
    fi
    
    # 顯示叢集狀態
    log_info "目前叢集狀態:"
    ziti agent cluster members 2>/dev/null || log_warn "無法獲取叢集狀態"
}

show_completion_info() {
    log_info "節點加入完成！"
    echo "========================================"
    echo "節點資訊:"
    echo "  ID: $CONTROLLER_ID"
    echo "  FQDN: $CONTROLLER_FQDN"
    echo "  主控制器: $PRIMARY_CONTROLLER"
    echo ""
    echo "檢查命令:"
    echo "  叢集狀態: ziti agent cluster members"
    echo "  控制器列表: ziti fabric list controllers"
    echo "  服務狀態: systemctl status ziti-controller"
    echo "  日誌檢查: tail -f /var/log/ziti-controller/${CONTROLLER_ID}.log"
    echo ""
    echo "管理介面:"
    echo "  https://${CONTROLLER_FQDN}:8441"
    echo "========================================"
}

main() {
    # 處理命令列參數
    if [[ $# -gt 0 && ("$1" == "-h" || "$1" == "--help") ]]; then
        show_usage
        exit 0
    fi
    
    log_info "OpenZiti Controller HA 節點加入開始"
    log_info "節點: $CONTROLLER_ID ($CONTROLLER_FQDN)"
    log_info "主控制器: $PRIMARY_CONTROLLER"
    log_info "信任域: $TRUST_DOMAIN"
    
    # 檢查要求
    check_requirements
    verify_primary_controller
    
    # 準備環境
    prepare_directories
    verify_certificates
    backup_existing_data
    
    # 停止現有服務
    stop_existing_controller
    
    # 加入叢集
    join_ha_cluster
    
    # 啟動服務
    start_controller_service
    
    # 驗證成員資格
    verify_cluster_membership
    
    # 顯示完成資訊
    show_completion_info
    
    log_info "節點加入叢集完成！"
}

# 執行主函數
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi