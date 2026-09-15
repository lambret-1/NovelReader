import Foundation
import Combine

/// GitHub Git Data API 服务 - 负责 Blob/Tree/Commit/Ref 操作
final class GitHubGitService {
    private let apiClient: GitHubAPIClient

    init(apiClient: GitHubAPIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Ref（分支引用）

    /// 获取分支引用
    func getRef(owner: String, repo: String, ref: String = "heads/main") -> AnyPublisher<GitRef, Error> {
        apiClient.get("/repos/\(owner)/\(repo)/git/ref/\(ref)")
    }

    /// 更新分支引用（指向新的 commit）
    func updateRef(owner: String, repo: String, ref: String = "heads/main", sha: String) -> AnyPublisher<GitRef, Error> {
        let body = UpdateRefRequest(sha: sha, force: false)
        return apiClient.patch("/repos/\(owner)/\(repo)/git/refs/\(ref)", body: body)
    }

    // MARK: - Blob（文件内容）

    /// 创建 Blob
    func createBlob(owner: String, repo: String, content: String, encoding: String = "utf-8") -> AnyPublisher<GitObject, Error> {
        let body = CreateBlobRequest(content: content, encoding: encoding)
        return apiClient.post("/repos/\(owner)/\(repo)/git/blobs", body: body)
    }

    /// 获取 Blob 内容
    func getBlob(owner: String, repo: String, sha: String) -> AnyPublisher<GitBlob, Error> {
        apiClient.get("/repos/\(owner)/\(repo)/git/blobs/\(sha)")
    }

    // MARK: - Tree（文件树）

    /// 获取递归文件树
    func getTree(owner: String, repo: String, sha: String, recursive: Bool = true) -> AnyPublisher<GitTree, Error> {
        let params = recursive ? ["recursive": "1"] : nil
        return apiClient.get("/repos/\(owner)/\(repo)/git/trees/\(sha)", parameters: params)
    }

    /// 创建 Tree（基于已有 base tree，添加/更新文件）
    func createTree(owner: String, repo: String, baseTree: String?, items: [CreateTreeItem]) -> AnyPublisher<GitTree, Error> {
        let body = CreateTreeRequest(baseTree: baseTree, tree: items)
        return apiClient.post("/repos/\(owner)/\(repo)/git/trees", body: body)
    }

    // MARK: - Commit

    /// 创建 Commit
    func createCommit(owner: String, repo: String, message: String, treeSHA: String, parentSHAs: [String]) -> AnyPublisher<GitCommit, Error> {
        let body = CreateCommitRequest(message: message, tree: treeSHA, parents: parentSHAs)
        return apiClient.post("/repos/\(owner)/\(repo)/git/commits", body: body)
    }

    // MARK: - 批量提交便捷方法

    /// 批量提交多个文件（一次 commit）
    /// - Parameters:
    ///   - files: 要提交的文件 [路径: 内容]
    ///   - message: commit 信息
    func commitFiles(owner: String,
                     repo: String,
                     files: [String: String],
                     message: String,
                     branch: String = "main") -> AnyPublisher<GitCommit, Error> {

        return getRef(owner: owner, repo: repo, ref: "heads/\(branch)")
            .flatMap { ref -> AnyPublisher<(GitRef, GitTree), Error> in
                // 获取当前 tree
                self.getTree(owner: owner, repo: repo, sha: ref.object.sha)
                    .map { (ref, $0) }
                    .eraseToAnyPublisher()
            }
            .flatMap { ref, currentTree -> AnyPublisher<(GitRef, GitTree), Error> in
                // 为每个文件创建 blob
                let blobPublishers = files.map { path, content in
                    self.createBlob(owner: owner, repo: repo, content: content)
                        .map { (path, $0.sha) }
                        .eraseToAnyPublisher()
                }

                return Publishers.MergeMany(blobPublishers)
                    .collect()
                    .flatMap { pathSHAs -> AnyPublisher<GitTree, Error> in
                        let items = pathSHAs.map { path, sha in
                            CreateTreeItem(path: path, mode: "100644", type: "blob", sha: sha, content: nil)
                        }
                        return self.createTree(owner: owner, repo: repo, baseTree: currentTree.sha, items: items)
                    }
                    .map { (ref, $0) }
                    .eraseToAnyPublisher()
            }
            .flatMap { ref, newTree -> AnyPublisher<GitCommit, Error> in
                // 创建 commit
                self.createCommit(owner: owner, repo: repo,
                                  message: message,
                                  treeSHA: newTree.sha,
                                  parentSHAs: [ref.object.sha])
            }
            .flatMap { commit -> AnyPublisher<GitCommit, Error> in
                // 更新分支引用
                self.updateRef(owner: owner, repo: repo, ref: "heads/\(branch)", sha: commit.sha)
                    .map { _ in commit }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
