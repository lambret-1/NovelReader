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

// MARK: - 阅读进度同步数据结构

/// 远端阅读进度条目（用 remotePath 关联，避免跨设备 UUID 不一致）
struct RemoteReadingProgress: Codable, Equatable {
    let bookPath: String          // 书籍远端路径
    let chapterPath: String       // 章节远端路径
    let chapterSortOrder: Int     // 章节序号（兜底匹配）
    let offset: Int                // 字符偏移
    let percent: Double           // 阅读百分比
    let updatedAt: TimeInterval   // 更新时间戳

    enum CodingKeys: String, CodingKey {
        case bookPath = "book_path"
        case chapterPath = "chapter_path"
        case chapterSortOrder = "chapter_sort_order"
        case offset, percent
        case updatedAt = "updated_at"
    }
}

/// 远端阅读进度文件结构
struct RemoteReadingProgressFile: Codable, Equatable {
    let version: Int
    let generatedAt: TimeInterval
    var progresses: [RemoteReadingProgress]

    enum CodingKeys: String, CodingKey {
        case version, progresses
        case generatedAt = "generated_at"
    }

    static let currentVersion = 1
    static let filePath = ".novel-sync/progress.json"

    init(progresses: [RemoteReadingProgress] = []) {
        self.version = Self.currentVersion
        self.generatedAt = Date().timeIntervalSince1970
        self.progresses = progresses
    }
}

// MARK: - 书签同步数据结构

/// 远端书签条目
struct RemoteBookmark: Codable, Equatable {
    let bookPath: String          // 书籍远端路径
    let chapterPath: String       // 章节远端路径
    let chapterSortOrder: Int     // 章节序号（兜底匹配）
    let offset: Int                // 字符偏移
    let textExcerpt: String?      // 选中文本摘要
    let note: String?             // 笔记
    let createdAt: TimeInterval   // 创建时间戳

    enum CodingKeys: String, CodingKey {
        case bookPath = "book_path"
        case chapterPath = "chapter_path"
        case chapterSortOrder = "chapter_sort_order"
        case offset
        case textExcerpt = "text_excerpt"
        case note
        case createdAt = "created_at"
    }
}

/// 远端书签文件结构
struct RemoteBookmarkFile: Codable, Equatable {
    let version: Int
    let generatedAt: TimeInterval
    var bookmarks: [RemoteBookmark]

    enum CodingKeys: String, CodingKey {
        case version, bookmarks
        case generatedAt = "generated_at"
    }

    static let currentVersion = 1
    static let filePath = ".novel-sync/bookmarks.json"

    init(bookmarks: [RemoteBookmark] = []) {
        self.version = Self.currentVersion
        self.generatedAt = Date().timeIntervalSince1970
        self.bookmarks = bookmarks
    }
}

/// Manifest 管理器 - 负责生成本地 manifest、对比差异、序列化同步数据
final class ManifestManager {

    // MARK: - Manifest 生成与对比

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
            .filter { !$0.path.hasPrefix(".git") }        // 排除 git 相关文件
            .filter { $0.path != "README.md" }            // 排除仓库说明文件
            .filter { $0.path != ".gitignore" }           // 排除 gitignore
            .filter { isValidNovelFilePath($0.path) }     // 只保留小说文件格式
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

    /// 验证是否为有效的小说文件路径
    /// 格式：书名/meta.json 或 书名/序号_标题.md
    private static func isValidNovelFilePath(_ path: String) -> Bool {
        let components = path.components(separatedBy: "/")
        guard components.count == 2 else { return false }
        let fileName = components[1]
        if fileName == "meta.json" { return true }
        if fileName.hasSuffix(".md") {
            // 序号_标题.md 格式，序号为 3 位数字
            let namePart = fileName.dropLast(3) // 去掉 .md
            if namePart.count >= 4, namePart.prefix(3).allSatisfy({ $0.isNumber }), namePart[namePart.index(namePart.startIndex, offsetBy: 3)] == "_" {
                return true
            }
        }
        return false
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
                    // 双方都有但内容不同，标记为冲突（由 SyncEngine 决定保留本地或远端）
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

    // MARK: - 章节 Markdown 序列化

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

    // MARK: - 书籍元数据序列化

    /// 生成书籍元数据 JSON
    static func bookMetaJSON(_ book: Book) -> String {
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

    /// 解析书籍元数据 JSON
    static func parseBookMetaJSON(_ content: String) -> (title: String, author: String, sortOrder: Int)? {
        guard let data = content.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let title = dict["title"] as? String ?? ""
        let author = dict["author"] as? String ?? ""
        let sortOrder = dict["sort_order"] as? Int ?? 0
        return (title, author, sortOrder)
    }

    // MARK: - 阅读进度序列化

    /// 从本地阅读进度生成远端同步数据
    /// - Parameters:
    ///   - progresses: 本地所有阅读进度
    ///   - books: 本地书籍（用于映射 bookId -> remotePath）
    ///   - chapters: 本地所有章节（用于映射 chapterId -> remotePath/sortOrder）
    /// - Returns: 远端阅读进度文件结构
    static func makeRemoteProgresses(progresses: [ReadingProgress], books: [Book], chapters: [Chapter]) -> RemoteReadingProgressFile {
        let bookMap = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
        let chapterMap = Dictionary(uniqueKeysWithValues: chapters.map { ($0.id, $0) })

        var remoteProgresses: [RemoteReadingProgress] = []

        for progress in progresses {
            guard let book = bookMap[progress.bookId],
                  let chapter = chapterMap[progress.chapterId] else {
                continue
            }
            let chapterPath = "\(book.remotePath)/\(chapter.remoteFileName())"
            remoteProgresses.append(RemoteReadingProgress(
                bookPath: book.remotePath,
                chapterPath: chapterPath,
                chapterSortOrder: chapter.sortOrder,
                offset: progress.offset,
                percent: progress.percent,
                updatedAt: progress.updatedAt.timeIntervalSince1970
            ))
        }

        return RemoteReadingProgressFile(progresses: remoteProgresses)
    }

    /// 序列化阅读进度文件为 JSON 字符串
    static func progressJSON(_ file: RemoteReadingProgressFile) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        if let data = try? encoder.encode(file),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    /// 解析远端阅读进度 JSON
    static func parseProgressJSON(_ content: String) -> RemoteReadingProgressFile? {
        guard let data = content.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(RemoteReadingProgressFile.self, from: data)
    }

    // MARK: - 书签序列化

    /// 从本地书签生成远端同步数据
    static func makeRemoteBookmarks(bookmarks: [Bookmark], books: [Book], chapters: [Chapter]) -> RemoteBookmarkFile {
        let bookMap = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
        let chapterMap = Dictionary(uniqueKeysWithValues: chapters.map { ($0.id, $0) })

        var remoteBookmarks: [RemoteBookmark] = []

        for bookmark in bookmarks {
            guard let book = bookMap[bookmark.bookId],
                  let chapter = chapterMap[bookmark.chapterId] else {
                continue
            }
            let chapterPath = "\(book.remotePath)/\(chapter.remoteFileName())"
            remoteBookmarks.append(RemoteBookmark(
                bookPath: book.remotePath,
                chapterPath: chapterPath,
                chapterSortOrder: chapter.sortOrder,
                offset: bookmark.offset,
                textExcerpt: bookmark.textExcerpt,
                note: bookmark.note,
                createdAt: bookmark.createdAt.timeIntervalSince1970
            ))
        }

        return RemoteBookmarkFile(bookmarks: remoteBookmarks)
    }

    /// 序列化书签文件为 JSON 字符串
    static func bookmarksJSON(_ file: RemoteBookmarkFile) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        if let data = try? encoder.encode(file),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    /// 解析远端书签 JSON
    static func parseBookmarksJSON(_ content: String) -> RemoteBookmarkFile? {
        guard let data = content.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(RemoteBookmarkFile.self, from: data)
    }

    // MARK: - 私有工具方法

    /// SHA256 哈希
    private static func sha256(_ string: String) -> String {
        Chapter.hash(content: string)
    }
}
