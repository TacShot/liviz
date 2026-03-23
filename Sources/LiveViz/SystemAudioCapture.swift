import AppKit
import CoreMedia
import ScreenCaptureKit

final class SystemAudioCapture: NSObject, SCStreamOutput, @unchecked Sendable {
    private let onSamples: ([Float]) -> Void
    private let onError: (Error) -> Void
    private let queue = DispatchQueue(label: "com.hysarthak.liveviz.audio")

    private var stream: SCStream?

    init(onSamples: @escaping ([Float]) -> Void, onError: @escaping (Error) -> Void) {
        self.onSamples = onSamples
        self.onError = onError
    }

    func start() async {
        do {
            let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = preferredDisplay(from: shareableContent) else {
                throw CaptureError.noDisplay
            }

            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = 2
            configuration.height = 2
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            configuration.queueDepth = 1
            configuration.showsCursor = false
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = true

            let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
            try await stream.startCapture()
            self.stream = stream
        } catch {
            onError(error)
        }
    }

    func stop() async {
        do {
            try await stream?.stopCapture()
        } catch {
            onError(error)
        }
        stream = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio else { return }
        guard let floats = sampleBuffer.floatSamples(), !floats.isEmpty else { return }
        onSamples(floats)
    }

    private func preferredDisplay(from shareableContent: SCShareableContent) -> SCDisplay? {
        let currentDisplayID = NSScreen.main?.displayID
        return shareableContent.displays.first { $0.displayID == currentDisplayID } ?? shareableContent.displays.first
    }
}

private enum CaptureError: LocalizedError {
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "No display was available for system audio capture."
        }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

private extension CMSampleBuffer {
    func floatSamples() -> [Float]? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(self),
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }

        let format = asbdPointer.pointee
        let channelCount = max(Int(format.mChannelsPerFrame), 1)
        let bytesPerSample = max(Int(format.mBitsPerChannel / 8), 1)
        let interleaved = (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
        let isFloat = (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0

        let bufferCount = interleaved ? 1 : channelCount
        let bufferListSize = MemoryLayout<AudioBufferList>.size + (bufferCount - 1) * MemoryLayout<AudioBuffer>.size
        let rawBufferList = UnsafeMutableRawPointer.allocate(byteCount: bufferListSize, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawBufferList.deallocate() }

        let audioBufferList = rawBufferList.bindMemory(to: AudioBufferList.self, capacity: 1)
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            self,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferList,
            bufferListSize: bufferListSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else { return nil }

        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        guard let firstBuffer = buffers.first else { return nil }
        let framesPerBuffer = Int(firstBuffer.mDataByteSize) / max(bytesPerSample, 1) / (interleaved ? channelCount : 1)
        guard framesPerBuffer > 0 else { return nil }

        var mono = Array(repeating: Float.zero, count: framesPerBuffer)

        if isFloat {
            if interleaved {
                guard let data = firstBuffer.mData?.assumingMemoryBound(to: Float.self) else { return nil }
                for frame in 0..<framesPerBuffer {
                    var sum: Float = 0
                    for channel in 0..<channelCount {
                        sum += data[(frame * channelCount) + channel]
                    }
                    mono[frame] = sum / Float(channelCount)
                }
            } else {
                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    for frame in 0..<framesPerBuffer {
                        mono[frame] += data[frame] / Float(channelCount)
                    }
                }
            }
        } else {
            if interleaved {
                guard let data = firstBuffer.mData?.assumingMemoryBound(to: Int16.self) else { return nil }
                for frame in 0..<framesPerBuffer {
                    var sum: Float = 0
                    for channel in 0..<channelCount {
                        let sample = data[(frame * channelCount) + channel]
                        sum += Float(sample) / Float(Int16.max)
                    }
                    mono[frame] = sum / Float(channelCount)
                }
            } else {
                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Int16.self) else { continue }
                    for frame in 0..<framesPerBuffer {
                        mono[frame] += (Float(data[frame]) / Float(Int16.max)) / Float(channelCount)
                    }
                }
            }
        }

        return mono
    }
}
