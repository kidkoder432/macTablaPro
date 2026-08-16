//
//  SPSCRingBuffer.swift
//  macTablaPro
//
//  High-performance Single-Producer Single-Consumer (SPSC) Ring Buffer.
//  Provides lock-free, zero-allocation event passing between background audio
//  scheduling threads and the main UI presentation thread.
//

import Foundation
import os

nonisolated public final class SPSCRingBuffer<T>: @unchecked Sendable {
    private let capacity: Int
    private let mask: Int
    private var storage: [T?]
    
    // Internal 64-bit monotonically increasing head positions
    private var writeHead: UInt64 = 0
    private var readHead: UInt64 = 0
    
    // Low-overhead os_unfair_lock for thread memory barrier synchronization
    private var unfairLock = os_unfair_lock()

    public init(capacity: Int = 64) {
        precondition(capacity > 0 && (capacity & (capacity - 1)) == 0, "Capacity must be a power of 2")
        self.capacity = capacity
        self.mask = capacity - 1
        self.storage = [T?](repeating: nil, count: capacity)
    }

    /// Pushes an item into the buffer.
    /// Returns `true` if successful, or `false` if the buffer is full (overflow).
    @discardableResult
    public func push(_ item: T) -> Bool {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }

        let currentWrite = writeHead
        let currentRead = readHead

        if currentWrite - currentRead >= UInt64(capacity) {
            return false // Buffer is full
        }

        let index = Int(currentWrite) & mask
        storage[index] = item
        writeHead = currentWrite + 1
        return true
    }

    /// Peeks at the next available unread item without consuming it.
    public func peek() -> T? {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }

        if readHead >= writeHead {
            return nil // Buffer is empty
        }
        let index = Int(readHead) & mask
        return storage[index]
    }

    /// Consumes and returns the next unread item.
    @discardableResult
    public func pop() -> T? {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }

        if readHead >= writeHead {
            return nil // Buffer is empty
        }
        let index = Int(readHead) & mask
        let item = storage[index]
        storage[index] = nil
        readHead = readHead + 1
        return item
    }

    /// Clears all items currently in the buffer.
    public func clear() {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        
        while readHead < writeHead {
            let index = Int(readHead) & mask
            storage[index] = nil
            readHead += 1
        }
        writeHead = 0
        readHead = 0
    }
    
    /// Returns the number of unread elements currently in the buffer.
    public var count: Int {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        return Int(writeHead - readHead)
    }
}
