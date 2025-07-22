#!/bin/bash

# =============================
# 批量复制目录到多个目标机器
# 使用已有 dtrans.sh 脚本
# =============================

# 定义目标IP列表
TARGET_IPS=(
    "90.91.109.21"
    "90.91.109.22"
    "90.91.109.26"
)

# 定义要复制的本地目录列表
DIRS_TO_COPY=(
    "/root/st_tsj.sh"
    "/home/t00906153/dtrans.sh"
    "/home/t00906153/batch_dtrans.sh"
    "/home/t00906153/set_proxy.sh"
    "/home/t00906153/zsh.tar"
    "/home/t00906153/PTA"
)

# 包装复制操作为函数
transfer_to_host() {
    local host=$1
    echo "🔄 开始向 $host 传输文件..."

    for dir in "${DIRS_TO_COPY[@]}"; do
        echo "📦 正在复制: $dir → $host"
        ~/dtrans.sh "$host" "$dir"
        if [ $? -eq 0 ]; then
            echo "  ✅ 成功复制 $dir 到 $host"
        else
            echo "  ❌ 复制失败: $dir → $host"
        fi
    done

    echo "✅ $host 传输完成"
    echo "-----------------------------"
}

# 主程序：遍历所有目标主机
main() {
    echo "🚀 开始批量传输任务"
    echo "目标主机数: ${#TARGET_IPS[@]}"
    echo "待复制目录数: ${#DIRS_TO_COPY[@]}"
    echo "-----------------------------"

    for ip in "${TARGET_IPS[@]}"; do
        transfer_to_host "$ip"
    done

    echo "🎉 所有传输任务完成！"
}

# 执行主函数
main "$@"
