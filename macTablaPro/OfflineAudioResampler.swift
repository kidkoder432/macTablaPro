//
//  OfflineAudioResampler.swift
//  macTablaPro
//
//  Created for Offline Buffer Resampling Engine
//

import AVFoundation
import Foundation

enum ResamplingError: Error {
    enum Reason {
        case converterInitializationFailed
        case bufferCreationFailed
        case conversionFailed(NSError?)
    }
    case failed(Reason)
}

/// High-performance offline PCM buffer resampler using AVAudioConverter.
nonisolated enum OfflineAudioResampler {

    /// Resamples a source PCM buffer to a new target pitch specified in cents.
    ///
    /// - Parameters:
    ///   - sourceBuffer: The original PCM buffer loaded from disk (e.g. at base pitch).
    ///   - centsOffset: Relative pitch shift in cents (e.g., +200.0 for +2 semitones, -100.0 for -1 semitone).
    /// - Returns: A newly allocated `AVAudioPCMBuffer` containing the resampled PCM data, or `nil` if conversion fails.
    nonisolated static func resample(
        sourceBuffer: AVAudioPCMBuffer,
        centsOffset: Double
    ) throws -> AVAudioPCMBuffer? {
        
        guard centsOffset != 0.0 else { return sourceBuffer }
        
        let sourceFormat = sourceBuffer.format
        
        let originalSampleRate = sourceFormat.sampleRate
        let rateConversionFactor = pow(2, centsOffset / 1200)
        let targetSampleRate = originalSampleRate * rateConversionFactor
        
        let inputSampleRate = targetSampleRate
        let outputSampleRate = originalSampleRate
        
        guard
            let inputFormat = AVAudioFormat(
                commonFormat: sourceFormat.commonFormat,
                sampleRate: inputSampleRate,
                channels: sourceFormat.channelCount,
                interleaved: sourceFormat.isInterleaved
            )
        else {
            throw ResamplingError.failed(.converterInitializationFailed)
        }
        
        guard let outputFormat = AVAudioFormat(
            commonFormat: inputFormat.commonFormat,
            sampleRate: outputSampleRate,
            channels: inputFormat.channelCount,
            interleaved: inputFormat.isInterleaved
        ) else {
            throw ResamplingError.failed(.converterInitializationFailed)
        }

        guard let converter = AVAudioConverter(
            from: inputFormat,
            to: outputFormat
        ) else {
            throw ResamplingError.failed(.converterInitializationFailed)
        }

        let sampleRateRatio = outputSampleRate / inputSampleRate
        let outputFrameCapacity = AVAudioFrameCount(
            Double(sourceBuffer.frameLength) * sampleRateRatio
        )

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            throw ResamplingError.failed(.bufferCreationFailed)
        }

        // Create a wrapper buffer matching inputFormat
        guard
            let inputBuffer = AVAudioPCMBuffer(
                pcmFormat: inputFormat,
                frameCapacity: sourceBuffer.frameCapacity
            )
        else {
            throw ResamplingError.failed(.bufferCreationFailed)
        }
        inputBuffer.frameLength = sourceBuffer.frameLength

        // Copy channel data pointers to match the custom inputFormat
        for ch in 0..<Int(sourceFormat.channelCount) {
            if let src = sourceBuffer.floatChannelData?[ch],
                let dst = inputBuffer.floatChannelData?[ch]
            {
                dst.initialize(from: src, count: Int(sourceBuffer.frameLength))
            } else if let src = sourceBuffer.int16ChannelData?[ch],
                let dst = inputBuffer.int16ChannelData?[ch]
            {
                dst.initialize(from: src, count: Int(sourceBuffer.frameLength))
            }
        }

        var error: NSError?
        var hasProvidedInput = false

        let status = converter.convert(to: outputBuffer, error: &error) {
            packetCount,
            outStatus in
            if !hasProvidedInput {
                hasProvidedInput = true
                outStatus.pointee = .haveData
                return inputBuffer
            } else {
                outStatus.pointee = .endOfStream
                return nil
            }
        }

        if status == .error || error != nil {
            throw ResamplingError.failed(.conversionFailed(error))
        }

        return outputBuffer

    }

    /// Batch resamples an array of PitchedSample objects to a target absolute tuning in cents.
    ///
    /// - Parameters:
    ///   - samples: The list of active samples to update.
    ///   - targetPitchCents: Total desired pitch (Master pitch + fine tune).
    nonisolated static func resampleBatch(
        samples: [PitchedSample],
        targetPitchCents: Double
    ) {
        for sample in samples {
            guard sample.role != "UnPitched" else { continue }
            try? sample.resampledBuffer =
                resample(
                    sourceBuffer: sample.buffer!,
                    centsOffset: targetPitchCents - sample.absolutePitch
                ) ?? sample.buffer
            sample.resampledPitch = targetPitchCents

            print(
                "Resampled sample: \(sample.fileName) from \(sample.absolutePitch) to \(targetPitchCents)"
            )
        }
    }
}
