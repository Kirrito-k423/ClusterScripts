#!/bin/bash

# ==================== 配置区 ====================

# 要安装的包（建议固定版本，确保可重复测试）
PACKAGE="cmake"

# 可选的国内 pip 源 (格式: "URL  Trusted-Host  名称")
SOURCES=(
    # "https://mirrors.aliyun.com/pypi/simple/        mirrors.aliyun.com        阿里云"
    # "https://repo.huaweicloud.com/repository/pypi/simple/  repo.huaweicloud.com 华为云"
    "https://pypi.mirrors.ustc.edu.cn/simple/       pypi.mirrors.ustc.edu.cn  中科大"
    # 清华源已被封，跳过或用于对比
    # "https://pypi.tuna.tsinghua.edu.cn/simple/    pypi.tuna.tsinghua.edu.cn 清华"
)

# 可选的代理列表（没有则留空字符串表示“无代理”）
PROXIES=(
    "http://p_atlas:proxy%40123@90.253.10.3:6688"
    "http://p_atlas:proxy%40123@90.253.10.3:8080"
    # "http://p_atlas:proxy%40123@90.253.10.3:8081"
    # "http://p_atlas:proxy%40123@90.253.10.3:8082"
    # "http://p_atlas:proxy%40123@90.253.10.3:8083"
    # ""  # 无代理（直连）
    # "http://90.253.10.3:8080"
    "http://90.253.10.3:8081"
    # "90.253.10.3:8081"
    # "http://90.253.10.3:8082"
    # "http://90.253.10.3:8083"
    # "http://90.253.10.3:6688"
)

# 是否强制重新安装（1=是，0=否）
# 设为 1 可真实测速；设为 0 可快速预览哪些组合能成功
FORCE_REINSTALL=1

# 超时时间（秒），防止卡死
TIMEOUT=30

# 临时日志目录
LOG_DIR="/tmp/pip-test-combo-$$"
mkdir -p "$LOG_DIR"

# 结果收集数组
RESULTS=()

# ==================================================

echo "🚀 开始测试 [代理 + pip源] 所有组合"
echo "📦 测试包: $PACKAGE"
echo "📝 日志路径: $LOG_DIR"
echo "⏳ 最长等待: ${TIMEOUT}s/组合"
echo "----------------------------------------"

# 外层循环：遍历所有源
for source in "${SOURCES[@]}"; do
    read -r URL HOST NAME <<< "$source"

    # 内层循环：遍历所有代理
    for PROXY in "${PROXIES[@]}"; do
        # 格式化代理显示名
        proxy_label="${PROXY:-无代理}"
        proxy_flag="${PROXY:+--proxy $PROXY}"

        echo "🔍 测试中: [$NAME] + [$proxy_label] ..."

        log_file="$LOG_DIR/${NAME// /_}_${proxy_label//[:\/@.]/_}.log"
        start_time=$(date +%s)

        # 构建 pip 命令
        cmd=(
            pip install "$PACKAGE"
            -i "$URL"
            --trusted-host "$HOST"
            -v --progress-bar=on 
            $proxy_flag
        )
        [ $FORCE_REINSTALL -eq 1 ] && cmd+=(--no-cache-dir --force-reinstall --no-deps)

        echo "命令是 ${cmd[@]}"
        # 执行命令并记录结果
        if timeout $TIMEOUT "${cmd[@]}" |tee "$log_file" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            echo -e "✅ 成功 | 耗时: ${duration} 秒\n"
            RESULTS+=("$duration|$NAME|$proxy_label|成功")
        else
            ret_code=$?
            error_hint=$(grep -E 'ERROR|Could not|timeout|407|403' "$log_file" | tail -n1 | sed 's/^.*ERROR: //; s/^.*error: //')
            echo -e "❌ 失败 | 错误码: $ret_code, 提示: ${error_hint:-连接超时或被拒绝}\n"
            RESULTS+=("9999|$NAME|$proxy_label|失败: $error_hint")
        fi
    done
done

# 删除临时日志（可选：注释掉以保留日志用于分析）
# rm -rf "$LOG_DIR"

# ==================== 输出最终结果 ====================

echo "========================================"
echo "🏆 所有组合测试完成！按速度排序："
printf '%-12s %-12s %-25s %s\n' "耗时(秒)" "源" "代理" "状态"
echo "------------------------------------------------------------"

# 排序并打印结果（成功在前，按耗时升序）
printf '%s\n' "${RESULTS[@]}" | sort -t'|' -k1,1n -k4 | while IFS='|' read -r duration name proxy status; do
    display_duration=$([ $duration -lt 9999 ] && echo "$duration" || echo "--")
    printf '%-12s %-12s %-25s %s\n' "$display_duration" "$name" "$proxy" "$status"
done

echo

# 推荐最快的成功组合
SUCCESSFUL=($(printf '%s\n' "${RESULTS[@]}" | grep "^$"))
if [ ${#SUCCESSFUL[@]} -gt 0 ]; then
    BEST=$(printf '%s\n' "${SUCCESSFUL[@]}" | sort -t'|' -k1,1n | head -1)
    IFS='|' read -r duration name proxy status <<< "$BEST"
    echo "🎉 推荐使用以下组合（最快）："
    echo "   源: $name"
    echo "   代理: $proxy"
    echo "   命令:"
    best_host=$(printf '%s\n' "${SOURCES[@]}" | grep "$name" | awk '{print $2}')
    echo
    echo "pip install $PACKAGE \\"
    echo "  -i $URL \\"
    echo "  --trusted-host $best_host \\"
    [ -n "$PROXY" ] && echo "  --proxy $proxy \\"
    echo "  # 成功耗时: ${duration} 秒"
else
    echo "❌ 所有组合均失败。"
    echo "💡 建议："
    echo "   1. 检查代理地址是否正确、是否有认证（如 user:pass@）"
    echo "   2. 尝试仅用 '无代理' 组合"
    echo "   3. 更换其他镜像源（如新增 pypi.org 官方源做对比）"
fi

echo
echo "📁 日志已保存至: $LOG_DIR （可在失败后查看详细错误）"
