import Foundation
import Combine

/// 防抖工具
final class Debounce<T> {
    private let interval: TimeInterval
    private var timer: Timer?
    private var pendingValue: T?
    private let handler: (T) -> Void

    init(interval: TimeInterval, handler: @escaping (T) -> Void) {
        self.interval = interval
        self.handler = handler
    }

    func emit(_ value: T) {
        pendingValue = value
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self, let value = self.pendingValue else { return }
            self.handler(value)
            self.pendingValue = nil
        }
    }

    func flush() {
        timer?.invalidate()
        if let value = pendingValue {
            handler(value)
            pendingValue = nil
        }
    }

    deinit {
        timer?.invalidate()
    }
}

/// 节流工具
final class Throttle<T> {
    private let interval: TimeInterval
    private var lastEmit: Date = .distantPast
    private var pendingValue: T?
    private var timer: Timer?
    private let handler: (T) -> Void

    init(interval: TimeInterval, handler: @escaping (T) -> Void) {
        self.interval = interval
        self.handler = handler
    }

    func emit(_ value: T) {
        let now = Date()
        if now.timeIntervalSince(lastEmit) >= interval {
            handler(value)
            lastEmit = now
        } else {
            pendingValue = value
            timer?.invalidate()
            let delay = interval - now.timeIntervalSince(lastEmit)
            timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self = self, let value = self.pendingValue else { return }
                self.handler(value)
                self.lastEmit = Date()
                self.pendingValue = nil
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}
