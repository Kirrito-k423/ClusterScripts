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

# 检查输入参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory or file>"
    exit 1
fi

# 判断输入类型（文件/目录）
if [ -f "$1" ]; then
    SOURCE_TYPE="file"
    FILE_PATH="$1"
    SOURCE_DIR=$(dirname "$FILE_PATH")
    DEST_DIR="$SOURCE_DIR"
    FILE_NAME=$(basename "$FILE_PATH")
elif [ -d "$1" ]; then
    SOURCE_TYPE="directory"
    SOURCE_DIR="$1"
    DEST_DIR="$1"
else
    echo "Error: $1 does not exist or is inaccessible."
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
            rsync -a --delete --info=progress2 "$SOURCE_DIR"/ "$DEST_DIR"/
        else
            echo "[本地] 同步文件..."
            rsync -a --info=progress2 "$FILE_PATH" "$DEST_DIR/"
        fi
    else
        # 远程节点处理
        if [ "$SOURCE_TYPE" = "directory" ]; then
            echo "[远程] 初始化目录..."
            sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$ip" "mkdir -p \"$DEST_DIR\""
            
            echo "[远程] 同步目录..."
            sshpass -p "$PASSWORD" rsync -avz --delete --progress \
                -e "ssh -o StrictHostKeyChecking=no" \
                "$SOURCE_DIR"/ "$USER@$ip:$DEST_DIR"/
        else
            echo "[远程] 创建目录并传输文件..."
            sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$ip" "mkdir -p \"$DEST_DIR\""
            
            sshpass -p "$PASSWORD" rsync -avz --progress \
                -e "ssh -o StrictHostKeyChecking=no" \
                "$FILE_PATH" "$USER@$ip:$DEST_DIR/"
        fi
    fi
done

echo "=== 所有节点同步完成 ==="
