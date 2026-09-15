#!/bin/bash
# ============================================
# 可视化警告日志报告生成器（入口脚本）
# 调用 Python 脚本分析 build.log，生成 bug/readme.md
# ============================================

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

BUILD_LOG="${1:-build.log}"
OUTPUT_DIR="${2:-bug}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/generate_bug_report.py" "$BUILD_LOG" "$OUTPUT_DIR"
