import Foundation
import Combine

/// GitHub 认证服务
final class GitHubAuthService {
    private let apiClient: GitHubAPIClient
    private let keychain = KeychainManager.shared

    private static let tokenKey = "github_personal_access_token"

    init(apiClient: GitHubAPIClient = .shared) {
        self.apiClient = apiClient
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
            }, receiveCompletion: { [weak self] completion in
                if case .failure = completion {
                    self?.apiClient.clearToken()
                }
            })
            .eraseToAnyPublisher()
    }

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
            .map { _ in true }
            .catch { _ in Just(false).setFailureType(to: Error.self) }
            .eraseToAnyPublisher()
    }
}
