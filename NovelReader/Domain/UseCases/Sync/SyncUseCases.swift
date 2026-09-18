import Foundation
import Combine

/// 同步结果
struct SyncResult: Equatable {
    let success: Bool
    /// 下载章节数
    let downloadedCount: Int
    /// 上传章节数
    let uploadedCount: Int
    /// 冲突章节数（保留本地版本上传）
    let conflictCount: Int
    /// 同步消息
    let message: String

    init(success: Bool, downloadedCount: Int = 0, uploadedCount: Int = 0, conflictCount: Int = 0, message: String) {
        self.success = success
        self.downloadedCount = downloadedCount
        self.uploadedCount = uploadedCount
        self.conflictCount = conflictCount
        self.message = message
    }
}

/// 同步状态（双向同步：下载 + 上传）
enum SyncStatus: Equatable {
    case idle
    /// 下载中，进度 0.0~1.0
    case pulling(progress: Double)
    /// 上传中，进度 0.0~1.0
    case pushing(progress: Double)
    /// 合并处理中
    case merging
    /// 错误状态
    case error(message: String)

    var isSyncing: Bool {
        switch self {
        case .pulling, .pushing, .merging: return true
        default: return false
        }
    }
}

/// 同步引擎协议（双向同步）
protocol SyncEngineProtocol {
    var currentStatus: SyncStatus { get }
    var statusPublisher: AnyPublisher<SyncStatus, Never> { get }
    func startSync() -> AnyPublisher<SyncResult, Error>
}
