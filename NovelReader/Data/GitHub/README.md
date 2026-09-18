# Data/GitHub GitHub 数据层

## 模块概述

本模块封装 GitHub REST API 与 Git Data API 的客户端实现，负责认证、文件读写、仓库管理、批量提交等能力，为 SyncEngine 提供底层数据访问。

## 文件清单

| 文件 | 职责 |
|---|---|
| `GitHubAPIClient.swift` | API 客户端基础封装：请求构建、Token 管理、限流追踪、错误处理 |
| `GitHubAuthService.swift` | 认证服务：PAT 登录验证、Token 持久化（Keychain）、登出、用户信息获取 |
| `GitHubFileService.swift` | 文件服务：单文件读写、仓库文件树获取、批量提交、仓库创建与存在性检查 |
| `GitHubGitService.swift` | Git Data API 服务：Blob/Tree/Commit/Ref 操作、批量提交（含文件删除） |
| `UpdateCheckService.swift` | 应用更新检查：查询最新 Release、版本比较、IPA 下载 |
| `Models/GitHubModels.swift` | GitHub API 响应模型与请求体模型 |

## 批量提交（Git Data API）

### 流程

```
获取默认分支 → 获取分支 Ref → 获取当前 Tree
    → 为每个文件创建 Blob → 基于 base_tree 创建新 Tree（含删除条目）
    → 创建 Commit（parent 为当前 Ref SHA）→ 更新分支 Ref 指向新 Commit
```

### 文件删除支持

`CreateTreeItem` 支持两种条目类型：

- **普通文件条目**（`fileItem(path:sha:)`）：`mode=100644, type=blob, sha=xxx`，新增或修改文件
- **删除条目**（`deleteItem(path:)`）：仅编码 `path`，其余字段省略，GitHub API 会从 `base_tree` 中移除该路径

### 调用入口

```swift
// GitHubFileService（推荐，自动检测默认分支）
fileService.writeFiles(
    owner: owner,
    repo: repo,
    files: ["路径": "内容"],
    deletedPaths: ["待删除路径"],  // 可选
    message: "commit 信息"
)

// GitHubGitService（底层，需自行处理分支）
gitService.commitFiles(owner:repo:files:deletedPaths:message:branch:)
```

## 认证与 Token

- Token 存储于 Keychain（key: `github_personal_access_token`）
- `AppDelegate` 启动时自动从 Keychain 恢复 Token 到 `GitHubAPIClient`
- 每次请求前若 `token == nil`，会自动尝试从 Keychain 恢复（兜底）
- 认证状态通过 `apiClient.isAuthenticated` 判断

## 错误类型

`GitHubError` 枚举：

| 错误 | 说明 |
|---|---|
| `invalidURL` | URL 构建失败 |
| `invalidResponse` | 响应非 HTTP |
| `httpError(statusCode:)` | HTTP 错误（非 2xx） |
| `apiError(message:statusCode:)` | GitHub API 业务错误（含错误消息） |
| `rateLimitExceeded(resetTime:)` | API 限流（403 + remaining=0） |
| `unauthorized` | 未授权 |
| `repositoryNotFound` | 仓库不存在 |
| `fileNotFound` | 文件不存在 |

## 限流追踪

`GitHubAPIClient` 自动从响应头解析并更新：
- `rateLimitRemaining` — 剩余请求数
- `rateLimitReset` — 限流重置时间戳

## 仓库存在性保证

`ensureRepositoryExists(owner:repo:description:)`：
1. 先调用 `getRepository` 检查仓库是否存在
2. 若返回 404，则自动调用 `createRepository` 创建私有仓库（`auto_init=true`）
3. 其他错误直接抛出

## 注意事项

1. **Token 一致性**：`GitHubFileService` 初始化时若未传入 `gitService`，会使用同一个 `apiClient` 创建，避免 Token 丢失
2. **空仓库**：空仓库（无 commit）调用 Git Data API 会返回 409，SyncEngine 已处理此场景
3. **大文件**：单文件内容通过 Contents API 读取时 GitHub 有 1MB 限制，大文件应使用 Blob SHA 方式（`getBlobContent`）
4. **更新检查**：`UpdateCheckService` 硬编码检查 `lambret-1/NovelReader` 仓库的 Release，与同步仓库无关
