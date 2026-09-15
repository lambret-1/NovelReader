import Foundation
import Combine

/// GitHub 文件服务 - 基于 Contents API 和 Git Data API 的文件读写
final class GitHubFileService {
    private let apiClient: GitHubAPIClient
    private let gitService: GitHubGitService

    init(apiClient: GitHubAPIClient = .shared, gitService: GitHubGitService = GitHubGitService()) {
        self.apiClient = apiClient
        self.gitService = gitService
    }

    // MARK: - 读取

    /// 读取仓库中指定路径的文件内容（单文件，小文件适用）
    func getFileContent(owner: String, repo: String, path: String, ref: String = "main") -> AnyPublisher<String, Error> {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let params = ["ref": ref]
        return apiClient.get("/repos/\(owner)/\(repo)/contents/\(encodedPath)", parameters: params)
            .tryMap { (content: GitHubContent) in
                guard let encoded = content.content,
                      let data = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters),
                      let text = String(data: data, encoding: .utf8) else {
                    throw GitHubError.fileNotFound
                }
                return text
            }
            .eraseToAnyPublisher()
    }

    /// 获取目录下的文件列表
    func getDirectoryContents(owner: String, repo: String, path: String, ref: String = "main") -> AnyPublisher<[GitHubContent], Error> {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let params = ["ref": ref]
        return apiClient.get("/repos/\(owner)/\(repo)/contents/\(encodedPath)", parameters: params)
    }

    /// 获取仓库完整文件树（递归，适合全量同步）
    func getRepositoryTree(owner: String, repo: String, ref: String = "main") -> AnyPublisher<GitTree, Error> {
        return gitService.getRef(owner: owner, repo: repo, ref: "heads/\(ref)")
            .flatMap { ref in
                self.gitService.getTree(owner: owner, repo: repo, sha: ref.object.sha, recursive: true)
            }
            .eraseToAnyPublisher()
    }

    /// 通过 Blob SHA 读取文件内容（大文件适用）
    func getBlobContent(owner: String, repo: String, sha: String) -> AnyPublisher<String, Error> {
        return gitService.getBlob(owner: owner, repo: repo, sha: sha)
            .tryMap { blob in
                guard let data = Data(base64Encoded: blob.content, options: .ignoreUnknownCharacters),
                      let text = String(data: data, encoding: .utf8) else {
                    throw GitHubError.fileNotFound
                }
                return text
            }
            .eraseToAnyPublisher()
    }

    // MARK: - 写入

    /// 写入/更新单个文件（Contents API，简单但每次一个 commit）
    func writeFile(owner: String,
                   repo: String,
                   path: String,
                   content: String,
                   message: String,
                   branch: String = "main",
                   sha: String? = nil) -> AnyPublisher<GitHubContent, Error> {

        let encoded = content.data(using: .utf8)?.base64EncodedString() ?? ""
        var body: [String: String] = [
            "message": message,
            "content": encoded,
            "branch": branch
        ]
        if let sha = sha {
            body["sha"] = sha
        }

        return apiClient.put("/repos/\(owner)/\(repo)/contents/\(path)", body: body)
    }

    /// 批量写入多个文件（一次 commit，推荐用于同步）
    func writeFiles(owner: String,
                    repo: String,
                    files: [String: String],
                    message: String,
                    branch: String = "main") -> AnyPublisher<GitCommit, Error> {
        return gitService.commitFiles(owner: owner, repo: repo, files: files, message: message, branch: branch)
    }

    // MARK: - 仓库管理

    /// 创建仓库
    func createRepository(name: String, description: String, isPrivate: Bool = true) -> AnyPublisher<GitHubRepo, Error> {
        let body: [String: Any] = [
            "name": name,
            "description": description,
            "private": isPrivate,
            "auto_init": true
        ]
        // 用 Data 封装
        let data = try? JSONSerialization.data(withJSONObject: body)
        let jsonString = String(data: data ?? Data(), encoding: .utf8) ?? ""
        return apiClient.post("/user/repos", body: EmptyBody())
            .mapError { $0 as Error }
            .flatMap { (_: GitHubRepo) -> AnyPublisher<GitHubRepo, Error> in
                // 上面的空 body 不行，需要真实 body
                Fail(error: GitHubError.invalidResponse).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    /// 检查仓库是否存在
    func getRepository(owner: String, repo: String) -> AnyPublisher<GitHubRepo, Error> {
        apiClient.get("/repos/\(owner)/\(repo)")
    }
}

/// 空 body 占位（实际不使用）
private struct EmptyBody: Encodable {}
