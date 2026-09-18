# SyncEngine 同步引擎模块

## 模块概述

本模块负责小说阅读器的 GitHub 云同步核心逻辑，实现**双向同步**（本地 ↔ 云端），涵盖书籍章节、阅读进度、书签的同步与冲突处理。

## 文件清单

| 文件 | 职责 |
|---|---|
| `SyncEngine.swift` | 同步引擎主类，双向同步流程编排、差异处理、上传下载、进度书签同步 |
| `ManifestManager.swift` | Manifest 生成与差异对比、章节 Markdown 序列化、阅读进度/书签 JSON 序列化 |
| `NovelRefreshService.swift` | 备用下载服务（书架页 API 刷新入口，硬编码作者仓库，仅作备用） |

## 双向同步流程

```
开始同步
  │
  ├─ 1. 检查认证状态 & 同步中互斥
  ├─ 2. 获取同步元数据，解析仓库 owner/repo
  ├─ 3. 确保仓库存在（不存在则自动创建私有仓库）
  ├─ 4. 拉取远端完整文件树（Git Data API 递归 Tree）
  ├─ 5. 获取本地全部数据（书籍/章节/阅读进度/书签）
  ├─ 6. 生成本地 Manifest 与远端 Manifest，差异对比
  ├─ 7. 下载远端新增章节到本地（remotePath 优先匹配，sortOrder 回退）
  ├─ 8. 下载远端书籍元数据（更新 title/author，sortOrder 保持本地优先）
  ├─ 9. 收集待上传文件（本地新增 + 冲突保留本地 + 全部书籍 meta.json）
  ├─ 10. 批量提交上传（Git Data API 一次 commit）
  ├─ 11. 标记已上传章节 isDirty=false，设置 remotePath
  ├─ 12. 同步阅读进度（last write wins）
  ├─ 13. 同步书签（合并去重）
  ├─ 14. 更新同步元数据（lastSyncAt / lastSyncCommitSHA）
  └─ 返回同步结果
```

## 差异对比规则

| 差异类型 | 含义 | 处理策略 |
|---|---|---|
| `added` | 远端有、本地没有 | 下载到本地 |
| `localAdded` | 本地有、远端没有 | 上传到远端 |
| `conflict` | 双方都有但内容不同 | 保留本地版本上传，记录冲突项到数据库 |
| `unchanged` | 内容一致 | 跳过 |
| `deleted` / `localDeleted` | 删除同步 | 规划中，当前版本暂不自动删除 |

## 章节匹配策略

下载远端章节时，按以下优先级匹配本地章节：

1. **remotePath 精确匹配**：`chapter.remotePath == 远端文件路径`（最可靠）
2. **sortOrder 回退匹配**：从文件名提取章节序号，匹配 `chapter.sortOrder`
3. **创建新章节**：均匹配不到时，按序号创建新章节

> 设计说明：优先使用 remotePath 是因为它是稳定的文件路径标识，不受章节标题修改和排序变动影响。sortOrder 仅作为旧数据（remotePath 为空）的兜底。

## 阅读进度同步

- **关联键**：`书籍远端路径 + 章节远端路径`
- **合并策略**：last write wins（取 `updatedAt` 较新的一方）
- **存储位置**：`.novel-sync/progress.json`
- **数据结构**：`RemoteReadingProgressFile` → `[RemoteReadingProgress]`

## 书签同步

- **关联键**：`书籍远端路径 + 章节远端路径 + 字符偏移量`
- **合并策略**：合并去重，同一位置保留本地版本（优先保留本地笔记）
- **存储位置**：`.novel-sync/bookmarks.json`
- **数据结构**：`RemoteBookmarkFile` → `[RemoteBookmark]`

## 冲突处理

- 检测到双方都修改的章节时，**保留本地版本上传**（本地是用户正在编辑的内容）
- 同时将冲突记录写入 `ConflictRepository`，供后续冲突解决界面使用
- 冲突项记录：`type=contentModified`、`localPath`、`remotePath`

## 空仓库处理

- 拉取远端文件树时，若 GitHub 返回 409（空仓库），则跳过下载流程
- 直接执行本地上传，将本地数据推送到空仓库
- 判断基于 `GitHubError.apiError(_, statusCode)` 的状态码，而非本地化错误字符串

## 批量提交

- 使用 Git Data API 实现一次 commit 提交多个文件
- 流程：创建 Blobs → 基于 base_tree 创建 Tree → 创建 Commit → 更新分支 Ref
- 支持文件删除（`CreateTreeItem.deleteItem`，仅编码 path，GitHub API 会从 base_tree 移除该路径）
- 当前 P0 版本上传不包含删除，删除同步留待后续版本

## 依赖注入

`SyncEngine` 通过构造函数注入以下依赖（`AppContainer` 统一装配）：

- `BookRepositoryProtocol` — 书籍数据读写
- `ChapterRepositoryProtocol` — 章节数据读写
- `SyncMetadataRepositoryProtocol` — 同步元数据读写
- `ReadingProgressRepositoryProtocol?` — 阅读进度读写（可选）
- `BookmarkRepositoryProtocol?` — 书签读写（可选）
- `ConflictRepositoryProtocol?` — 冲突项读写（可选）
- `GitHubFileService` — GitHub 文件读写
- `GitHubAPIClient` — GitHub API 客户端（用于认证状态检查）

## 状态发布

`SyncEngine` 通过 `@Published currentStatus` 发布同步状态，UI 层通过 Combine 订阅：

- `.idle` — 空闲/同步完成
- `.pulling(progress: Double)` — 下载中（0.0~1.0）
- `.pushing(progress: Double)` — 上传中（0.0~1.0）
- `.merging` — 合并处理中
- `.error(message: String)` — 同步失败

## 注意事项

1. **书籍排序保持本地优先**：下载远端 meta.json 时不更新 `sortOrder`，避免打乱用户本地排序
2. **NovelRefreshService 为备用**：书架页的"API 刷新书籍"使用独立的下载服务，硬编码作者仓库，与 SyncEngine 互不干扰
3. **awaitPublisher 模式**：当前使用 `DispatchSemaphore` 阻塞等待 Publisher，后续可重构为 async/await 或纯 Combine 链式
4. **删除同步未实现**：远端删除的书籍/章节当前不会自动删除本地数据，需手动清理
