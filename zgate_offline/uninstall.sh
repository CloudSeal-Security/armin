#!/bin/bash

pause() {
    echo -e "\n\033[33m按任意鍵返回主選單(30秒後自動繼續)...\033[0m"
    read -t 30 -n 1 -s -r
    clear
}

# 解除安装All
delete_cmd_zac() {
    sudo systemctl disable --now ziti-controller.service
    sudo systemctl reset-failed ziti-controller.service
    sudo systemctl clean --what=state ziti-controller.service
    sudo apt-get purge openziti-controller
    sudo rm -fr /opt/openziti
    echo "✓ Commander & ZAC 元件刪除成功"
    pause
}

# 解除安装Router
delete_Router() {
    sudo systemctl disable --now ziti-router.service
    sudo systemctl reset-failed ziti-router.service
    sudo systemctl clean --what=state ziti-router.service
    sudo apt-get purge openziti-router
    sudo rm -fr /opt/openziti/etc/router
    echo "✓ Router 元件刪除成功"
    pause
}

Uninstall_cmd_zac() {
  read -p "請輸入 ( yes or no) 確認刪除 : " yesorno
  if [ "$yesorno" = yes ]; then
      delete_cmd_zac
  elif [ "$yesorno" = no ]; then
      pause
  else
      echo "Not a valid answer."
      exit 1
  fi
}

Uninstall_Router() {
  read -p "請輸入 ( yes or no) 確認刪除 : " yesorno
  if [ "$yesorno" = yes ]; then
      delete_Router
  elif [ "$yesorno" = no ]; then
      pause
  else
      echo "Not a valid answer."
      exit 1
  fi
}




# 主選單
clear
echo "=============================================="
echo " Uninstall Script           Ver 1.0 2025/03/23"
echo "=============================================="
echo "  #######        #####                      "
echo "       #        #     #   ##   ##### ###### "
echo "      #         #        #  #    #   #      "
echo "     #    ##### #  #### #    #   #   #####  "
echo "    #           #     # ######   #   #      "
echo "   #            #     # #    #   #   #      "
echo "  #######        #####  #    #   #   ###### "
echo "=============================================="


PS3="請選擇ZGate 系統移除項目（輸入數字）:"
options=("Uninstall-Commander & ZAC" "Uninstall-Router" "Exit")

select choice in "${options[@]}"
do
    case $choice in
         "Uninstall-Commander & ZAC")
            Uninstall_cmd_zac
            pause
            ;;
        "Uninstall-Router")
            Uninstall_Router
            pause
            ;;
        "Exit")
            echo "已退出本移除程序"
            break
            ;;
        *)
            echo "無效選項，請重新輸入！"
            ;;
    esac
    echo
done
