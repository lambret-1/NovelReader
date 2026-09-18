import Foundation

// MARK: - GitHub API 响应模型

/// GitHub 用户信息
struct GitHubUser: Codable {
    let login: String
    let id: Int
    let name: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case login, id, name
        case avatarURL = "avatar_url"
    }
}

/// GitHub 仓库信息
struct GitHubRepo: Codable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    let defaultBranch: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case fullName = "full_name"
        case isPrivate = "private"
        case defaultBranch = "default_branch"
    }
}

/// Git 引用（分支）
struct GitRef: Codable {
    let ref: String
    let object: GitObject
}

/// Git 对象（Blob/Tree/Commit 的引用）
/// 注意：创建 Blob 接口返回 {sha, url} 不含 type，故 type 必须为可选
struct GitObject: Codable {
    let sha: String
    let type: String?
    let url: String?
}

/// Git Tree
struct GitTree: Codable {
    let sha: String
    let tree: [GitTreeItem]?
    let truncated: Bool?
}

struct GitTreeItem: Codable {
    let path: String
    let mode: String
    let type: String  // blob / tree
    let sha: String?
    let size: Int?
}

/// Git Blob
struct GitBlob: Codable {
    let sha: String
    let content: String  // base64 编码
    let encoding: String
    let size: Int
}

/// Git Commit
struct GitCommit: Codable {
    let sha: String
    let message: String
    let author: GitCommitAuthor?
    let tree: GitObject
    let parents: [GitObject]
}

struct GitCommitAuthor: Codable {
    let name: String
    let email: String
    let date: String
}

/// 创建 Blob 请求
struct CreateBlobRequest: Codable {
    let content: String
    let encoding: String  // "utf-8" or "base64"
}

/// 创建 Tree 请求
struct CreateTreeRequest: Codable {
    let baseTree: String?
    let tree: [CreateTreeItem]

    enum CodingKeys: String, CodingKey {
        case baseTree = "base_tree"
        case tree
    }
}

/// 创建 Tree 条目
/// 注意：删除文件时 mode/type/sha 均为 nil，仅编码 path，GitHub API 会将其解释为删除该路径
struct CreateTreeItem: Codable {
    let path: String
    let mode: String?  // "100644" for file，删除时为 nil
    let type: String?  // "blob"，删除时为 nil
    let sha: String?   // 已有 blob 的 sha，删除时为 nil
    let content: String? // 直接内联内容（小文件）

    enum CodingKeys: String, CodingKey {
        case path, mode, type, sha, content
    }

    /// 自定义编码：删除条目仅编码 path，其余字段省略
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
        if let mode = mode { try container.encode(mode, forKey: .mode) }
        if let type = type { try container.encode(type, forKey: .type) }
        if let sha = sha { try container.encode(sha, forKey: .sha) }
        if let content = content { try container.encode(content, forKey: .content) }
    }

    /// 创建普通文件条目（新增/修改）
    static func fileItem(path: String, sha: String) -> CreateTreeItem {
        CreateTreeItem(path: path, mode: "100644", type: "blob", sha: sha, content: nil)
    }

    /// 创建删除条目（从 tree 中移除该路径）
    static func deleteItem(path: String) -> CreateTreeItem {
        CreateTreeItem(path: path, mode: nil, type: nil, sha: nil, content: nil)
    }
}

/// 创建 Commit 请求
struct CreateCommitRequest: Codable {
    let message: String
    let tree: String
    let parents: [String]
}

/// 更新 Ref 请求
struct UpdateRefRequest: Codable {
    let sha: String
    let force: Bool
}

/// Contents API 响应（单文件）
struct GitHubContent: Codable {
    let name: String
    let path: String
    let sha: String
    let size: Int
    let type: String  // file / dir
    let content: String?  // base64，仅单文件时返回
    let encoding: String?
    let downloadURL: String?

    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, type, content, encoding
        case downloadURL = "download_url"
    }
}

/// API 错误响应
struct GitHubAPIError: Codable, Error {
    let message: String
    let errors: [GitHubAPIErrorDetail]?
    let documentationURL: String?

    enum CodingKeys: String, CodingKey {
        case message, errors
        case documentationURL = "documentation_url"
    }
}

struct GitHubAPIErrorDetail: Codable {
    let resource: String?
    let field: String?
    let code: String?
    let message: String?
}
