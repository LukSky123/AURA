import AVFoundation
import Flutter

// iOS capability is intentionally foreground/lifecycle-limited. This class
// never claims background persistence, autonomous SMS, or hardware-key control.
final class AudioDetectionPlugin: NSObject {
  private let engine = AVAudioEngine()

  func start() throws {
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    input.installTap(onBus: 0, bufferSize: 16_000, format: format) { buffer, _ in
      // Convert in-memory PCM to the release-approved INT8 model input and emit
      // only label/confidence. Do not retain buffers.
      _ = buffer
    }
    try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
    try AVAudioSession.sharedInstance().setActive(true)
    try engine.start()
  }

  func stop() { engine.inputNode.removeTap(onBus: 0); engine.stop() }
}
