import Foundation
import Combine

/// 同步结果
struct SyncResult: Equatable {
    let success: Bool
    let downloadedCount: Int
    let message: String
}

/// 同步状态（仅下载同步）
enum SyncStatus: Equatable {
    case idle
    case pulling(progress: Double)
    case merging
    case error(message: String)

    var isSyncing: Bool {
        switch self {
        case .pulling, .merging: return true
        default: return false
        }
    }
}

/// 同步引擎协议（仅下载同步）
protocol SyncEngineProtocol {
    var currentStatus: SyncStatus { get }
    var statusPublisher: AnyPublisher<SyncStatus, Never> { get }
    func startSync() -> AnyPublisher<SyncResult, Error>
}
