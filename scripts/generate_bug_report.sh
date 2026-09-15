#!/bin/bash
# ============================================
# 可视化警告日志报告生成器
# 分析 build.log，生成 bug/readme.md
# ============================================

set -e

BUILD_LOG="${1:-build.log}"
OUTPUT_DIR="${2:-bug}"
mkdir -p "$OUTPUT_DIR"

# 安全计数函数
count_matches() {
    local pattern="$1"
    local file="$2"
    if [ ! -f "$file" ]; then
        echo 0
        return
    fi
    local n
    n=$(grep -cE "$pattern" "$file" 2>/dev/null || true)
    echo "${n:-0}"
}

# 统计错误和警告
ERROR_COUNT=$(count_matches "error:" "$BUILD_LOG")
WARNING_COUNT=$(count_matches "warning:" "$BUILD_LOG")

# 构建状态
if [ "$ERROR_COUNT" -gt 0 ]; then
    BUILD_STATUS="❌ 构建失败"
else
    BUILD_STATUS="✅ 构建成功"
fi

# 警告类型分类
UNUSED_VAR=$(count_matches "warning:.*(never used|was never used|defined but never used|immutable value.*never used)" "$BUILD_LOG")
DEPRECATED=$(count_matches "warning:.*(deprecated|was deprecated)" "$BUILD_LOG")
TYPE_CAST=$(count_matches "warning:.*(type cast|conditional cast|forced cast)" "$BUILD_LOG")
NULLABILITY=$(count_matches "warning:.*(optional|nil coalescing|non-optional)" "$BUILD_LOG")
OTHER_WARN=$((WARNING_COUNT - UNUSED_VAR - DEPRECATED - TYPE_CAST - NULLABILITY))
if [ "$OTHER_WARN" -lt 0 ]; then OTHER_WARN=0; fi

# 计算占比
calc_percent() {
    if [ "$WARNING_COUNT" -gt 0 ]; then
        echo "$(( $1 * 100 / WARNING_COUNT ))%"
    else
        echo "0%"
    fi
}

# 警告文件分布 Top 20
generate_file_dist() {
    if [ ! -f "$BUILD_LOG" ] || [ "$WARNING_COUNT" -eq 0 ]; then
        echo "| - | 无 | 0 个 | 🟢 低 |"
        return
    fi
    local rank=0
    grep "warning:" "$BUILD_LOG" | sed 's/:.*//' | awk -F'/' '{print $NF}' | sort | uniq -c | sort -rn | head -20 | while read -r count filename; do
        rank=$((rank + 1))
        if [ "$count" -ge 5 ]; then
            severity="🔴 高"
        elif [ "$count" -ge 3 ]; then
            severity="🟡 中"
        else
            severity="🟢 低"
        fi
        echo "| $rank | \`$filename\` | $count 个 | $severity |"
    done
}

# 警告详情
generate_warning_details() {
    local pattern="$1"
    local label="$2"
    local count="$3"
    echo "### $label ($count个)"
    echo ""
    echo '```'
    if [ -f "$BUILD_LOG" ] && [ "$count" -gt 0 ]; then
        grep -E "$pattern" "$BUILD_LOG" | head -20
    else
        echo "无"
    fi
    echo '```'
    echo ""
}

# 代码总行数
TOTAL_LINES=$(find NovelReader -name "*.swift" -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')

# 质量评级
if [ "$ERROR_COUNT" -gt 0 ]; then
    QUALITY="F级（构建失败）"
elif [ "$WARNING_COUNT" -eq 0 ]; then
    QUALITY="A级（优秀，无警告）"
elif [ "$WARNING_COUNT" -lt 10 ]; then
    QUALITY="B级（良好，警告较少）"
elif [ "$WARNING_COUNT" -lt 30 ]; then
    QUALITY="C级（一般，建议清理警告）"
else
    QUALITY="D级（较差，警告较多）"
fi

# 生成报告
cat > "$OUTPUT_DIR/readme.md" << EOF
# 🐛 可视化警告日志报告 (Bug Log)

**生成时间**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**源日志文件**: \`build.log\`
**构建状态**: $BUILD_STATUS

---

## 📊 问题统计概览

| 类型 | 数量 | 状态 |
|------|------|------|
| 🔴 错误 | **$(printf "%02d" "$ERROR_COUNT")** 个 | $(if [ "$ERROR_COUNT" -gt 0 ]; then echo "需修复"; else echo "无错误"; fi) |
| 🟡 警告 | **$(printf "%02d" "$WARNING_COUNT")** 个 | $(if [ "$WARNING_COUNT" -gt 0 ]; then echo "建议清理"; else echo "无警告"; fi) |

---

## 📋 警告类型分布

| 警告类型 | 数量 | 占比 |
|----------|------|------|
| ⚠️ 弃用API警告 | $(printf "%02d" "$DEPRECATED") 个 | $(calc_percent "$DEPRECATED") |
| 📦 未使用变量警告 | $(printf "%02d" "$UNUSED_VAR") 个 | $(calc_percent "$UNUSED_VAR") |
| 🔄 类型转换警告 | $(printf "%02d" "$TYPE_CAST") 个 | $(calc_percent "$TYPE_CAST") |
| 🔍 可空性警告 | $(printf "%02d" "$NULLABILITY") 个 | $(calc_percent "$NULLABILITY") |
| 📝 其他警告 | $(printf "%02d" "$OTHER_WARN") 个 | $(calc_percent "$OTHER_WARN") |

---

## 📁 警告文件分布 (Top 20)

| 排名 | 文件名 | 警告数量 | 严重程度 |
|------|--------|----------|----------|
$(generate_file_dist)

---

## 📝 警告详情列表

$(generate_warning_details "warning:.*(never used|was never used|defined but never used)" "📦 未使用变量警告" "$UNUSED_VAR")
$(generate_warning_details "warning:.*(deprecated|was deprecated)" "⚠️ 弃用API警告" "$DEPRECATED")
$(generate_warning_details "warning:.*(type cast|conditional cast|forced cast)" "🔄 类型转换警告" "$TYPE_CAST")
$(generate_warning_details "warning:.*(optional|nil coalescing|non-optional)" "🔍 可空性警告" "$NULLABILITY")

### 📝 其他警告 ($OTHER_WARN个)

\`\`\`
$(if [ -f "$BUILD_LOG" ] && [ "$OTHER_WARN" -gt 0 ]; then grep "warning:" "$BUILD_LOG" | grep -vE "(never used|deprecated|type cast|optional|nil coalescing)" | head -20; else echo "无"; fi)
\`\`\`

---

## 🎯 代码质量评估与建议

### 📊 质量评级

- **质量评级**: **$QUALITY**
- **警告密度**: 每千行约 $(if [ "$TOTAL_LINES" -gt 0 ]; then echo "$(( WARNING_COUNT * 1000 / TOTAL_LINES ))"; else echo "0"; fi) 个警告
- **代码总行数**: $TOTAL_LINES 行

### 💡 修复建议

$(if [ "$ERROR_COUNT" -gt 0 ]; then echo "#### 1. 编译错误 ($ERROR_COUNT个)
- 优先修复所有编译错误，确保构建通过
- 查看上方错误详情定位问题文件和行号"; fi)

$(if [ "$UNUSED_VAR" -gt 0 ]; then echo "#### 2. 未使用变量警告 ($UNUSED_VAR个)
- 删除未使用的变量和函数
- 检查是否是调试代码遗留
- 使用Xcode的静态分析工具辅助清理"; fi)

$(if [ "$DEPRECATED" -gt 0 ]; then echo "#### 3. 弃用API警告 ($DEPRECATED个)
- 替换为最新API
- 检查最低系统版本兼容性"; fi)

#### 4. 警告数量管理
- 建议分批次清理警告，优先清理高风险警告
- 可以在CI中设置警告阈值，超过阈值则构建失败
- 建立代码审查机制，防止新警告引入

---

## 📋 报告说明

- 本报告由CI流水线自动生成
- 报告基于构建日志 \`build.log\` 分析生成
- 报告包含警告统计、分类、文件分布、详情和修复建议
- 如需查看原始构建日志，请下载 CI Artifacts

---

*本报告由 GitHub Actions 自动生成，仅供参考*
EOF

echo "✅ 报告已生成: $OUTPUT_DIR/readme.md ($(wc -l < "$OUTPUT_DIR/readme.md") 行)"
