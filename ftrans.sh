#!/bin/bash

# 配置参数
USER="root"          # SSH用户名
PASSWORD="xxx"      # SSH密码
DEST_DIR="/home/t00906153"  # 目标目录（确保有写入权限）
SOURCE_FILE="/home/t00906153/dsV3_0310/dsV3-dev_release_0211.zip" # 源文件路径
SOURCE_IP="141.61.29.101"
IPs=(
    '141.61.29.102'
    '141.61.29.103'
    '141.61.29.104'
    '141.61.29.105'
    '141.61.29.106'
    '141.61.29.107'
    '141.61.29.108'
)

# 遍历所有IP
for ip in "${IPs[@]}"; do
    echo "处理IP: $ip"
    if [[ $ip == "$SOURCE_IP" ]]; then
        # 本地目录处理
        mkdir -p "$DEST_DIR"
        cp -v "$SOURCE_FILE" "$DEST_DIR"
    else
        # 远程操作：创建目录并传输文件
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$ip" "mkdir -p '$DEST_DIR'"
        sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no "$SOURCE_FILE" "$USER@$ip:'$DEST_DIR/'"
    fi
done

echo "文件传输完成。"
