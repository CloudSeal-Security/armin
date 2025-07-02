#!/bin/bash

### 2025.06.08 ###
# Version list:
# openziti_1.5.4_amd64.deb
# openziti-console_3.12.4_amd64.deb
# openziti-controller_1.5.4_amd64.deb
# openziti-router_1.5.4_amd64.deb
#
pause() {
    echo -e "\n\033[33m操作完成，按任意鍵返回主選單(30秒後自動繼續)...\033[0m"
    read -t 30 -n 1 -s -r
    clear
}

# 添加安装前的文件檢查（防止找不到文件）
check_deb_file() {
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        echo -e "\033[31m錯誤：找不到文件 $file_path\033[0m"
        return 1
    fi
}


# 安装Commander+ZAC
install_suite() {
    echo -e "\033[32m開始安装所需元件...\033[0m"
    check_deb_file "./ziti/openziti_1.5.4_amd64.deb" || return 1
    # 安裝Ziti 主程式
    if sudo dpkg -i ./ziti/openziti_1.5.4_amd64.deb; then
        echo "✓ Ziti 主程式安裝成功"
    else
        echo "✗ Ziti 主程式安裝失敗!"
        return 1
    fi

    # 安裝Controller
    check_deb_file "./controller/openziti-controller_1.5.4_amd64.deb" || return 1
    if sudo dpkg -i ./controller/openziti-controller_1.5.4_amd64.deb; then
        echo "✓ Controller 元件安裝成功"
    else
        echo "✗ Controller 元件安裝失敗!"
        return 1
    fi

    echo "執行 CA 憑證替換程序..."
    if bash ./pki_change/caReplace.sh; then
        echo "✓ CA 憑證替換成功"
    else
        echo "✗ CA 憑證替換失敗!"
        return 1
    fi

    # 安裝Console
    check_deb_file "./console/openziti-console_3.12.4_amd64.deb" || return 1
    if sudo dpkg -i ./console/openziti-console_3.12.4_amd64.deb; then
        echo "✓ Console 元件安裝成功"
    else
        echo "✗ Console 元件安裝失敗!"
        return 1
    fi
    echo "設置 Commander 參數注意事項"
    echo "Commander 要設定FQDN"
    pause
    sudo /opt/openziti/etc/controller/bootstrap.bash
    sudo systemctl enable --now ziti-controller.service
    sudo systemctl restart ziti-controller.service
    

    
    echo "重啟 Commander 與 Console 服務"
    echo "進入Console Patch 程序"
    pause

    cd console
    tar xvf console_patch.tar
    echo "✓ New Console 元件解縮成功"
    sudo rm -fr /opt/openziti/share/console
    echo "✓ 移除 Old Console 元件"  
    sudo cp -r ./console_patch/ /opt/openziti/share/console
    echo "✓ 置換 Console 元件成功" 
    rm -fr ./console_patch/
    cd ..
    sudo systemctl restart ziti-controller.service
    echo "Console Patch 程序完成"
    pause
    echo "重啟新 Console 服務"
    sudo systemctl restart ziti-controller.service
    echo "Commander 與 Console 服務設置程序，並已重啟"
    pause
}

# 安装Commander
install_Commander() {
    echo -e "\033[32m開始安装所需元件...\033[0m"
    check_deb_file "./ziti/openziti_1.5.4_amd64.deb" || return 1
    # 安裝Ziti 主程式
    if sudo dpkg -i ./ziti/openziti_1.5.4_amd64.debb; then
        echo "✓ Ziti 主程式安裝成功"
    else
        echo "✗ Ziti 主程式安裝失敗!"
        return 1
    fi

    # 安裝Controller
    check_deb_file "./controller/openziti-controller_1.5.4_amd64.deb" || return 1
    if sudo dpkg -i ./controller/openziti-controller_1.5.4_amd64.deb; then
        echo "✓ Commander 元件安裝成功"
    else
        echo "✗ Commander 元件安裝失敗!"
        return 1
    fi
    echo "設置 Commander 參數注意事項"
    echo "Commander 要設定FQDN"
    pause
    echo "啟動Commander服務"
    pause
    sudo /opt/openziti/etc/controller/bootstrap.bash
    sudo systemctl enable --now ziti-controller.service
    sudo systemctl restart ziti-controller.service
    
    echo "執行 CA 憑證替換程序..."
    if bash ./caReplace.sh; then
        echo "✓ CA 憑證替換成功"
    else
        echo "✗ CA 憑證替換失敗!"
        return 1
    fi
    
    echo "完成 Commander 服務設置程序，並已啟動中..."
    pause
}

# 安装Router
install_Router() {
    echo -e "\033[32m開始安装所需元件...\033[0m"

    # 安裝Ziti 主程式
    check_deb_file "./ziti/openziti_1.5.4_amd64.deb" || return 1
    if sudo dpkg -i ./ziti/openziti_1.5.4_amd64.deb; then
        echo "✓ Ziti 主程式安裝成功"
    else
        echo "✗ Ziti 主程式安裝失敗!"
        return 1
    fi

    # 安裝Router
    check_deb_file "./router/openziti-router_1.5.4_amd64.deb" || return 1
    if sudo dpkg -i ./router/openziti-router_1.5.4_amd64.deb; then
        echo "✓ Router 元件安裝成功"
    else
        echo "✗ Router 元件安裝失敗!"
        return 1
    fi

    echo "設置 Router 參數注意事項"
    echo "Router 要設定IP 或 FQDN"
    echo "請在Console 上先建立Router 並取得Router 的 JWT內容"
    pause
    echo "啟動Router服務"
    pause
    sudo /opt/openziti/etc/router/bootstrap.bash
    sudo systemctl enable --now ziti-router.service
    sudo systemctl restart ziti-router.service
    echo "完成 Router 服務設置程序，並已啟動中..."

    pause
}

# 主選單
clear
echo "=============================================="
echo " Install Script           Ver 1.3 2025/06/08  "
echo "=============================================="
echo "  #######        #####                      "
echo "       #        #     #   ##   ##### ###### "
echo "      #         #        #  #    #   #      "
echo "     #    ##### #  #### #    #   #   #####  "
echo "    #           #     # ######   #   #      "
echo "   #            #     # #    #   #   #      "
echo "  #######        #####  #    #   #   ###### "
echo "=============================================="
PS3="請選擇ZGate 系統安裝項目（輸入數字）:"
options=("Commander + ZAC" "Commander" "Router" "Exit")

select choice in "${options[@]}"
do
    case $choice in
        "Commander + ZAC")
            install_suite
            pause
            ;;
        "Commander")
            install_Commander
            pause
            ;;
        "Router")
            install_Router
            pause
            ;;
        "Exit")
            echo "已退出本安裝程序"
            break
            ;;
        *)
            echo "無效選項，請重新輸入！"
            ;;
    esac
    echo
done
