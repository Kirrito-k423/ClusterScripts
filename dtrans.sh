#!/bin/bash

# 配置参数
USER="root"             
PASSWORD="xxx"          
SOURCE_IP="141.61.29.101"    
IPs=(
    '141.61.29.102'
    '141.61.29.103'
    '141.61.29.104'
)

# 处理输入参数
SKIP_LARGE_FILES=0
TARGET_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -skipb)
            SKIP_LARGE_FILES=1
            shift
            ;;
        *)
            if [ -z "$TARGET_ARG" ]; then
                TARGET_ARG="$1"
                shift
            else
                echo "错误：多余的参数 $1"
                exit 1
            fi
            ;;
    esac
done

if [ -z "$TARGET_ARG" ]; then
    echo "Usage: $0 [-skipb] <directory or file>"
    exit 1
fi

# 判断输入类型（文件/目录）
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
        # 远程节点处理
        if [ "$SOURCE_TYPE" = "directory" ]; then
            echo "[远程] 初始化目录..."
            sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$ip" "mkdir -p \"$DEST_DIR\""
            
            echo "[远程] 同步目录..."
            if [ $SKIP_LARGE_FILES -eq 1 ]; then
                sshpass -p "$PASSWORD" rsync -avz --progress --max-size=100M \
                    -e "ssh -o StrictHostKeyChecking=no" \
                    "$SOURCE_DIR"/ "$USER@$ip:$DEST_DIR"/
            else
                sshpass -p "$PASSWORD" rsync -avz --delete --progress \
                    -e "ssh -o StrictHostKeyChecking=no" \
                    "$SOURCE_DIR"/ "$USER@$ip:$DEST_DIR"/
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
            sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$ip" "mkdir -p \"$DEST_DIR\""
            
            sshpass -p "$PASSWORD" rsync -avz --progress \
                -e "ssh -o StrictHostKeyChecking=no" \
                "$FILE_PATH" "$USER@$ip:$DEST_DIR/"
        fi
    fi
done

echo "=== 所有节点同步完成 ==="
