import Foundation
import Combine

/// 获取书籍的所有章节
struct FetchChaptersUseCase {
    private let repository: ChapterRepositoryProtocol

    init(repository: ChapterRepositoryProtocol) {
        self.repository = repository
    }

    func execute(bookId: String) -> AnyPublisher<[Chapter], Error> {
        repository.fetchChapters(bookId: bookId)
    }
}

/// 获取单个章节内容
struct GetChapterContentUseCase {
    private let repository: ChapterRepositoryProtocol

    init(repository: ChapterRepositoryProtocol) {
        self.repository = repository
    }

    func execute(chapterId: String) -> AnyPublisher<Chapter?, Error> {
        repository.fetchChapter(id: chapterId)
    }
}

/// 创建章节
struct CreateChapterUseCase {
    private let repository: ChapterRepositoryProtocol

    init(repository: ChapterRepositoryProtocol) {
        self.repository = repository
    }

    func execute(bookId: String, title: String, sortOrder: Int) -> AnyPublisher<Chapter, Error> {
        let chapter = Chapter(bookId: bookId, title: title, sortOrder: sortOrder)
        return repository.createChapter(chapter)
    }
}

/// 更新章节内容
struct UpdateChapterContentUseCase {
    private let repository: ChapterRepositoryProtocol

    init(repository: ChapterRepositoryProtocol) {
        self.repository = repository
    }

    func execute(chapterId: String, content: String) -> AnyPublisher<Chapter, Error> {
        repository.fetchChapter(id: chapterId)
            .compactMap { $0 }
            .flatMap { chapter -> AnyPublisher<Chapter, Error> in
                var updated = chapter
                updated.updateContent(content)
                return self.repository.updateChapter(updated)
            }
            .eraseToAnyPublisher()
    }
}

/// 更新章节标题
struct UpdateChapterTitleUseCase {
    private let repository: ChapterRepositoryProtocol

    init(repository: ChapterRepositoryProtocol) {
        self.repository = repository
    }

    func execute(chapterId: String, title: String) -> AnyPublisher<Chapter, Error> {
        repository.fetchChapter(id: chapterId)
            .compactMap { $0 }
            .flatMap { chapter -> AnyPublisher<Chapter, Error> in
                var updated = chapter
                updated.title = title
                updated.updatedAt = Date()
                updated.isDirty = true
                return self.repository.updateChapter(updated)
            }
            .eraseToAnyPublisher()
    }
}

/// 删除章节
struct DeleteChapterUseCase {
    private let repository: ChapterRepositoryProtocol

    init(repository: ChapterRepositoryProtocol) {
        self.repository = repository
    }

    func execute(chapterId: String) -> AnyPublisher<Void, Error> {
        repository.deleteChapter(id: chapterId)
    }
}

/// 章节重新排序
struct ReorderChaptersUseCase {
    private let repository: ChapterRepositoryProtocol

    init(repository: ChapterRepositoryProtocol) {
        self.repository = repository
    }

    func execute(chapters: [Chapter]) -> AnyPublisher<Void, Error> {
        var reordered = chapters
        for (index, _) in reordered.enumerated() {
            reordered[index].sortOrder = index
            reordered[index].isDirty = true
        }
        return repository.reorderChapters(reordered)
    }
}
