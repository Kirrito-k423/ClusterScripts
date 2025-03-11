
#!/bin/bash

# 配置参数
USER="root"              # SSH用户名
PASSWORD="xxx"          # SSH密码（生产环境建议用密钥）
DEST_DIR="/home/t00906153/dsV3_0310/dsV3-dev_release_0211"      # 目标目录（需写权限）
SOURCE_DIR="/home/t00906153/dsV3_0310/dsV3-dev_release_0211"  # 源文件夹路径（末尾不要带斜杠）
SOURCE_IP="141.61.29.101"    # 当前主机IP（避免自连接）
IPs=(
    '141.61.29.102'
    '141.61.29.103'
    '141.61.29.104'
    '141.61.29.105'
    '141.61.29.106'
    '141.61.29.107'
    '141.61.29.108'
)

# 遍历所有节点
for ip in "${IPs[@]}"; do
    echo "==== 正在处理 $ip ===="
    
    # 在目标节点创建目录（本地/远程）
    if [[ $ip == "$SOURCE_IP" ]]; then
        mkdir -p "$DEST_DIR"
        echo "[本地] 同步文件夹内容..."
        rsync -rlt --delete --info=progress2 "$SOURCE_DIR"/ "$DEST_DIR"/
    else
        echo "[远程] 初始化目录..."
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$ip" "mkdir -p '$DEST_DIR'"
        
        echo "[远程] 同步文件..."
        sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -rpq "$SOURCE_DIR"/* "$USER@$ip:'$DEST_DIR'"
    fi
done

echo "=== 所有节点同步完成 ==="
