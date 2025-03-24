#!/bin/bash
USER="root" 
# 定义本地日志目录
LOCAL_DIR="/path/to/local/logs"
# 定义远程机器的 IP 地址列表
REMOTE_MACHINES=("192.168.1.101" "192.168.1.102" "192.168.1.103" "192.168.1.104" "192.168.1.105" "192.168.1.106" "192.168.1.107" "192.168.1.108")
# 定义远程日志文件路径
REMOTE_LOG_PATH="/path/to/log"
# 定义 SSH 密码
SSH_PASSWORD="your_password"

# 循环遍历每台机器
for IP in "${REMOTE_MACHINES[@]}"; do
  # 创建以 IP 为名称的子目录（如果不存在）
  DEST_DIR="$LOCAL_DIR/$IP"
  mkdir -p "$DEST_DIR"

  # 使用 sshpass 和 rsync 同步日志文件到对应的本地子目录
  sshpass -p "$SSH_PASSWORD" rsync -avz -e ssh "$USER@$IP:$REMOTE_LOG_PATH" "$DEST_DIR"

  if [ $? -eq 0 ]; then
    echo "Logs from $IP synchronized successfully."
  else
    echo "Failed to sync logs from $IP."
  fi
done
