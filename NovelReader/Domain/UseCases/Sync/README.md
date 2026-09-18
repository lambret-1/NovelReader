# Domain/UseCases/Sync 同步领域模型

## 模块概述

本模块定义同步功能的领域模型，包括同步状态、同步结果、同步引擎协议，供 Presentation 层和 SyncEngine 层共同使用。

## 文件清单

| 文件 | 职责 |
|---|---|
| `SyncUseCases.swift` | 同步状态枚举、同步结果结构体、同步引擎协议定义 |

## 同步状态 SyncStatus

```swift
enum SyncStatus: Equatable {
    case idle                          // 空闲/同步完成
    case pulling(progress: Double)    // 下载中，进度 0.0~1.0
    case pushing(progress: Double)    // 上传中，进度 0.0~1.0
    case merging                       // 合并处理中
    case error(message: String)       // 同步失败
}
```

- `isSyncing` 计算属性：`.pulling`、`.pushing`、`.merging` 均视为同步中
- UI 层通过 Combine 订阅 `statusPublisher` 实时更新界面

## 同步结果 SyncResult

```swift
struct SyncResult: Equatable {
    let success: Bool           // 是否成功
    let downloadedCount: Int    // 下载章节数
    let uploadedCount: Int      // 上传章节数
    let conflictCount: Int      // 冲突章节数（保留本地版本）
    let message: String         // 同步消息（用户可见）
}
```

## 同步引擎协议 SyncEngineProtocol

```swift
protocol SyncEngineProtocol {
    var currentStatus: SyncStatus { get }
    var statusPublisher: AnyPublisher<SyncStatus, Never> { get }
    func startSync() -> AnyPublisher<SyncResult, Error>
}
```

- `SyncEngine` 类实现此协议
- `AppContainer` 负责装配并注入依赖
- `SyncViewController` 通过 `AppContainer.shared.syncEngine` 获取实例

## 设计说明

1. **双向同步**：状态区分 `pulling`（下载）和 `pushing`（上传），UI 可分别展示不同图标和文案
2. **冲突计数**：`conflictCount` 单独统计，用户可了解有多少章节发生了冲突并被保留本地版本
3. **协议隔离**：Presentation 层仅依赖协议，不依赖具体实现，便于测试和替换
