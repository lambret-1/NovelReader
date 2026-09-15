import Foundation
import Combine

/// GitHub Git Data API 服务 - 负责 Blob/Tree/Commit/Ref 操作
final class GitHubGitService {
    private let apiClient: GitHubAPIClient

    init(apiClient: GitHubAPIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - 仓库信息

    /// 获取仓库信息（含默认分支）
    func getRepository(owner: String, repo: String) -> AnyPublisher<GitHubRepo, Error> {
        apiClient.get("/repos/\(owner)/\(repo)")
    }

    /// 获取仓库默认分支名
    func getDefaultBranch(owner: String, repo: String) -> AnyPublisher<String, Error> {
        getRepository(owner: owner, repo: repo)
            .map { $0.defaultBranch }
            .eraseToAnyPublisher()
    }

    // MARK: - Ref（分支引用）

    /// 获取分支引用
    func getRef(owner: String, repo: String, ref: String = "heads/main") -> AnyPublisher<GitRef, Error> {
        apiClient.get("/repos/\(owner)/\(repo)/git/ref/\(ref)")
    }

    /// 获取指定分支的引用
    func getBranchRef(owner: String, repo: String, branch: String) -> AnyPublisher<GitRef, Error> {
        getRef(owner: owner, repo: repo, ref: "heads/\(branch)")
    }

    /// 更新分支引用
    func updateRef(owner: String, repo: String, ref: String = "heads/main", sha: String) -> AnyPublisher<Void, Error> {
        let body = UpdateRefRequest(sha: sha, force: false)
        return apiClient.patchVoid("/repos/\(owner)/\(repo)/git/refs/\(ref)", body: body)
    }

    /// 更新指定分支引用
    func updateBranchRef(owner: String, repo: String, branch: String, sha: String) -> AnyPublisher<Void, Error> {
        updateRef(owner: owner, repo: repo, ref: "heads/\(branch)", sha: sha)
    }

    // MARK: - Blob

    func createBlob(owner: String, repo: String, content: String, encoding: String = "utf-8") -> AnyPublisher<GitObject, Error> {
        let body = CreateBlobRequest(content: content, encoding: encoding)
        return apiClient.post("/repos/\(owner)/\(repo)/git/blobs", body: body)
    }

    func getBlob(owner: String, repo: String, sha: String) -> AnyPublisher<GitBlob, Error> {
        apiClient.get("/repos/\(owner)/\(repo)/git/blobs/\(sha)")
    }

    // MARK: - Tree

    func getTree(owner: String, repo: String, sha: String, recursive: Bool = true) -> AnyPublisher<GitTree, Error> {
        let params = recursive ? ["recursive": "1"] : nil
        return apiClient.get("/repos/\(owner)/\(repo)/git/trees/\(sha)", parameters: params)
    }

    func createTree(owner: String, repo: String, baseTree: String?, items: [CreateTreeItem]) -> AnyPublisher<GitTree, Error> {
        let body = CreateTreeRequest(baseTree: baseTree, tree: items)
        return apiClient.post("/repos/\(owner)/\(repo)/git/trees", body: body)
    }

    // MARK: - Commit

    func createCommit(owner: String, repo: String, message: String, treeSHA: String, parentSHAs: [String]) -> AnyPublisher<GitCommit, Error> {
        let body = CreateCommitRequest(message: message, tree: treeSHA, parents: parentSHAs)
        return apiClient.post("/repos/\(owner)/\(repo)/git/commits", body: body)
    }

    // MARK: - 批量提交

    /// 批量提交多个文件（一次 commit），自动检测默认分支
    func commitFiles(owner: String,
                     repo: String,
                     files: [String: String],
                     message: String,
                     branch: String? = nil) -> AnyPublisher<GitCommit, Error> {

        let branchPublisher: AnyPublisher<String, Error>
        if let branch = branch {
            branchPublisher = Just(branch).setFailureType(to: Error.self).eraseToAnyPublisher()
        } else {
            branchPublisher = getDefaultBranch(owner: owner, repo: repo).eraseToAnyPublisher()
        }

        return branchPublisher
            .flatMap { branch -> AnyPublisher<GitCommit, Error> in
                self.commitFilesOnBranch(owner: owner, repo: repo, files: files, message: message, branch: branch)
            }
            .eraseToAnyPublisher()
    }

    private func commitFilesOnBranch(owner: String,
                                     repo: String,
                                     files: [String: String],
                                     message: String,
                                     branch: String) -> AnyPublisher<GitCommit, Error> {

        return getBranchRef(owner: owner, repo: repo, branch: branch)
            .flatMap { ref -> AnyPublisher<(GitRef, GitTree), Error> in
                self.getTree(owner: owner, repo: repo, sha: ref.object.sha)
                    .map { (ref, $0) }
                    .eraseToAnyPublisher()
            }
            .flatMap { ref, currentTree -> AnyPublisher<(GitRef, GitTree), Error> in
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
                self.createCommit(owner: owner, repo: repo,
                                  message: message,
                                  treeSHA: newTree.sha,
                                  parentSHAs: [ref.object.sha])
            }
            .flatMap { commit -> AnyPublisher<GitCommit, Error> in
                self.updateBranchRef(owner: owner, repo: repo, branch: branch, sha: commit.sha)
                    .map { commit }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
