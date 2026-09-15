#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
可视化警告日志报告生成器
分析 build.log，生成 bug/readme.md
"""

import os
import re
import sys
from datetime import datetime, timezone
from collections import Counter


def main():
    build_log = sys.argv[1] if len(sys.argv) > 1 else "build.log"
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "bug"
    os.makedirs(output_dir, exist_ok=True)

    # 读取构建日志
    errors = []
    warnings = []
    if os.path.exists(build_log):
        with open(build_log, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                # 跳过 CI 脚本自身的输出行
                if any(skip in line for skip in ["echo ", "ERROR_COUNT", "WARNING_COUNT", "grep ", "🐛", "📊", "📋", "📁", "📝", "🎯", "📋"]):
                    continue
                # 匹配 Xcode 编译错误/警告格式: /path/to/file.swift:line:col: error: message
                if re.match(r"^/.*\.swift:\d+:\d+: error:", line):
                    errors.append(line)
                elif re.match(r"^/.*\.swift:\d+:\d+: warning:", line):
                    warnings.append(line)

    error_count = len(errors)
    warning_count = len(warnings)
    build_status = "❌ 构建失败" if error_count > 0 else "✅ 构建成功"

    # 警告分类
    def match_any(patterns, text):
        return any(re.search(p, text, re.IGNORECASE) for p in patterns)

    unused_var = [w for w in warnings if match_any(
        [r"never used", r"was never used", r"defined but never used", r"immutable value.*never used"], w)]
    deprecated = [w for w in warnings if match_any([r"deprecated", r"was deprecated"], w)]
    type_cast = [w for w in warnings if match_any([r"type cast", r"conditional cast", r"forced cast"], w)]
    nullability = [w for w in warnings if match_any([r"optional", r"nil coalescing", r"non-optional"], w)]
    other = [w for w in warnings if w not in unused_var and w not in deprecated and w not in type_cast and w not in nullability]

    def calc_percent(count):
        return f"{count * 100 // warning_count}%" if warning_count > 0 else "0%"

    # 文件分布（只匹配 .swift 文件）
    file_counts = Counter()
    for w in warnings:
        match = re.match(r"^/([^:]+\.swift):", w)
        if match:
            filename = match.group(1).split("/")[-1]
            file_counts[filename] += 1
    top_files = file_counts.most_common(20)

    # 代码行数
    total_lines = 0
    for root, dirs, files in os.walk("NovelReader"):
        for f in files:
            if f.endswith(".swift"):
                try:
                    with open(os.path.join(root, f), "r", encoding="utf-8", errors="replace") as fh:
                        total_lines += sum(1 for _ in fh)
                except Exception:
                    pass

    # 质量评级
    if error_count > 0:
        quality = "F级（构建失败）"
    elif warning_count == 0:
        quality = "A级（优秀，无警告）"
    elif warning_count < 10:
        quality = "B级（良好，警告较少）"
    elif warning_count < 30:
        quality = "C级（一般，建议清理警告）"
    else:
        quality = "D级（较差，警告较多）"

    gen_time = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    # 生成报告
    lines = []
    lines.append("# 🐛 可视化警告日志报告 (Bug Log)")
    lines.append("")
    lines.append(f"**生成时间**: {gen_time}")
    lines.append(f"**源日志文件**: `build.log`")
    lines.append(f"**构建状态**: {build_status}")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## 📊 问题统计概览")
    lines.append("")
    lines.append("| 类型 | 数量 | 状态 |")
    lines.append("|------|------|------|")
    lines.append(f"| 🔴 错误 | **{error_count:02d}** 个 | {'需修复' if error_count > 0 else '无错误'} |")
    lines.append(f"| 🟡 警告 | **{warning_count:02d}** 个 | {'建议清理' if warning_count > 0 else '无警告'} |")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## 📋 警告类型分布")
    lines.append("")
    lines.append("| 警告类型 | 数量 | 占比 |")
    lines.append("|----------|------|------|")
    lines.append(f"| ⚠️ 弃用API警告 | {len(deprecated):02d} 个 | {calc_percent(len(deprecated))} |")
    lines.append(f"| 📦 未使用变量警告 | {len(unused_var):02d} 个 | {calc_percent(len(unused_var))} |")
    lines.append(f"| 🔄 类型转换警告 | {len(type_cast):02d} 个 | {calc_percent(len(type_cast))} |")
    lines.append(f"| 🔍 可空性警告 | {len(nullability):02d} 个 | {calc_percent(len(nullability))} |")
    lines.append(f"| 📝 其他警告 | {len(other):02d} 个 | {calc_percent(len(other))} |")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## 📁 警告文件分布 (Top 20)")
    lines.append("")
    lines.append("| 排名 | 文件名 | 警告数量 | 严重程度 |")
    lines.append("|------|--------|----------|----------|")
    if top_files:
        for i, (filename, count) in enumerate(top_files, 1):
            if count >= 5:
                severity = "🔴 高"
            elif count >= 3:
                severity = "🟡 中"
            else:
                severity = "🟢 低"
            lines.append(f"| {i} | `{filename}` | {count} 个 | {severity} |")
    else:
        lines.append("| - | 无 | 0 个 | 🟢 低 |")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## 📝 警告详情列表")
    lines.append("")

    def add_warning_section(title, items):
        lines.append(f"### {title} ({len(items)}个)")
        lines.append("")
        lines.append("```")
        if items:
            for item in items[:20]:
                lines.append(item)
        else:
            lines.append("无")
        lines.append("```")
        lines.append("")

    add_warning_section("📦 未使用变量警告", unused_var)
    add_warning_section("⚠️ 弃用API警告", deprecated)
    add_warning_section("🔄 类型转换警告", type_cast)
    add_warning_section("🔍 可空性警告", nullability)
    add_warning_section("📝 其他警告", other)

    lines.append("---")
    lines.append("")
    lines.append("## 🎯 代码质量评估与建议")
    lines.append("")
    lines.append("### 📊 质量评级")
    lines.append("")
    lines.append(f"- **质量评级**: **{quality}**")
    lines.append(f"- **警告密度**: 每千行约 {warning_count * 1000 // total_lines if total_lines > 0 else 0} 个警告")
    lines.append(f"- **代码总行数**: {total_lines} 行")
    lines.append("")
    lines.append("### 💡 修复建议")
    lines.append("")

    if error_count > 0:
        lines.append(f"#### 1. 编译错误 ({error_count}个)")
        lines.append("- 优先修复所有编译错误，确保构建通过")
        lines.append("- 查看上方错误详情定位问题文件和行号")
        lines.append("")

    if unused_var:
        lines.append(f"#### 2. 未使用变量警告 ({len(unused_var)}个)")
        lines.append("- 删除未使用的变量和函数")
        lines.append("- 检查是否是调试代码遗留")
        lines.append("- 使用Xcode的静态分析工具辅助清理")
        lines.append("")

    if deprecated:
        lines.append(f"#### 3. 弃用API警告 ({len(deprecated)}个)")
        lines.append("- 替换为最新API")
        lines.append("- 检查最低系统版本兼容性")
        lines.append("")

    lines.append("#### 4. 警告数量管理")
    lines.append("- 建议分批次清理警告，优先清理高风险警告")
    lines.append("- 可以在CI中设置警告阈值，超过阈值则构建失败")
    lines.append("- 建立代码审查机制，防止新警告引入")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## 📋 报告说明")
    lines.append("")
    lines.append("- 本报告由CI流水线自动生成")
    lines.append("- 报告基于构建日志 `build.log` 分析生成")
    lines.append("- 报告包含警告统计、分类、文件分布、详情和修复建议")
    lines.append("- 如需查看原始构建日志，请下载 CI Artifacts")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("*本报告由 GitHub Actions 自动生成，仅供参考*")

    # 写入文件
    output_path = os.path.join(output_dir, "readme.md")
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print(f"✅ 报告已生成: {output_path} ({len(lines)} 行)")
    print(f"   错误: {error_count}, 警告: {warning_count}")


if __name__ == "__main__":
    main()
