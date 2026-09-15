import Foundation

/// Manifest 文件条目
struct ManifestEntry: Codable, Equatable {
    let path: String       // 相对仓库根目录的路径
    let sha: String        // 文件内容的 Git blob SHA（或本地 hash）
    let size: Int          // 文件大小（字节）
    let lastModified: TimeInterval  // 最后修改时间戳

    enum CodingKeys: String, CodingKey {
        case path, sha, size
        case lastModified = "last_modified"
    }
}

/// Manifest 文件结构（存储在 .novel-sync/manifest.json）
struct Manifest: Codable, Equatable {
    let version: Int
    let generatedAt: TimeInterval
    var entries: [ManifestEntry]

    enum CodingKeys: String, CodingKey {
        case version, entries
        case generatedAt = "generated_at"
    }

    static let currentVersion = 1
    static let manifestPath = ".novel-sync/manifest.json"

    init(version: Int = currentVersion, entries: [ManifestEntry] = []) {
        self.version = version
        self.generatedAt = Date().timeIntervalSince1970
        self.entries = entries
    }
}

/// 文件差异类型
enum FileDiffType {
    case added          // 远端新增，本地没有
    case deleted        // 远端删除，本地有
    case modified       // 双方都有但内容不同
    case localAdded     // 本地新增，远端没有
    case localDeleted   // 本地删除，远端有
    case localModified  // 本地修改，远端没变
    case unchanged      // 无变化
    case conflict       // 双方都修改了
}

/// 文件差异结果
struct FileDiff {
    let path: String
    let type: FileDiffType
    let localEntry: ManifestEntry?
    let remoteEntry: ManifestEntry?
}

/// Manifest 管理器 - 负责生成本地 manifest 和对比差异
final class ManifestManager {

    /// 从本地书籍和章节数据生成 manifest
    static func generateLocalManifest(books: [Book], chapters: [Chapter]) -> Manifest {
        var entries: [ManifestEntry] = []

        for book in books {
            // 书籍元数据文件
            let metaPath = "\(book.remotePath)/meta.json"
            let metaContent = bookMetaJSON(book)
            let metaSHA = sha256(metaContent)
            entries.append(ManifestEntry(
                path: metaPath,
                sha: metaSHA,
                size: metaContent.utf8.count,
                lastModified: book.updatedAt.timeIntervalSince1970
            ))

            // 章节文件
            let bookChapters = chapters.filter { $0.bookId == book.id }
            for chapter in bookChapters {
                let chapterPath = "\(book.remotePath)/\(chapter.remoteFileName())"
                let content = chapterMarkdown(chapter: chapter)
                let sha = sha256(content)
                entries.append(ManifestEntry(
                    path: chapterPath,
                    sha: sha,
                    size: content.utf8.count,
                    lastModified: chapter.updatedAt.timeIntervalSince1970
                ))
            }
        }

        return Manifest(entries: entries)
    }

    /// 从远端 Git Tree 生成 manifest
    static func generateRemoteManifest(from tree: GitTree) -> Manifest {
        let entries = (tree.tree ?? [])
            .filter { $0.type == "blob" }
            .filter { !$0.path.hasPrefix(".novel-sync/") } // 排除同步元数据目录
            .map { item in
                ManifestEntry(
                    path: item.path,
                    sha: item.sha ?? "",
                    size: item.size ?? 0,
                    lastModified: 0 // Git Tree 不含修改时间
                )
            }
        return Manifest(entries: entries)
    }

    /// 对比本地和远端 manifest，返回差异列表
    static func diff(local: Manifest, remote: Manifest) -> [FileDiff] {
        let localMap = Dictionary(uniqueKeysWithValues: local.entries.map { ($0.path, $0) })
        let remoteMap = Dictionary(uniqueKeysWithValues: remote.entries.map { ($0.path, $0) })

        var diffs: [FileDiff] = []
        let allPaths = Set(localMap.keys).union(Set(remoteMap.keys))

        for path in allPaths.sorted() {
            let localEntry = localMap[path]
            let remoteEntry = remoteMap[path]

            let type: FileDiffType
            switch (localEntry, remoteEntry) {
            case (.some(let local), .some(let remote)):
                if local.sha == remote.sha {
                    type = .unchanged
                } else {
                    // 双方都有但内容不同，需要进一步判断
                    // 简化策略：如果本地 isDirty 则认为本地修改了
                    // 这里只基于 hash 判断为冲突，由 SyncEngine 进一步处理
                    type = .conflict
                }
            case (.some, .none):
                type = .localAdded
            case (.none, .some):
                type = .added
            case (.none, .none):
                continue
            }

            diffs.append(FileDiff(path: path, type: type, localEntry: localEntry, remoteEntry: remoteEntry))
        }

        return diffs
    }

    // MARK: - 私有工具方法

    /// 生成书籍元数据 JSON
    private static func bookMetaJSON(_ book: Book) -> String {
        let dict: [String: Any] = [
            "id": book.id,
            "title": book.title,
            "author": book.author,
            "created_at": ISO8601DateFormatter().string(from: book.createdAt),
            "updated_at": ISO8601DateFormatter().string(from: book.updatedAt),
            "sort_order": book.sortOrder
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    /// 生成章节 Markdown 内容
    static func chapterMarkdown(chapter: Chapter) -> String {
        return "# \(chapter.title)\n\n\(chapter.content)\n"
    }

    /// 从 Markdown 内容解析章节标题和正文
    static func parseChapterMarkdown(_ content: String) -> (title: String, body: String) {
        let lines = content.components(separatedBy: .newlines)
        var title = "未命名章节"
        var bodyLines: [String] = []
        var foundTitle = false

        for line in lines {
            if !foundTitle && line.hasPrefix("# ") {
                title = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                foundTitle = true
            } else if foundTitle {
                bodyLines.append(line)
            }
        }

        // 去掉开头的空行
        while bodyLines.first?.isEmpty == true {
            bodyLines.removeFirst()
        }

        let body = bodyLines.joined(separator: "\n")
        return (title, body)
    }

    /// SHA256 哈希
    private static func sha256(_ string: String) -> String {
        Chapter.hash(content: string)
    }
}
