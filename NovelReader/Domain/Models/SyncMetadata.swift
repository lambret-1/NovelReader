import Foundation

/// 同步元数据（单例）
struct SyncMetadata: Codable, Equatable {
    /// 固定 ID
    static let sharedID = "singleton"

    let id: String
    /// 上次同步时的远端 commit SHA
    var lastSyncCommitSHA: String?
    var lastSyncAt: Date?
    /// 本地 manifest 版本号
    var localManifestVersion: Int
    /// GitHub 用户名
    var githubUsername: String?
    /// 同步仓库全名 owner/repo
    var repoFullName: String?

    init(id: String = SyncMetadata.sharedID,
         lastSyncCommitSHA: String? = nil,
         lastSyncAt: Date? = nil,
         localManifestVersion: Int = 1,
         githubUsername: String? = nil,
         repoFullName: String? = nil) {
        self.id = id
        self.lastSyncCommitSHA = lastSyncCommitSHA
        self.lastSyncAt = lastSyncAt
        self.localManifestVersion = localManifestVersion
        self.githubUsername = githubUsername
        self.repoFullName = repoFullName
    }

    static var `default` = SyncMetadata()
}

/// 冲突项
struct ConflictItem: Codable, Equatable, Identifiable {
    let id: String
    /// 冲突类型
    let type: ConflictType
    /// 本地文件路径
    let localPath: String
    /// 远端文件路径
    let remotePath: String
    /// 本地内容（可选，大文件可能不存）
    var localContent: String?
    /// 远端内容
    var remoteContent: String?
    /// 用户选择的解决方案
    var resolution: ConflictResolution?

    enum ConflictType: String, Codable {
        case contentModified  // 双方都修改了内容
        case rename           // 重命名冲突
        case delete           // 删除冲突（本地删了远端改了）
    }

    enum ConflictResolution: String, Codable {
        case keepLocal    // 保留本地
        case keepRemote   // 保留远端
        case keepBoth     // 保留双方
        case manual       // 手动合并
    }

    init(id: String = UUID().uuidString,
         type: ConflictType,
         localPath: String,
         remotePath: String,
         localContent: String? = nil,
         remoteContent: String? = nil,
         resolution: ConflictResolution? = nil) {
        self.id = id
        self.type = type
        self.localPath = localPath
        self.remotePath = remotePath
        self.localContent = localContent
        self.remoteContent = remoteContent
        self.resolution = resolution
    }
}
