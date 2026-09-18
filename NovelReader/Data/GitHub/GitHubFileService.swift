import Foundation
import Combine

/// GitHub 文件服务 - 基于 Contents API 和 Git Data API 的文件读写
final class GitHubFileService {
    private let apiClient: GitHubAPIClient
    private let gitService: GitHubGitService

    init(apiClient: GitHubAPIClient = .shared, gitService: GitHubGitService? = nil) {
        self.apiClient = apiClient
        // 关键修复：如果外部未传入 gitService，则使用同一个 apiClient 创建，
        // 避免 gitService 内部使用 .shared 单例导致 Token 丢失
        self.gitService = gitService ?? GitHubGitService(apiClient: apiClient)
    }

    // MARK: - 读取

    /// 读取仓库中指定路径的文件内容（单文件，小文件适用）
    func getFileContent(owner: String, repo: String, path: String, ref: String? = nil) -> AnyPublisher<String, Error> {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        var params: [String: String] = [:]
        if let ref = ref { params["ref"] = ref }
        return apiClient.get("/repos/\(owner)/\(repo)/contents/\(encodedPath)", parameters: params.isEmpty ? nil : params)
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
    func getDirectoryContents(owner: String, repo: String, path: String, ref: String? = nil) -> AnyPublisher<[GitHubContent], Error> {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        var params: [String: String] = [:]
        if let ref = ref { params["ref"] = ref }
        return apiClient.get("/repos/\(owner)/\(repo)/contents/\(encodedPath)", parameters: params.isEmpty ? nil : params)
    }

    /// 获取仓库完整文件树（递归，自动检测默认分支）
    func getRepositoryTree(owner: String, repo: String, branch: String? = nil) -> AnyPublisher<GitTree, Error> {
        let branchPublisher: AnyPublisher<String, Error>
        if let branch = branch {
            branchPublisher = Just(branch).setFailureType(to: Error.self).eraseToAnyPublisher()
        } else {
            branchPublisher = gitService.getDefaultBranch(owner: owner, repo: repo).eraseToAnyPublisher()
        }
        return branchPublisher
            .flatMap { branch in
                self.gitService.getBranchRef(owner: owner, repo: repo, branch: branch)
                    .flatMap { ref in
                        self.gitService.getTree(owner: owner, repo: repo, sha: ref.object.sha, recursive: true)
                    }
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

    /// 写入/更新单个文件（Contents API，每次一个 commit）
    func writeFile(owner: String,
                   repo: String,
                   path: String,
                   content: String,
                   message: String,
                   branch: String? = nil,
                   sha: String? = nil) -> AnyPublisher<GitHubContent, Error> {

        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let encoded = content.data(using: .utf8)?.base64EncodedString() ?? ""
        var body: [String: String] = [
            "message": message,
            "content": encoded
        ]
        if let branch = branch {
            body["branch"] = branch
        }
        if let sha = sha {
            body["sha"] = sha
        }

        return apiClient.put("/repos/\(owner)/\(repo)/contents/\(encodedPath)", body: body)
    }

    /// 批量写入多个文件（一次 commit，自动检测默认分支，推荐用于同步），支持文件删除
    func writeFiles(owner: String,
                    repo: String,
                    files: [String: String],
                    deletedPaths: [String] = [],
                    message: String,
                    branch: String? = nil) -> AnyPublisher<GitCommit, Error> {
        return gitService.commitFiles(owner: owner, repo: repo, files: files, deletedPaths: deletedPaths, message: message, branch: branch)
    }

    // MARK: - 仓库管理

    /// 创建仓库（正确实现）
    func createRepository(name: String, description: String, isPrivate: Bool = true) -> AnyPublisher<GitHubRepo, Error> {
        let body = CreateRepoRequest(name: name, description: description, isPrivate: isPrivate, autoInit: true)
        return apiClient.post("/user/repos", body: body)
    }

    /// 检查仓库是否存在，不存在则自动创建
    func ensureRepositoryExists(owner: String, repo: String, description: String = "小说阅读云同步仓库") -> AnyPublisher<GitHubRepo, Error> {
        return getRepository(owner: owner, repo: repo)
            .catch { error -> AnyPublisher<GitHubRepo, Error> in
                if case let GitHubError.apiError(_, statusCode) = error, statusCode == 404 {
                    return self.createRepository(name: repo, description: description, isPrivate: true)
                }
                if case let GitHubError.httpError(statusCode) = error, statusCode == 404 {
                    return self.createRepository(name: repo, description: description, isPrivate: true)
                }
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    /// 检查仓库是否存在
    func getRepository(owner: String, repo: String) -> AnyPublisher<GitHubRepo, Error> {
        apiClient.get("/repos/\(owner)/\(repo)")
    }
}

// MARK: - 创建仓库请求体
private struct CreateRepoRequest: Codable {
    let name: String
    let description: String
    let isPrivate: Bool
    let autoInit: Bool

    enum CodingKeys: String, CodingKey {
        case name, description
        case isPrivate = "private"
        case autoInit = "auto_init"
    }
}
