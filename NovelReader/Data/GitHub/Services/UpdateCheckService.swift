import Foundation
import Combine

/// 最新版本信息
struct LatestRelease: Decodable {
    let tagName: String          // 标签名，如 v1.3.3
    let name: String             // 发布名称
    let body: String?            // 发布说明
    let htmlUrl: String          // 发布页面 URL
    let assets: [ReleaseAsset]   // 附件列表
    let publishedAt: String      // 发布时间

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body, assets
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
    }
}

/// Release 附件
struct ReleaseAsset: Decodable {
    let name: String             // 文件名
    let browserDownloadUrl: String // 下载 URL
    let size: Int                // 文件大小（字节）

    enum CodingKeys: String, CodingKey {
        case name, size
        case browserDownloadUrl = "browser_download_url"
    }
}

/// 更新检查结果
enum UpdateCheckResult {
    case noUpdate                 // 已是最新版本
    case updateAvailable(LatestRelease) // 有新版本
    case checkFailed(Error)       // 检查失败
}

/// 更新检查服务 - 负责检查 GitHub 最新 Release
final class UpdateCheckService {
    private let apiClient: GitHubAPIClient
    private let owner: String
    private let repo: String

    /// 初始化
    /// - Parameters:
    ///   - apiClient: GitHub API 客户端
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    init(apiClient: GitHubAPIClient = .shared, owner: String = "lambret-1", repo: String = "NovelReader") {
        self.apiClient = apiClient
        self.owner = owner
        self.repo = repo
    }

    /// 检查最新版本
    /// - Returns: 发布者，输出最新 Release 信息
    func checkForUpdates() -> AnyPublisher<LatestRelease, Error> {
        let endpoint = "/repos/\(owner)/\(repo)/releases/latest"
        return apiClient.get(endpoint)
    }

    /// 比较版本号，判断是否有更新
    /// - Parameters:
    ///   - latest: 最新版本信息
    ///   - currentVersion: 当前应用版本
    /// - Returns: 是否有新版本
    func hasUpdate(latest: LatestRelease, currentVersion: String) -> Bool {
        // 去掉 tag 前缀 "v"，如 "v1.3.3" -> "1.3.3"
        let latestVersion = latest.tagName.hasPrefix("v")
            ? String(latest.tagName.dropFirst())
            : latest.tagName

        let latestParts = latestVersion.split(separator: ".").compactMap { Int($0) }
        let currentParts = currentVersion.split(separator: ".").compactMap { Int($0) }

        guard latestParts.count == 3, currentParts.count == 3 else {
            return false
        }

        // 逐位比较
        for i in 0..<3 {
            if latestParts[i] > currentParts[i] {
                return true
            } else if latestParts[i] < currentParts[i] {
                return false
            }
        }
        return false
    }

    /// 获取 IPA 下载 URL
    /// - Parameter release: Release 信息
    /// - Returns: IPA 下载 URL，如果没有则返回 nil
    func ipaDownloadUrl(from release: LatestRelease) -> URL? {
        guard let asset = release.assets.first(where: { $0.name.hasSuffix(".ipa") }) else {
            return nil
        }
        return URL(string: asset.browserDownloadUrl)
    }

    /// 下载 IPA 文件
    /// - Parameters:
    ///   - url: 下载 URL
    ///   - progress: 进度回调（0.0 - 1.0）
    /// - Returns: 发布者，输出下载完成的本地文件 URL
    func downloadIPA(url: URL, progress: @escaping (Double) -> Void) -> AnyPublisher<URL, Error> {
        return Future { promise in
            let task = URLSession.shared.downloadTask(with: url) { tempUrl, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let tempUrl = tempUrl else {
                    promise(.failure(NSError(domain: "UpdateCheckService", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载失败"])))
                    return
                }
                // 移动到临时目录，保持文件名
                let destination = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.moveItem(at: tempUrl, to: destination)
                    promise(.success(destination))
                } catch {
                    promise(.failure(error))
                }
            }
            // 观察下载进度
            let observation = task.progress.observe(\.fractionCompleted) { prog, _ in
                DispatchQueue.main.async {
                    progress(prog.fractionCompleted)
                }
            }
            task.resume()
            // 保持 observation 存活
            objc_setAssociatedObject(task, &UpdateCheckService.observationKey, observation, .OBJC_ASSOCIATION_RETAIN)
        }.eraseToAnyPublisher()
    }

    private static var observationKey: UInt8 = 0
}
