#!/bin/bash

# 配置区
USER="root"                 # SSH用户名
PASSWORD="xxx"             # 密码（建议改用密钥）
IPS=(
    "141.61.29.101"
    '141.61.29.102'
    '141.61.29.103'
    '141.61.29.104'
    '141.61.29.105'
    '141.61.29.106'
    '141.61.29.107'
    '141.61.29.108'
    # ...其他IP
)
MAX_PARALLEL=4                       # 最大并行任务数

# ----- 全局固定参数 -----
COMMON_ARGS="/home/l00878165/deepseekv3-lite-base-latest_bugtest 1 1 4096 5 256 3 0 "

# ==== 路径配置 ====
declare -A NODE_PATHS=(
    # 基础路径 + 节点专属子目录
    ["141.61.29.101"]="/opt/deploy/master"
    ["141.61.29.102"]="/opt/deploy/worker/102"
    ["141.61.29.103"]="/data/processing/node_103"
)


# ----- 节点专属参数映射表 -----
declare -A NODE_PARAMS=(
    # 格式: [IP]="参数1=值 参数2=值"
    ["141.61.29.101"]="0"
    ["141.61.29.102"]="16"
    ["141.61.29.103"]="32"
    ["141.61.29.104"]="node_id=103 role=storage disk=/data"
    ["141.61.29.105"]="node_id=103 role=storage disk=/data"
    ["141.61.29.106"]="node_id=103 role=storage disk=/data"
    ["141.61.29.107"]="node_id=103 role=storage disk=/data"
    ["141.61.29.108"]="node_id=103 role=storage disk=/data"
)

# ----- 参数生成规则 -----
generate_command() {
    local ip=$1

    local work_dir="/home/t00906153/dsV3_0310/dsV3-dev_release_0211/inference/moe/deepseek/scripts"
    
    # 安全创建目录并切换工作路径
    local cmd_prepare="mkdir -p '${work_dir}' && cd '${work_dir}' || exit 1"
    
    # 提取预设参数
    local node_args="${NODE_PARAMS[$ip]}"

    # 节点专属命令
    local main_cmd="bash eight.sh \
        $COMMON_ARGS \
        $node_args"

    # 组合完整命令
    echo "${cmd_prepare} && ${main_cmd}"
}

# ==== 执行引擎 ====
trap 'kill $(jobs -p)' EXIT  # 安全退出

for ip in "${IPS[@]}"; do
    (
        # 生成命令
        command=$(generate_command "$ip")
        
        # 执行逻辑
        echo "[启动] $ip => $command"
        if [[ "$ip" == $(hostname -I | awk '{print $1}') ]]; then
            eval "$command" 2>&1 | sed "s/^/[本地] /"
        else
            sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o LogLevel=QUIET -n "$USER@$ip" "$command" 2>&1 | sed "s/^/[远程] /"
        fi
        echo "[完成] $ip"
    ) &
    
    # 并发控制
    ((count++))
    if ((count % MAX_PARALLEL == 0)); then
        wait
    fi
done
wait
echo "=== 集群任务执行完毕 ==="
