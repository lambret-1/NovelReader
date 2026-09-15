#!/bin/bash
# ============================================
# 可视化警告日志报告生成器
# 分析 build.log，生成 bug/readme.md
# 使用 Python 确保 UTF-8 编码输出
# ============================================

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

BUILD_LOG="${1:-build.log}"
OUTPUT_DIR="${2:-bug}"
mkdir -p "$OUTPUT_DIR"

python3 << PYEOF
import os
import re
from datetime import datetime, timezone

build_log = os.environ.get("BUILD_LOG", "$BUILD_LOG")
output_dir = os.environ.get("OUTPUT_DIR", "$OUTPUT_DIR")

# 读取构建日志
errors = []
warnings = []
if os.path.exists(build_log):
    with open(build_log, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            if "error:" in line and not line.strip().startswith("echo") and "ERROR_COUNT" not in line:
                errors.append(line.strip())
            if "warning:" in line and not line.strip().startswith("echo") and "WARNING_COUNT" not in line:
                warnings.append(line.strip())

error_count = len(errors)
warning_count = len(warnings)

# 构建状态
build_status = "❌ 构建失败" if error_count > 0 else "✅ 构建成功"

# 警告分类
unused_var = [w for w in warnings if re.search(r"never used|was never used|defined but never used|immutable value.*never used", w, re.IGNORECASE)]
deprecated = [w for w in warnings if re.search(r"deprecated|was deprecated", w, re.IGNORECASE)]
type_cast = [w for w in warnings if re.search(r"type cast|conditional cast|forced cast", w, re.IGNORECASE)]
nullability = [w for w in warnings if re.search(r"optional|nil coalescing|non-optional", w, re.IGNORECASE)]
other = [w for w in warnings if w not in unused_var and w not in deprecated and w not in type_cast and w not in nullability]

def calc_percent(count):
    return f"{count * 100 // warning_count}%" if warning_count > 0 else "0%"

# 文件分布
from collections import Counter
file_counts = Counter()
for w in warnings:
    match = re.match(r"^([^:]+):", w)
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
            except:
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

# 生成时间
gen_time = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

# 生成报告
report = f"""# 🐛 可视化警告日志报告 (Bug Log)

**生成时间**: {gen_time}
**源日志文件**: \`build.log\`
**构建状态**: {build_status}

---

## 📊 问题统计概览

| 类型 | 数量 | 状态 |
|------|------|------|
| 🔴 错误 | **{error_count:02d}** 个 | {"需修复" if error_count > 0 else "无错误"} |
| 🟡 警告 | **{warning_count:02d}** 个 | {"建议清理" if warning_count > 0 else "无警告"} |

---

## 📋 警告类型分布

| 警告类型 | 数量 | 占比 |
|----------|------|------|
| ⚠️ 弃用API警告 | {len(deprecated):02d} 个 | {calc_percent(len(deprecated))} |
| 📦 未使用变量警告 | {len(unused_var):02d} 个 | {calc_percent(len(unused_var))} |
| 🔄 类型转换警告 | {len(type_cast):02d} 个 | {calc_percent(len(type_cast))} |
| 🔍 可空性警告 | {len(nullability):02d} 个 | {calc_percent(len(nullability))} |
| 📝 其他警告 | {len(other):02d} 个 | {calc_percent(len(other))} |

---

## 📁 警告文件分布 (Top 20)

| 排名 | 文件名 | 警告数量 | 严重程度 |
|------|--------|----------|----------|
"""

for i, (filename, count) in enumerate(top_files, 1):
    if count >= 5:
        severity = "🔴 高"
    elif count >= 3:
        severity = "🟡 中"
    else:
        severity = "🟢 低"
    report += f"| {i} | \`{filename}\` | {count} 个 | {severity} |\n"

if not top_files:
    report += "| - | 无 | 0 个 | 🟢 低 |\n"

report += """
---

## 📝 警告详情列表

### 📦 未使用变量警告 (""" + str(len(unused_var)) + """个)

```
""" + ("\n".join(unused_var[:20]) if unused_var else "无") + """
```

### ⚠️ 弃用API警告 (""" + str(len(deprecated)) + """个)

```
""" + ("\n".join(deprecated[:20]) if deprecated else "无") + """
```

### 🔄 类型转换警告 (""" + str(len(type_cast)) + """个)

```
""" + ("\n".join(type_cast[:20]) if type_cast else "无") + """
```

### 🔍 可空性警告 (""" + str(len(nullability)) + """个)

```
""" + ("\n".join(nullability[:20]) if nullability else "无") + """
```

### 📝 其他警告 (""" + str(len(other)) + """个)

```
""" + ("\n".join(other[:20]) if other else "无") + """
```

---

## 🎯 代码质量评估与建议

### 📊 质量评级

- **质量评级**: **""" + quality + """**
- **警告密度**: 每千行约 """ + str(warning_count * 1000 // total_lines if total_lines > 0 else 0) + """ 个警告
- **代码总行数**: """ + str(total_lines) + """ 行

### 💡 修复建议

"""

if error_count > 0:
    report += f"""#### 1. 编译错误 ({error_count}个)
- 优先修复所有编译错误，确保构建通过
- 查看上方错误详情定位问题文件和行号

"""

if unused_var:
    report += f"""#### 2. 未使用变量警告 ({len(unused_var)}个)
- 删除未使用的变量和函数
- 检查是否是调试代码遗留
- 使用Xcode的静态分析工具辅助清理

"""

if deprecated:
    report += f"""#### 3. 弃用API警告 ({len(deprecated)}个)
- 替换为最新API
- 检查最低系统版本兼容性

"""

report += """#### 4. 警告数量管理
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
"""

# 写入文件
output_path = os.path.join(output_dir, "readme.md")
with open(output_path, "w", encoding="utf-8") as f:
    f.write(report)

print(f"✅ 报告已生成: {output_path} ({len(report.splitlines())} 行)")
PYEOF
