import Foundation
import Combine

/// GitHub API 客户端 - 基础请求封装
final class GitHubAPIClient {
    static let shared = GitHubAPIClient()

    private let session: URLSession
    private let baseURL = AppConfig.githubAPIBaseURL
    private var token: String?

    /// 限流信息
    private(set) var rateLimitRemaining: Int = 5000
    private(set) var rateLimitReset: TimeInterval = 0

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        session = URLSession(configuration: config)
    }

    /// 设置 Token
    func setToken(_ token: String) {
        self.token = token
    }

    /// 清除 Token
    func clearToken() {
        self.token = nil
    }

    /// 是否已登录
    var isAuthenticated: Bool {
        token != nil && !(token?.isEmpty ?? true)
    }

    // MARK: - 通用请求方法

    /// 发送 GET 请求
    func get<T: Decodable>(_ path: String, parameters: [String: String]? = nil) -> AnyPublisher<T, Error> {
        request(method: "GET", path: path, parameters: parameters, body: nil)
    }

    /// 发送 POST 请求
    func post<T: Decodable, B: Encodable>(_ path: String, body: B) -> AnyPublisher<T, Error> {
        request(method: "POST", path: path, parameters: nil, body: body)
    }

    /// 发送 PATCH 请求
    func patch<T: Decodable, B: Encodable>(_ path: String, body: B) -> AnyPublisher<T, Error> {
        request(method: "PATCH", path: path, parameters: nil, body: body)
    }

    /// 发送 PATCH 请求（无返回值）
    func patchVoid<B: Encodable>(_ path: String, body: B) -> AnyPublisher<Void, Error> {
        requestVoid(method: "PATCH", path: path, body: body)
    }

    /// 发送 PUT 请求
    func put<T: Decodable, B: Encodable>(_ path: String, body: B) -> AnyPublisher<T, Error> {
        request(method: "PUT", path: path, parameters: nil, body: body)
    }

    /// 发送 DELETE 请求
    func delete(_ path: String) -> AnyPublisher<Void, Error> {
        requestVoid(method: "DELETE", path: path)
    }

    // MARK: - 私有实现

    private func request<T: Decodable>(method: String,
                                        path: String,
                                        parameters: [String: String]?,
                                        body: Encodable?) -> AnyPublisher<T, Error> {
        guard let request = buildRequest(method: method, path: path, parameters: parameters, body: body) else {
            return Fail(error: GitHubError.invalidURL).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                try self.handleResponse(data: data, response: response)
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder.githubDecoder)
            .eraseToAnyPublisher()
    }

    private func requestVoid(method: String, path: String, body: Encodable? = nil) -> AnyPublisher<Void, Error> {
        guard let request = buildRequest(method: method, path: path, parameters: nil, body: body) else {
            return Fail(error: GitHubError.invalidURL).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                try self.handleResponse(data: data, response: response)
                return ()
            }
            .eraseToAnyPublisher()
    }

    private func buildRequest(method: String,
                              path: String,
                              parameters: [String: String]?,
                              body: Encodable?) -> URLRequest? {
        var urlString = baseURL + path
        if let parameters = parameters, !parameters.isEmpty {
            let queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            var components = URLComponents(string: urlString)
            components?.queryItems = queryItems
            urlString = components?.url?.absoluteString ?? urlString
        }

        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try? JSONEncoder.githubEncoder.encode(body)
        }

        return request
    }

    private func handleResponse(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        // 更新限流信息
        if let remaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
           let value = Int(remaining) {
            rateLimitRemaining = value
        }
        if let reset = httpResponse.allHeaderFields["X-RateLimit-Reset"] as? String,
           let value = TimeInterval(reset) {
            rateLimitReset = value
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 403 && rateLimitRemaining == 0 {
                throw GitHubError.rateLimitExceeded(resetTime: rateLimitReset)
            }
            if let apiError = try? JSONDecoder.githubDecoder.decode(GitHubAPIError.self, from: data) {
                throw GitHubError.apiError(message: apiError.message, statusCode: httpResponse.statusCode)
            }
            throw GitHubError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - 错误类型

enum GitHubError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(message: String, statusCode: Int)
    case rateLimitExceeded(resetTime: TimeInterval)
    case unauthorized
    case repositoryNotFound
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .invalidResponse: return "无效的响应"
        case .httpError(let code): return "HTTP 错误: \(code)"
        case .apiError(let message, _): return message
        case .rateLimitExceeded: return "GitHub API 限流，请稍后再试"
        case .unauthorized: return "未授权，请检查 Token"
        case .repositoryNotFound: return "仓库不存在"
        case .fileNotFound: return "文件不存在"
        }
    }
}

// MARK: - JSON 编解码扩展

extension JSONDecoder {
    static let githubDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static let githubEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .withoutEscapingSlashes
        return encoder
    }()
}
