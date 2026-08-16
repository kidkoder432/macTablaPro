//
//  Locked.swift
//  macTablaPro
//
//  Generic, zero-allocation thread-safe container using low-overhead os_unfair_lock.
//  Protects shared state between MainActor UI and background audio scheduler threads.
//

import Foundation
import os

nonisolated public final class Locked<T>: @unchecked Sendable {
    private var lock = os_unfair_lock()
    private var _value: T

    public init(_ value: T) {
        self._value = value
    }

    public var value: T {
        get {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            return _value
        }
        set {
            os_unfair_lock_lock(&lock)
            _value = newValue
            os_unfair_lock_unlock(&lock)
        }
    }

    @discardableResult
    public func withLock<R>(_ block: (inout T) -> R) -> R {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return block(&_value)
    }
}
