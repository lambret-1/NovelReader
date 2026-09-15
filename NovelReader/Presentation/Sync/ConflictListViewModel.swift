import Foundation
import Combine

/// 冲突列表 ViewModel
final class ConflictListViewModel: ObservableObject {
    @Published private(set) var conflicts: [ConflictItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var syncResult: SyncResult?

    private let conflictRepository: ConflictRepositoryProtocol
    private let syncEngine: SyncEngineProtocol
    private var cancellables = Set<AnyCancellable>()

    init(conflictRepository: ConflictRepositoryProtocol,
         syncEngine: SyncEngineProtocol) {
        self.conflictRepository = conflictRepository
        self.syncEngine = syncEngine
    }

    func loadConflicts() {
        isLoading = true
        errorMessage = nil
        conflictRepository.fetchUnresolvedConflicts()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] conflicts in
                self?.conflicts = conflicts
            })
            .store(in: &cancellables)
    }

    func resolveConflict(conflictId: String, resolution: ConflictItem.ConflictResolution) {
        syncEngine.resolveConflict(conflictId: conflictId, resolution: resolution)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.conflicts.removeAll { $0.id == conflictId }
                }
            }, receiveValue: {})
            .store(in: &cancellables)
    }

    func resolveAllKeepLocal() { resolveAll(resolution: .keepLocal) }
    func resolveAllKeepRemote() { resolveAll(resolution: .keepRemote) }

    private func resolveAll(resolution: ConflictItem.ConflictResolution) {
        let ids = conflicts.map { $0.id }
        guard !ids.isEmpty else { return }
        isLoading = true
        Publishers.MergeMany(ids.map { syncEngine.resolveConflict(conflictId: $0, resolution: resolution) })
            .collect()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.conflicts.removeAll()
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func continueSync() {
        guard conflicts.isEmpty else {
            errorMessage = "还有 \(conflicts.count) 个冲突未解决"
            return
        }
        isLoading = true
        syncEngine.continueSyncAfterConflictsResolved()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] result in
                self?.syncResult = result
            })
            .store(in: &cancellables)
    }

    func abortSync() {
        syncEngine.abortSync()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: {})
            .store(in: &cancellables)
    }

    func conflictTypeName(for type: ConflictItem.ConflictType) -> String {
        switch type {
        case .contentModified: return "内容修改冲突"
        case .rename: return "重命名冲突"
        case .delete: return "删除冲突"
        }
    }

    func fileName(for path: String) -> String {
        (path as NSString).lastPathComponent
    }

    func bookName(for path: String) -> String {
        path.components(separatedBy: "/").first ?? "未知书籍"
    }
}
