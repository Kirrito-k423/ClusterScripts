#!/bin/bash

# 配置参数
USER="root"             
PASSWORD="xxx"          
DEST_DIR=$1      
SOURCE_DIR=$1  
SOURCE_IP="141.61.29.101"    
IPs=(
    '141.61.29.102'
    '141.61.29.103'
    '141.61.29.104'
)

# 遍历所有节点
for ip in "${IPs[@]}"; do
    echo "==== 正在处理 $ip ===="
    
    if [[ $ip == "$SOURCE_IP" ]]; then
        mkdir -p "$DEST_DIR"
        echo "[本地] 同步文件夹内容..."
        rsync -a --delete --info=progress2 "$SOURCE_DIR"/ "$DEST_DIR"/
    else
        echo "[远程] 初始化目录..."
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$ip" "mkdir -p '$DEST_DIR'"
        
        echo "[远程] 同步文件..."
        # 改造后的rsync命令
        sshpass -p "$PASSWORD" rsync -avz --delete --progress \
            -e "ssh -o StrictHostKeyChecking=no" \
            "$SOURCE_DIR"/ "$USER@$ip:$DEST_DIR"/
    fi
done

echo "=== 所有节点同步完成 ==="
