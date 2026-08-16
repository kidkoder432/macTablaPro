import Foundation

#if DEBUG
import os

nonisolated struct AudioLogger {
    // Configurable switches for console logging in DEBUG mode
    nonisolated(unsafe) static var isTablaLoggingEnabled: Bool = true
    nonisolated(unsafe) static var isTanpuraLoggingEnabled: Bool = true
    nonisolated(unsafe) static var isSwarMandalLoggingEnabled: Bool = true
    
    private static let tablaLogger = Logger(subsystem: "com.praj.macTablaPro", category: "Tabla")
    private static let tanpuraLogger = Logger(subsystem: "com.praj.macTablaPro", category: "Tanpura")
    private static let swarLogger = Logger(subsystem: "com.praj.macTablaPro", category: "SwarMandal")
    
    static func logTablaStroke(bol: String, matra: Int, beatFraction: Double, sample: String, hostTime: UInt64) {
        guard isTablaLoggingEnabled else { return }
        tablaLogger.debug("🥁 Matra \(matra, privacy: .public) (@\(String(format: "%.2f", beatFraction), privacy: .public)) | Bol: \(bol, privacy: .public) | Sample: \(sample, privacy: .public) | HostTime: \(hostTime, privacy: .public)")
    }
    
    static func logTanpuraStep(instrument: String, stepIndex: Int, noteName: String, sample: String, hostTime: UInt64) {
        guard isTanpuraLoggingEnabled else { return }
        tanpuraLogger.debug("🪕 \(instrument, privacy: .public) Step [\(stepIndex, privacy: .public)] | Note: \(noteName, privacy: .public) | Sample: \(sample, privacy: .public) | HostTime: \(hostTime, privacy: .public)")
    }
    
    static func logSwarMandalPluck(stringIndex: Int, noteName: String, sample: String, hostTime: UInt64) {
        guard isSwarMandalLoggingEnabled else { return }
        swarLogger.debug("✨ Swar String [\(stringIndex + 1, privacy: .public)] | Note: \(noteName, privacy: .public) | Sample: \(sample, privacy: .public) | HostTime: \(hostTime, privacy: .public)")
    }
}
#else
nonisolated struct AudioLogger {
    nonisolated(unsafe) static var isTablaLoggingEnabled: Bool = false
    nonisolated(unsafe) static var isTanpuraLoggingEnabled: Bool = false
    nonisolated(unsafe) static var isSwarMandalLoggingEnabled: Bool = false
    
    @inline(__always) static func logTablaStroke(bol: String, matra: Int, beatFraction: Double, sample: String, hostTime: UInt64) {}
    @inline(__always) static func logTanpuraStep(instrument: String, stepIndex: Int, noteName: String, sample: String, hostTime: UInt64) {}
    @inline(__always) static func logSwarMandalPluck(stringIndex: Int, noteName: String, sample: String, hostTime: UInt64) {}
}
#endif
