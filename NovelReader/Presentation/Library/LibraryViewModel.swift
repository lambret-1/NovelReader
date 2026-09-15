import Foundation
import Combine

/// 书架 ViewModel
final class LibraryViewModel {
    // MARK: - 输出
    @Published private(set) var books: [Book] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 输入
    let refreshTrigger = PassthroughSubject<Void, Never>()
    let createBookTrigger = PassthroughSubject<String, Never>()
    let deleteBookTrigger = PassthroughSubject<IndexPath, Never>()
    let selectBookTrigger = PassthroughSubject<Book, Never>()

    // MARK: - 依赖
    private let fetchBooksUseCase: FetchBooksUseCase
    private let createBookUseCase: CreateBookUseCase
    private let deleteBookUseCase: DeleteBookUseCase
    private var cancellables = Set<AnyCancellable>()

    init(fetchBooksUseCase: FetchBooksUseCase,
         createBookUseCase: CreateBookUseCase,
         deleteBookUseCase: DeleteBookUseCase) {
        self.fetchBooksUseCase = fetchBooksUseCase
        self.createBookUseCase = createBookUseCase
        self.deleteBookUseCase = deleteBookUseCase
        bind()
    }

    private func bind() {
        refreshTrigger
            .sink { [weak self] in self?.loadBooks() }
            .store(in: &cancellables)

        createBookTrigger
            .sink { [weak self] title in self?.createBook(title: title) }
            .store(in: &cancellables)

        deleteBookTrigger
            .sink { [weak self] indexPath in self?.deleteBook(at: indexPath) }
            .store(in: &cancellables)
    }

    func loadBooks() {
        isLoading = true
        fetchBooksUseCase.execute()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] books in
                self?.books = books
            })
            .store(in: &cancellables)
    }

    private func createBook(title: String) {
        createBookUseCase.execute(title: title)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] _ in
                self?.loadBooks()
            })
            .store(in: &cancellables)
    }

    private func deleteBook(at indexPath: IndexPath) {
        guard indexPath.row < books.count else { return }
        let book = books[indexPath.row]
        deleteBookUseCase.execute(bookId: book.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] _ in
                self?.loadBooks()
            })
            .store(in: &cancellables)
    }

    func book(at indexPath: IndexPath) -> Book? {
        guard indexPath.row < books.count else { return nil }
        return books[indexPath.row]
    }
}
