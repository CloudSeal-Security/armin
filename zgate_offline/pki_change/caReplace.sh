#!/bin/bash

# 顏色
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_BLUE="\033[36m"
COLOR_RESET="\033[0m"

# 日志函數
log_info() {
    local datetime=$(date '+%Y/%m/%d %H:%M:%S')
    echo -e "$datetime ${COLOR_BLUE}[INFO]${COLOR_RESET} ${COLOR_BLUE}[$1]${COLOR_RESET} $2"
}

log_warn() {
    local datetime=$(date '+%Y/%m/%d %H:%M:%S')
    echo -e "$datetime ${COLOR_YELLOW}[WARN]${COLOR_RESET} ${COLOR_BLUE}[$1]${COLOR_RESET} $2"
}

log_error() {
    local datetime=$(date '+%Y/%m/%d %H:%M:%S')
    echo -e "$datetime ${COLOR_RED}[ERROR]${COLOR_RESET} ${COLOR_BLUE}[$1]${COLOR_RESET} $2"
}

usage() {
    log_error "usage" "Usage: $0 <caPath.yaml的路徑>"
    exit 1
}

# 使用cert-go產生自簽 CA
generate_self_signed_ca() {
    log_info "generate_self_signed_ca" "開始產生自簽 CA"

    # 產生 root cert
    ./pki_change/cert-go-linux-amd64 create cert -t root -y ./pki_change/caCfg.yaml -k rsa

    # 產生 intermediate cert
    ./pki_change/cert-go-linux-amd64 create cert -t intermediate -y ./pki_change/caCfg.yaml -k rsa

    # 產生 client cert
    ./pki_change/cert-go-linux-amd64 create cert -t client -y ./pki_change/caCfg.yaml -k rsa

    # 產生 server cert
    ./pki_change/cert-go-linux-amd64 create cert -t server -y ./pki_change/caCfg.yaml -k rsa

    log_info "generate_self_signed_ca" "自簽 CA 產生完成"
}

# 檢查指令
check_command() {
    log_info "check command" "${COLOR_GREEN}$1${COLOR_RESET} 檢查指令..."
    if ! command -v $1 &> /dev/null; then
        log_warn "check command" "${COLOR_GREEN}$1${COLOR_RESET} 指令不存在"

        sudo apt update
        sudo apt install -y $1
    fi
    log_info "check command" "${COLOR_GREEN}$1${COLOR_RESET} 檢查完成"
}

# 獲取 CA 路徑
get_ca_path() {
    local yaml_file="$1"
    
    # 使用 grep 和 sed 解析 YAML 文件
    ROOT_CERT=$(grep -A1 "root:" $yaml_file | grep "cert:" | sed 's/.*cert: *\(.*\)/\1/')
    ROOT_KEY=$(grep -A2 "root:" $yaml_file | grep "key:" | sed 's/.*key: *\(.*\)/\1/')
    
    INTERMEDIATE_CERT=$(grep -A1 "intermediate:" $yaml_file | grep "cert:" | sed 's/.*cert: *\(.*\)/\1/')
    INTERMEDIATE_KEY=$(grep -A2 "intermediate:" $yaml_file | grep "key:" | sed 's/.*key: *\(.*\)/\1/')
    INTERMEDIATE_CHAIN=$(grep -A3 "intermediate:" $yaml_file | grep "chain:" | sed 's/.*chain: *\(.*\)/\1/')
    
    CLIENT_CERT=$(grep -A1 "client:" $yaml_file | grep "cert:" | sed 's/.*cert: *\(.*\)/\1/')
    CLIENT_KEY=$(grep -A2 "client:" $yaml_file | grep "key:" | sed 's/.*key: *\(.*\)/\1/')
    CLIENT_CHAIN=$(grep -A3 "client:" $yaml_file | grep "chain:" | sed 's/.*chain: *\(.*\)/\1/')
    
    SERVER_CERT=$(grep -A1 "server:" $yaml_file | grep "cert:" | sed 's/.*cert: *\(.*\)/\1/')
    SERVER_KEY=$(grep -A2 "server:" $yaml_file | grep "key:" | sed 's/.*key: *\(.*\)/\1/')
    SERVER_CHAIN=$(grep -A3 "server:" $yaml_file | grep "chain:" | sed 's/.*chain: *\(.*\)/\1/')
    
    # 將變量導出，使其在函數外部可用
    export ROOT_CERT ROOT_KEY
    export INTERMEDIATE_CERT INTERMEDIATE_KEY INTERMEDIATE_CHAIN
    export CLIENT_CERT CLIENT_KEY CLIENT_CHAIN
    export SERVER_CERT SERVER_KEY SERVER_CHAIN
}

# 顯示獲取的路徑
print_ca_path() {
    log_info "print" "根證書路徑: $ROOT_CERT"
    log_info "print" "根密鑰路徑: $ROOT_KEY"

    log_info "print" "中間證書路徑: $INTERMEDIATE_CERT"
    log_info "print" "中間密鑰路徑: $INTERMEDIATE_KEY"
    log_info "print" "中間鏈路徑: $INTERMEDIATE_CHAIN"

    log_info "print" "客戶端證書路徑: $CLIENT_CERT"
    log_info "print" "客戶端密鑰路徑: $CLIENT_KEY"
    log_info "print" "客戶端鏈路徑: $CLIENT_CHAIN"

    log_info "print" "伺服器證書路徑: $SERVER_CERT"
    log_info "print" "伺服器密鑰路徑: $SERVER_KEY"
    log_info "print" "伺服器鏈路徑: $SERVER_CHAIN"
}

make_chain() {
    # 檢查chain.pem是否存在
    if [ -f "$1" ]; then
        log_info "make_chain" "$1 存在"
        return 0
    fi
    log_warn "make_chain" "$1 不存在"

    case $2 in
        "intermediate")
            sudo cat $INTERMEDIATE_CERT $ROOT_CERT > $1
            log_info "make_chain" "$1 生成完成"
        ;;
        "client")
            sudo cat $CLIENT_CERT $INTERMEDIATE_CERT $ROOT_CERT > $1
            log_info "make_chain" "$1 生成完成"
        ;;
        "server")
            sudo cat $SERVER_CERT $INTERMEDIATE_CERT $ROOT_CERT > $1
            log_info "make_chain" "$1 生成完成"
        ;;
        *)
        log_error "make_chain" "不支援的證書類型"
        exit 1
        ;;
    esac
}

# 替換 CA
replace_ca() {
    log_info "replace" "開始替換 CA"
    local dest_dir="/var/lib/private/zgate-controller/pki"

    log_info "replace" "替換根證書"
    local root_cert_dest="$dest_dir/root/certs/root.cert"
    local root_key_dest="$dest_dir/root/keys/root.key"

    sudo rm $root_cert_dest
    sudo rm $root_key_dest
    sudo cp $ROOT_CERT $root_cert_dest
    sudo cp $ROOT_KEY $root_key_dest

    log_info "replace" "替換中間證書"
    local intermediate_cert_dest1="$dest_dir/root/certs/intermediate.cert"
    local intermediate_cert_dest2="$dest_dir/intermediate/certs/intermediate.cert"
    local intermediate_key_dest1="$dest_dir/root/keys/intermediate.key"
    local intermediate_key_dest2="$dest_dir/intermediate/keys/intermediate.key"
    local intermediate_chain_dest="$dest_dir/intermediate/certs/intermediate.chain.pem"

    make_chain $INTERMEDIATE_CHAIN "intermediate"

    sudo rm $intermediate_cert_dest1
    sudo rm $intermediate_cert_dest2
    sudo rm $intermediate_key_dest1
    sudo rm $intermediate_key_dest2
    sudo rm $intermediate_chain_dest
    sudo cp $INTERMEDIATE_CERT $intermediate_cert_dest1
    sudo cp $INTERMEDIATE_CERT $intermediate_cert_dest2
    sudo cp $INTERMEDIATE_KEY $intermediate_key_dest1
    sudo cp $INTERMEDIATE_KEY $intermediate_key_dest2
    sudo cp $INTERMEDIATE_CHAIN $intermediate_chain_dest

    log_info "replace" "替換客戶端證書"
    local client_cert_dest="$dest_dir/intermediate/certs/client.cert"
    local client_key_dest="$dest_dir/intermediate/keys/client.key"
    local client_chain_dest="$dest_dir/intermediate/certs/client.chain.pem"

    make_chain $CLIENT_CHAIN "client"

    sudo rm $client_cert_dest
    sudo rm $client_key_dest
    sudo rm $client_chain_dest
    sudo cp $CLIENT_CERT $client_cert_dest
    sudo cp $CLIENT_KEY $client_key_dest
    sudo cp $CLIENT_CHAIN $client_chain_dest

    log_info "replace" "替換伺服器證書"
    local server_cert_dest="$dest_dir/intermediate/certs/server.cert"
    local server_key_dest="$dest_dir/intermediate/keys/server.key"
    local server_chain_dest="$dest_dir/intermediate/certs/server.chain.pem"

    make_chain $SERVER_CHAIN "server"

    sudo rm $server_cert_dest
    sudo rm $server_key_dest
    sudo rm $server_chain_dest
    sudo cp $SERVER_CERT $server_cert_dest
    sudo cp $SERVER_KEY $server_key_dest
    sudo cp $SERVER_CHAIN $server_chain_dest

    log_info "replace" "替換完成"
}

# 更改env變數，停用renew CA
disable_renew_ca() {
    log_info "disable_renew_ca" "開始停用renew CA"

    local env_file="/opt/zgate/etc/controller/service.env"

    sudo sed -i 's/ZITI_AUTO_RENEW_CERTS=.*/ZITI_AUTO_RENEW_CERTS='\''false'\''/' "$env_file"

    log_info "disable_renew_ca" "停用renew CA 完成"
}

# 重新啟動 zgate-controller
restart_zgate_controller() {
    log_info "restart" "重新啟動 zgate-controller"
    sudo systemctl restart zgate-controller
    log_info "restart" "zgate-controller 重新啟動完成"
}

main() {
    local caPath="./pki_change/caPath.yaml"

    # 確認有一個參數
    if [ $# -eq 1 ]; then
        caPath=$1
    fi

    # 檢查文件是否存在
    if [ ! -f "$caPath" ]; then
        log_error "main" "文件 $caPath 不存在"
        exit 1
    fi

    # 使用cert-go產生自簽 CA
    generate_self_signed_ca

    # 獲取 CA 路徑
    get_ca_path "$caPath"

    # 顯示獲取的路徑
    print_ca_path

    # 替換 CA
    replace_ca

    # 更改env變數，停用renew CA
    disable_renew_ca

    # 重新啟動 zgate-controller
    restart_zgate_controller
}

main $@
