import Foundation
import Combine

/// 触发同步
struct TriggerSyncUseCase {
    private let syncEngine: SyncEngineProtocol

    init(syncEngine: SyncEngineProtocol) {
        self.syncEngine = syncEngine
    }

    func execute() -> AnyPublisher<SyncResult, Error> {
        syncEngine.startSync()
    }
}

/// 获取同步状态
struct GetSyncStatusUseCase {
    private let syncEngine: SyncEngineProtocol

    init(syncEngine: SyncEngineProtocol) {
        self.syncEngine = syncEngine
    }

    func execute() -> SyncStatus {
        syncEngine.currentStatus
    }
}

/// 解决冲突
struct ResolveConflictUseCase {
    private let syncEngine: SyncEngineProtocol

    init(syncEngine: SyncEngineProtocol) {
        self.syncEngine = syncEngine
    }

    func execute(conflictId: String, resolution: ConflictItem.ConflictResolution) -> AnyPublisher<Void, Error> {
        syncEngine.resolveConflict(conflictId: conflictId, resolution: resolution)
    }
}

/// 同步结果
struct SyncResult: Equatable {
    let success: Bool
    let uploadedCount: Int
    let downloadedCount: Int
    let conflictCount: Int
    let message: String
}

/// 同步状态
enum SyncStatus: Equatable {
    case idle
    case pulling(progress: Double)
    case merging
    case pushing(progress: Double)
    case conflictWaiting(count: Int)
    case error(message: String)

    var isSyncing: Bool {
        switch self {
        case .pulling, .merging, .pushing: return true
        default: return false
        }
    }
}

/// 同步引擎协议
protocol SyncEngineProtocol {
    var currentStatus: SyncStatus { get }
    var statusPublisher: AnyPublisher<SyncStatus, Never> { get }
    func startSync() -> AnyPublisher<SyncResult, Error>
    func resolveConflict(conflictId: String, resolution: ConflictItem.ConflictResolution) -> AnyPublisher<Void, Error>
}
