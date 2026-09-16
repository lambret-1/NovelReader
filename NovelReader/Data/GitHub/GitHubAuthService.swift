import Foundation
import Combine
import GRDB

/// GitHub 认证服务
final class GitHubAuthService {
    private let apiClient: GitHubAPIClient
    private let keychain = KeychainManager.shared
    private let syncMetadataRepository: SyncMetadataRepository?
    private var cancellables = Set<AnyCancellable>()

    private static let tokenKey = "github_personal_access_token"

    init(apiClient: GitHubAPIClient = .shared,
         syncMetadataRepository: SyncMetadataRepository? = nil) {
        self.apiClient = apiClient
        self.syncMetadataRepository = syncMetadataRepository
    }

    /// 从 Keychain 加载已保存的 Token
    func loadSavedToken() -> String? {
        return keychain.get(key: Self.tokenKey)
    }

    /// 使用 PAT 登录并验证
    func loginWithPAT(_ token: String) -> AnyPublisher<GitHubUser, Error> {
        apiClient.setToken(token)
        return apiClient.get("/user")
            .handleEvents(receiveOutput: { [weak self] user in
                // 验证成功，保存 Token
                self?.keychain.set(value: token, key: Self.tokenKey)
                AppLogger.info("GitHub 登录成功: \(user.login)")

                // 自动配置同步仓库：用户名/MyNovels
                guard let self = self, let repo = self.syncMetadataRepository else { return }
                let defaultRepo = "\(user.login)/\(AppConfig.defaultRepoName)"
                _ = repo.fetchMetadata()
                    .flatMap { metadata -> AnyPublisher<SyncMetadata, Error> in
                        var updated = metadata
                        updated.githubUsername = user.login
                        if updated.repoFullName == nil {
                            updated.repoFullName = defaultRepo
                        }
                        return repo.updateMetadata(updated)
                    }
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            AppLogger.error("保存同步元数据失败: \(error.localizedDescription)")
                        }
                    }, receiveValue: { _ in
                        AppLogger.info("同步仓库已配置: \(defaultRepo)")
                    })
                    .store(in: &self.cancellables)
            }, receiveCompletion: { [weak self] completion in
                if case .failure = completion {
                    self?.apiClient.clearToken()
                }
            })
            .eraseToAnyPublisher()
    }

    private var cancellables = Set<AnyCancellable>()

    /// 登出
    func logout() {
        apiClient.clearToken()
        keychain.delete(key: Self.tokenKey)
    }

    /// 获取当前登录用户
    func fetchCurrentUser() -> AnyPublisher<GitHubUser, Error> {
        return apiClient.get("/user")
    }

    /// 检查 Token 是否有效
    func validateToken() -> AnyPublisher<Bool, Error> {
        return apiClient.get("/user")
            .map { (_: GitHubUser) in true }
            .catch { (_: Error) in Just(false).setFailureType(to: Error.self) }
            .eraseToAnyPublisher()
    }
}
