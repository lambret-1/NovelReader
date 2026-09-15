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
- 四种主题：日间、夜间、护眼、羊皮纸
- 左右滑动切换章节
- 点击屏幕显示/隐藏设置面板

### ☁️ GitHub 云同步
- Personal Access Token 登录
- 基于 Git Data API 的批量提交（一次 commit 多个文件）
- Manifest 差异对比，增量同步
- 冲突检测与提示
- 同步状态实时展示
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
│  Manifest 对比 / 冲突检测 / 批量提交     │
└─────────────────────────────────────────┘
```

### 技术栈
- **语言**: Swift 5
- **最低系统**: iOS 14.0
- **UI**: UIKit（程序式布局，无 Storyboard 依赖）
- **响应式**: Combine
- **数据库**: GRDB.swift (SQLite)
- **网络**: URLSession + 自定义封装
- **依赖注入**: 手写 AppContainer
- **存储**: Keychain (Token) / UserDefaults (偏好)

### GitHub 仓库结构
同步时在用户 GitHub 仓库中创建以下结构：
```
NovelReader/
├── .novel-sync/
│   └── manifest.json          # 文件清单与 hash
├── 书名/
│   ├── meta.json              # 书籍元数据
│   ├── 001_第一章.md           # 章节内容（Markdown）
│   └── 002_第二章.md
└── README.md
```

## 快速开始

### 环境要求
- Xcode 14.0+
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
4. 点击「立即同步」开始同步

## 项目结构

```
NovelReader/
├── App/                    # 应用入口与依赖注入
├── Configuration/          # 全局配置与主题
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

## 版本规划

### v1.0 (当前)
- ✅ 本地书架与章节管理
- ✅ 基础阅读器（字号/主题/翻页）
- ✅ 基础编辑器（自动保存/字数统计）
- ✅ GitHub PAT 登录
- ✅ 全量同步 + 冲突检测

### v1.1
- 增量同步优化
- 冲突解决界面
- 书签与阅读进度同步
- 大纲视图

### v2.0
- 版本历史（基于 Git commits）
- 导出 EPUB/PDF
- 写作专注模式
- OAuth Device Flow 登录

## 许可证

MIT License
