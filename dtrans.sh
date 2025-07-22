#!/bin/bash

# 配置参数


# 定义每个IP对应的目标信息
declare -A configs
configs["xx.xx.xx.1"]="user:root password:xxx targetip:xxx"
configs["xx.xx.xx.2"]="user:root password:xxx targetip:xxx"
# 添加更多IP和配置...



# 处理输入参数

SKIP_LARGE_FILES=0
TARGET_IP=""
TARGET_PATH=""

# 验证字符串是否是合法 IP 地址
function is_valid_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ $ip =~ $regex ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        -skipb)
            SKIP_LARGE_FILES=1
            shift
            ;;
        *)
            if [ -z "$TARGET_IP" ]; then
                if ! is_valid_ip "$1"; then
                    echo "错误：'$1' 不是一个合法的IPv4地址"
                    exit 1
                fi
                TARGET_IP="$1"
                shift
            elif [ -z "$TARGET_PATH" ]; then
                TARGET_PATH="$1"
                shift
            else
                echo "错误：多余的参数 '$1'"
                exit 1
            fi
            ;;
    esac
done

# 检查必要参数是否提供
if [ -z "$TARGET_IP" ] || [ -z "$TARGET_PATH" ]; then
    echo "Usage: $0 [-skipb] <ipv4> <directory or file>"
    exit 1
fi

# 输出确认信息
echo "解析结果如下："
echo "SKIP_LARGE_FILES = $SKIP_LARGE_FILES"
echo "TARGET_IP = $TARGET_IP"
echo "TARGET_PATH = $TARGET_PATH"

# 获取用户输入的IP
# read -p "请输入目的IP地址: " INPUT_IP
INPUT_IP=$TARGET_IP

# 检查是否在配置中
if [[ -z "${configs[$INPUT_IP]}" ]]; then
    echo "未找到该IP的配置！"
    exit 1
fi

# 解析配置
IFS=' ' read -r user_field pass_field targetip_field <<< "${configs[$INPUT_IP]}"
USER=$(echo "$user_field" | cut -d':' -f2)
PASSWORD=$(echo "$pass_field" | cut -d':' -f2)
# TARGET_IP=$(echo "$targetip_field" | cut -d':' -f2)

# 输出确认
echo "解析结果如下："
echo "USER = $USER"
echo "PASSWORD = $PASSWORD"
# echo "TARGET_IP = $TARGET_IP"



USER=$USER
PASSWORD=$PASSWORD
SOURCE_IP=$(hostname -I | awk '{print $1}')
IPs=(
    $INPUT_IP
)

# 判断输入类型（文件/目录）
TARGET_ARG=$TARGET_PATH
if [ -f "$TARGET_ARG" ]; then
    SOURCE_TYPE="file"
    FILE_PATH="$TARGET_ARG"
    SOURCE_DIR=$(dirname "$FILE_PATH")
    DEST_DIR="$SOURCE_DIR"
    FILE_NAME=$(basename "$FILE_PATH")
elif [ -d "$TARGET_ARG" ]; then
    SOURCE_TYPE="directory"
    SOURCE_DIR="$TARGET_ARG"
    DEST_DIR="$TARGET_ARG"
else
    echo "Error: $TARGET_ARG does not exist or is inaccessible."
    exit 1
fi

# 检查是否有 sshpass 命令
if command -v sshpass >/dev/null 2>&1; then
    HAS_SSHPASS=1
else
    HAS_SSHPASS=0
fi


# 遍历所有节点
for ip in "${IPs[@]}"; do
    echo "==== 正在处理 $ip ===="

    if [[ $ip == "$SOURCE_IP" ]]; then
        # 本地节点处理
        mkdir -p "$DEST_DIR"
        if [ "$SOURCE_TYPE" = "directory" ]; then
            echo "[本地] 同步目录内容..."
            if [ $SKIP_LARGE_FILES -eq 1 ]; then
                rsync -a --info=progress2 --max-size=100M "$SOURCE_DIR"/ "$DEST_DIR"/
            else
                rsync -a --delete --info=progress2 "$SOURCE_DIR"/ "$DEST_DIR"/
            fi
        else
            if [ $SKIP_LARGE_FILES -eq 1 ]; then
                FILE_SIZE=$(stat -c%s "$FILE_PATH")
                if [ $FILE_SIZE -gt 104857600 ]; then
                    echo "跳过大文件 $FILE_NAME"
                    continue
                fi
            fi
            echo "[本地] 同步文件..."
            rsync -a --info=progress2 "$FILE_PATH" "$DEST_DIR/"
        fi
    else
        # ssh-copy-id 同步key
        ssh-copy-id $USER@$ip

        # 远程节点处理
        if [ "$SOURCE_TYPE" = "directory" ]; then
            echo "[远程] 初始化目录..."

            if [ $HAS_SSHPASS -eq 1 ]; then
                sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$ip" "mkdir -p \"$DEST_DIR\""
            else
                ssh -o StrictHostKeyChecking=no "$USER@$ip" "mkdir -p \"$DEST_DIR\""
            fi

            echo "[远程] 同步目录..."
            if [ $SKIP_LARGE_FILES -eq 1 ]; then
                if [ $HAS_SSHPASS -eq 1 ]; then
                    sshpass -p "$PASSWORD" rsync -avz --progress --max-size=100M \
                        -e "ssh -o StrictHostKeyChecking=no" \
                        "$SOURCE_DIR"/ "$USER@$ip:$DEST_DIR"/
                else
                    rsync -avz --progress --max-size=100M \
                        -e "ssh -o StrictHostKeyChecking=no" \
                        "$SOURCE_DIR"/ "$USER@$ip:$DEST_DIR"/
                fi
            else
                if [ $HAS_SSHPASS -eq 1 ]; then
                    sshpass -p "$PASSWORD" rsync -avz --delete --progress \
                        -e "ssh -o StrictHostKeyChecking=no" \
                        "$SOURCE_DIR"/ "$USER@$ip:$DEST_DIR"/
                else
                    rsync -avz --delete --progress \
                        -e "ssh -o StrictHostKeyChecking=no" \
                        "$SOURCE_DIR"/ "$USER@$ip:$DEST_DIR"/
                fi
            fi
        else
            if [ $SKIP_LARGE_FILES -eq 1 ]; then
                FILE_SIZE=$(stat -c%s "$FILE_PATH")
                if [ $FILE_SIZE -gt 104857600 ]; then
                    echo "跳过大文件 $FILE_NAME，不传输到 $ip"
                    continue
                fi
            fi
            echo "[远程] 创建目录并传输文件..."

            if [ $HAS_SSHPASS -eq 1 ]; then
                sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$ip" "mkdir -p \"$DEST_DIR\""
                sshpass -p "$PASSWORD" rsync -avz --progress \
                    -e "ssh -o StrictHostKeyChecking=no" \
                    "$FILE_PATH" "$USER@$ip:$DEST_DIR/"
            else
                ssh -o StrictHostKeyChecking=no "$USER@$ip" "mkdir -p \"$DEST_DIR\""
                rsync -avz --progress \
                    -e "ssh -o StrictHostKeyChecking=no" \
                    "$FILE_PATH" "$USER@$ip:$DEST_DIR/"
            fi
        fi
    fi
done

echo "=== 所有节点同步完成 ==="


auto_ssh() {
    local user="$1"
    local ip="$2"
    local password="$3"
    local command="$4"

    expect <<EOF
spawn ssh "$user@$ip" "$command"
expect {
    "Are you sure you want to continue connecting" {
        send "yes\r"; exp_continue
    }
    "password:" {
        send "$password\r"
    }
}
interact
EOF
}
