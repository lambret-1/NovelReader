import Foundation
import Combine

/// 最新版本信息
struct LatestRelease: Decodable {
    let tagName: String
    let name: String
    let body: String?
    let htmlUrl: String
    let assets: [ReleaseAsset]
    let publishedAt: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body, assets
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
    }
}

/// Release 附件
struct ReleaseAsset: Decodable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name, size
        case browserDownloadUrl = "browser_download_url"
    }
}

/// 更新检查服务
final class UpdateCheckService {
    private let apiClient: GitHubAPIClient
    private let owner: String
    private let repo: String

    init(apiClient: GitHubAPIClient = .shared, owner: String = "lambret-1", repo: String = "NovelReader") {
        self.apiClient = apiClient
        self.owner = owner
        self.repo = repo
    }

    func checkForUpdates() -> AnyPublisher<LatestRelease, Error> {
        let endpoint = "/repos/\(owner)/\(repo)/releases/latest"
        return apiClient.get(endpoint)
    }

    func hasUpdate(latest: LatestRelease, currentVersion: String) -> Bool {
        let latestVersion = latest.tagName.hasPrefix("v")
            ? String(latest.tagName.dropFirst())
            : latest.tagName

        let latestParts = latestVersion.split(separator: ".").compactMap { Int($0) }
        let currentParts = currentVersion.split(separator: ".").compactMap { Int($0) }

        guard latestParts.count == 3, currentParts.count == 3 else {
            return false
        }

        for i in 0..<3 {
            if latestParts[i] > currentParts[i] {
                return true
            } else if latestParts[i] < currentParts[i] {
                return false
            }
        }
        return false
    }

    func ipaDownloadUrl(from release: LatestRelease) -> URL? {
        guard let asset = release.assets.first(where: { $0.name.hasSuffix(".ipa") }) else {
            return nil
        }
        return URL(string: asset.browserDownloadUrl)
    }

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
            let observation = task.progress.observe(\.fractionCompleted) { prog, _ in
                DispatchQueue.main.async {
                    progress(prog.fractionCompleted)
                }
            }
            task.resume()
            objc_setAssociatedObject(task, &UpdateCheckService.observationKey, observation, .OBJC_ASSOCIATION_RETAIN)
        }.eraseToAnyPublisher()
    }

    private static var observationKey: UInt8 = 0
}
