# NovelReader - 小说阅读编辑 + GitHub 云同步

一个支持小说阅读、编辑和 GitHub 云同步的 iOS 应用，最低支持 iOS 14。

## 功能特性

### 📚 书架管理
- 创建、删除、重命名书籍
- 书籍列表展示，支持未同步状态标识
- 本地数据库持久化（GRDB.swift / SQLite）

### ✍️ 章节编辑
- 章节创建、删除、排序
- 富文本编辑（UITextView）
- 自动保存（防抖 3 秒）
- 实时字数统计
- 章节标题编辑

### 📖 阅读器
- 流畅的章节阅读体验
- 字号调节（12-32pt）
- 四种主题：日间、夜间、护眼、羊皮纸（均适配深色模式）
- 左右滑动切换章节
- 点击屏幕显示/隐藏设置面板
- 书签管理、章节内搜索

### ☁️ GitHub 云同步（双向）
- Personal Access Token 登录
- 双向同步：上传本地修改 + 下载远端更新
- 基于 Git Data API 的批量提交（一次 commit 多个文件）
- Manifest 差异对比，增量同步（仅下载/上传有变化的文件）
- 冲突检测：双方都修改时保留本地版本上传，并记录冲突项
- 同步前自动检查仓库存在性，不存在则自动创建私有仓库
- 自动检测仓库默认分支（不再硬编码 main）
- 支持自定义同步仓库地址
- 阅读进度同步（last write wins，按书籍+章节匹配）
- 书签同步（合并去重，按书籍+章节+偏移量匹配）
- 书籍元数据同步（标题/作者，排序保持本地优先）
- Token 安全存储于 Keychain

### 🔒 安全
- GitHub Token 存储在 Keychain
- 所有网络请求通过 HTTPS
- 不收集用户数据，内容仅存储在本地和用户自己的 GitHub 仓库

## 技术架构

```
┌─────────────────────────────────────────┐
│           Presentation 层                │
│  UIViewController / ViewModel (MVVM)    │
├─────────────────────────────────────────┤
│             Domain 层                    │
│  UseCase / Service / Model / Protocol   │
├─────────────────────────────────────────┤
│              Data 层                     │
│  Repository (GRDB) / GitHub API Client  │
├─────────────────────────────────────────┤
│            SyncEngine                    │
│  双向同步 / Manifest 对比 / 冲突处理     │
│  阅读进度同步 / 书签同步 / 批量提交      │
└─────────────────────────────────────────┘
```

### 技术栈
- **语言**: Swift 5
- **最低系统**: iOS 14.0
- **UI**: UIKit（程序式布局，无 Storyboard 依赖）
- **响应式**: Combine
- **数据库**: GRDB.swift (SQLite)
- **网络**: URLSession + 自定义封装
- **依赖注入**: AppContainer（支持 init 注入，保留 shared 向后兼容）
- **存储**: Keychain (Token) / UserDefaults (偏好)

### 设计令牌（DesignToken）
项目统一使用以下设计令牌，确保 UI 一致性：
- **间距**: 4pt / 8pt / 12pt / 16pt / 24pt / 32pt（8pt 网格）
- **圆角**: 6pt / 12pt / 16pt / 24pt
- **字体**: 12pt 说明 / 14pt 正文小 / 16pt 正文 / 17pt 标题 / 20pt 大标题 / 28pt 展示
- **颜色**: 全部使用系统动态颜色，自动适配深色模式

### GitHub 仓库结构
同步时在用户 GitHub 仓库中创建以下结构：
```
MyNovels/
├── .novel-sync/
│   ├── manifest.json          # 文件清单与 hash（用于增量对比）
│   ├── progress.json          # 阅读进度（跨设备同步）
│   └── bookmarks.json         # 书签数据（跨设备同步）
├── 书名/
│   ├── meta.json              # 书籍元数据
│   ├── 001_第一章.md           # 章节内容（Markdown）
│   └── 002_第二章.md
└── README.md
```

## 快速开始

### 环境要求
- Xcode 15.4+
- iOS 14.0+
- Swift 5.0+

### 安装步骤
1. 克隆仓库
2. 用 Xcode 打开 `NovelReader.xcodeproj`
3. 等待 Swift Package Manager 下载 GRDB.swift 依赖
4. 选择模拟器或真机，点击运行

### GitHub 同步配置
1. 在 GitHub 生成 Personal Access Token:
   - 进入 GitHub → Settings → Developer settings → Personal access tokens
   - 点击 "Generate new token"
   - 勾选 `repo` 权限
   - 生成并复制 Token
2. 在 APP 中进入「设置」→「云同步」→「登录 GitHub」
3. 输入 Token 完成登录
4. 默认同步仓库为 `用户名/MyNovels`，可在云同步页面点击「修改仓库」自定义
5. 点击「立即同步」开始同步（仓库不存在会自动创建）

## 项目结构

```
NovelReader/
├── App/                    # 应用入口与依赖注入
├── Configuration/          # 全局配置、主题、DesignToken
├── Domain/
│   ├── Models/             # 数据模型
│   ├── Protocols/          # 仓库协议
│   └── UseCases/           # 业务用例
├── Data/
│   ├── Database/           # 数据库管理
│   ├── Repository/         # 仓库实现
│   └── GitHub/             # GitHub API 客户端
├── SyncEngine/             # 同步引擎核心
├── Presentation/
│   ├── Library/            # 书架
│   ├── Reader/             # 阅读器
│   ├── Editor/             # 编辑器
│   ├── Sync/               # 同步界面
│   └── Settings/           # 设置
└── Foundation/             # 工具类与扩展
```

## 同步机制说明

### 双向同步流程
1. 检查登录状态和仓库配置
2. 确保仓库存在（不存在则自动创建私有仓库）
3. 自动检测仓库默认分支（main / master / 其他）
4. 拉取远端完整文件树（Git Data API 递归 Tree）
5. 获取本地所有书籍、章节、阅读进度、书签
6. 生成本地 Manifest 与远端 Manifest，对比差异
7. 下载远端新增/更新的章节到本地（优先 remotePath 匹配，回退 sortOrder）
8. 收集本地新增/修改的章节，连同书籍元数据批量上传（一次 commit）
9. 冲突处理：双方都修改的章节保留本地版本上传，并记录冲突项到数据库
10. 同步阅读进度（last write wins，按书籍+章节匹配）
11. 同步书签（合并去重，按书籍+章节+字符偏移匹配）
12. 标记已上传章节为已同步（isDirty=false），更新同步元数据

### 差异对比规则
- `added`: 远端有本地没有 → 下载到本地
- `localAdded`: 本地有远端没有 → 上传到远端
- `conflict`: 双方都有但内容不同 → 保留本地版本上传，记录冲突项
- `unchanged`: 内容一致 → 跳过
- `deleted` / `localDeleted`: 删除同步（规划中，当前版本暂不自动删除）

### 章节匹配规则
- 优先使用 `remotePath`（远端文件路径）精确匹配本地章节
- 若本地章节 `remotePath` 为空（旧数据），回退到 `sortOrder`（文件名序号）匹配
- 避免因标题修改导致重复创建章节

### 阅读进度同步规则
- 以 `书籍远端路径 + 章节远端路径` 为关联键
- 双方都有进度时，取 `updatedAt` 较新的一方（last write wins）
- 仅一方有时，直接同步到另一方

### 书签同步规则
- 以 `书籍远端路径 + 章节远端路径 + 字符偏移量` 为去重键
- 同一位置的书签保留本地版本（优先保留本地笔记）
- 远端新增的书签自动写入本地数据库

## CI/CD

- 触发条件：push 到 main 分支 / 手动触发
- 构建环境：macos-latest + Xcode 15.4
- 构建配置：Release / arm64 / 无签名
- 版本号：自动缝九进一（PATCH 0-9 进位）
- 产物：未签名 IPA，上传 Artifacts 保留 90 天

## 版本规划

### v1.1 (当前)
- ✅ 本地书架与章节管理
- ✅ 基础阅读器（字号/主题/翻页/书签/搜索）
- ✅ 基础编辑器（自动保存/字数统计）
- ✅ GitHub PAT 登录
- ✅ 双向同步（上传+下载+冲突处理）
- ✅ Manifest 差异对比增量同步
- ✅ 阅读进度同步（last write wins）
- ✅ 书签同步（合并去重）
- ✅ 书籍元数据同步
- ✅ 阅读统计
- ✅ 自动创建同步仓库
- ✅ 默认分支自动检测
- ✅ 深色模式适配
- ✅ 统一 DesignToken

### v1.2
- 增量同步优化
- 冲突解决界面
- 大纲视图
- 写作专注模式

### v2.0
- 版本历史（基于 Git commits）
- 导出 EPUB/PDF
- OAuth Device Flow 登录

## 许可证

MIT License
