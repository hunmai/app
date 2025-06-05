#!/bin/bash

CONFIG_DIR="/etc/hysteria"
CONFIG_FILE="$CONFIG_DIR/config.json"
USER_DB="$CONFIG_DIR/udpusers.db"
SYSTEMD_SERVICE="/etc/systemd/system/hysteria-server.service"

mkdir -p "$CONFIG_DIR"
touch "$USER_DB"

fetch_users() {
    if [[ -f "$USER_DB" ]]; then
        sqlite3 "$USER_DB" "SELECT username || ':' || password FROM users;" | paste -sd, -
    fi
}

update_userpass_config() {
    local users=$(fetch_users)
    local user_array=$(echo "$users" | awk -F, '{for(i=1;i<=NF;i++) printf "\"" $i "\"" ((i==NF) ? "" : ",")}')
    jq ".auth.config = [$user_array]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
}

add_user() {
    echo -e "\n\e[1;34mEnter username:\e[0m"
    read -r username
    echo -e "\e[1;34mEnter password:\e[0m"
    read -r password
    sqlite3 "$USER_DB" "INSERT INTO users (username, password) VALUES ('$username', '$password');"
    if [[ $? -eq 0 ]]; then
        echo -e "\e[1;32mUser $username added successfully.\e[0m"
        update_userpass_config
        restart_server
    else
        echo -e "\e[1;31mError: Failed to add user $username.\e[0m"
    fi
}

edit_user() {
    echo -e "\n\e[1;34mEnter username to edit:\e[0m"
    read -r username
    echo -e "\e[1;34mEnter new password:\e[0m"
    read -r password
    sqlite3 "$USER_DB" "UPDATE users SET password = '$password' WHERE username = '$username';"
    if [[ $? -eq 0 ]]; then
        echo -e "\e[1;32mUser $username updated successfully.\e[0m"
        update_userpass_config
        restart_server
    else
        echo -e "\e[1;31mError: Failed to update user $username.\e[0m"
    fi
}

delete_user() {
    echo -e "\n\e[1;34mEnter username to delete:\e[0m"
    read -r username
    sqlite3 "$USER_DB" "DELETE FROM users WHERE username = '$username';"
    if [[ $? -eq 0 ]]; then
        echo -e "\e[1;32mUser $username deleted successfully.\e[0m"
        update_userpass_config
        restart_server
    else
        echo -e "\e[1;31mError: Failed to delete user $username.\e[0m"
    fi
}

show_users() {
    echo -e "\n\e[1;34mCurrent users:\e[0m"
    sqlite3 "$USER_DB" "SELECT username FROM users;"
}

change_domain() {
    echo -e "\n\e[1;34mEnter new domain:\e[0m"
    read -r domain
    jq ".server = \"$domain\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "\e[1;32mDomain changed to $domain successfully.\e[0m"
    restart_server
}

change_obfs() {
    echo -e "\n\e[1;34mEnter new obfuscation string:\e[0m"
    read -r obfs
    jq ".obfs.password = \"$obfs\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "\e[1;32mObfuscation string changed to $obfs successfully.\e[0m"
    restart_server
}

change_up_speed() {
    echo -e "\n\e[1;34mป้อนความเร็วอัพโหลดใหม่ (Mbps):\e[0m"
    read -r up_speed
    jq ".up_mbps = $up_speed" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    jq ".up = \"$up_speed Mbps\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "\e[1;32mความเร็วในการอัพโหลดเปลี่ยนเป็น $up_speed Mbps เรียบร้อยแล้ว.\e[0m"
    restart_server
}

change_down_speed() {
    echo -e "\n\e[1;34mป้อนความเร็วการดาวน์โหลดใหม่ (Mbps):\e[0m"
    read -r down_speed
    jq ".down_mbps = $down_speed" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    jq ".down = \"$down_speed Mbps\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "\e[1;32mความเร็วในการดาวน์โหลดเปลี่ยนเป็น$ลดความเร็ว Mbps สำเร็จ\e[0m"
    restart_server
}

restart_server() {
    systemctl restart hysteria-server
    echo -e "\e[1;32mเซิร์ฟเวอร์รีสตาร์ทสำเร็จแล้ว.\e[0m"
}

uninstall_server() {
    echo -e "\n\e[1;34mกำลังถอนการติดตั้งเซิร์ฟเวอร์ PNT-UDP...\e[0m"
    systemctl stop hysteria-server
    systemctl disable hysteria-server
    rm -f "$SYSTEMD_SERVICE"
    systemctl daemon-reload
    rm -rf "$CONFIG_DIR"
    rm -f /usr/local/bin/hysteria
    echo -e "\e[1;32mPNT-UDP ถอนการติดตั้งเซิร์ฟเวอร์สำเร็จแล้ว\e[0m"
}

show_banner() {
    echo -e "\e[1;36m---------------------------------------------"
    echo " PNTUDP Manager,"
    echo " (c) 2024 pnt vpn"
    echo "---------------------------------------------\e[0m"
}

show_menu() {
    echo -e "\e[1;36m----------------------------"
    echo " PNTUDP Manager"
    echo -e "----------------------------\e[0m"
    echo -e "\e[1;32m1. เพิ่มผู้ใช้ใหม่"
    echo "2. แก้ไขรหัสผ่านผู้ใช้"
    echo "3. ลบผู้ใช้"
    echo "4. แสดงผู้ใช้งาน"
    echo "5. เปลี่ยนโดเมน"
    echo "6. เปลี่ยนสตริงการบดบัง"
    echo "7. เปลี่ยนความเร็วการอัพโหลด"
    echo "8. เปลี่ยนความเร็วในการดาวน์โหลด"
    echo "9. รีสตาร์ทเซิร์ฟเวอร์"
    echo "10. ถอนการติดตั้งเซิร์ฟเวอร์"
    echo -e "11. ออก\e[0m"
    echo -e "\e[1;36m----------------------------"
    echo -e "กรุณาระบุตัวเลือกของคุณ: \e[0m"
}

show_banner
while true; do
    show_menu
    read -r choice
    case $choice in
        1) add_user ;;
        2) edit_user ;;
        3) delete_user ;;
        4) show_users ;;
        5) change_domain ;;
        6) change_obfs ;;
        7) change_up_speed ;;
        8) change_down_speed ;;
        9) restart_server ;;
        10) uninstall_server; exit 0 ;;
        11) exit 0 ;;
        *) echo -e "\e[1;31mตัวเลือกไม่ถูกต้อง กรุณาลองอีกครั้ง.\e[0m" ;;
    esac
done
