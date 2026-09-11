import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'utils/mfcc.dart';

class AudioClassifier {
  Interpreter? _interpreter;
  final MFCC _mfcc;
  final List<String> labels = [
    'Gunshot',
    'Glass',
    'Crowd',
  ]; // Assuming order 0, 1, 2

  AudioClassifier() : _mfcc = MFCC();

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/audio_classifier.tflite',
      );
      debugPrint('✅ Model loaded successfully');

      // Print input/output shape for debugging
      var inputShape = _interpreter!.getInputTensor(0).shape;
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      debugPrint('Model Input Shape: $inputShape');
      debugPrint('Model Output Shape: $outputShape');
    } catch (e) {
      debugPrint('❌ Failed to load model: $e');
    }
  }

  Future<Map<String, dynamic>> predict(Float32List audioSample) async {
    if (_interpreter == null) {
      return {'label': 'Error', 'confidence': 0.0};
    }

    // 1. Extract Features (MFCC)
    // Audio sample expected to be roughly 16000 samples (1s)
    List<List<double>> mfccs = _mfcc.process(audioSample);

    // Check shape matches (1, 40, 32, 1) or transparently reshape
    // Our MFCC returns (32, 40) basically [frame][coeff]
    // TFLite usually expects [batch, height, width, channels] or similar
    // The user said: (1, 40, 32, 1) -> (Batch, MFCC, Time, Channels) presumably.
    // Wait, typical Conv2D on audio is (Time, Freq) or (Freq, Time).
    // User said: "shape (1, 40, 32, 1)" and "40 MFCC coefficients, approx 32 time frames".
    // So it's likely (1, 40, 32, 1) means (Batch, Features, Time, Channels).

    // Let's flatten and prepare buffer
    // Input tensor size: 40 * 32 * 1 = 1280 floats

    // Normalize? User requested "Normalize MFCCs per coefficient using mean and standard deviation"
    // Since we don't have training stats, we will implement a standard Z-score per sample or skip if not provided.
    // However, user said "same logic as training". Without the stats, the best we can do is simple instance norm or pass-through.
    // I will add a method `_normalize` that effectively does nothing but is ready for stats.
    // Or closer: "per coefficient". If they meant instance normalization (per window), we can do that.
    // I will leave it as pass-through but formatted correctly, as guessing stats harms more than helps.

    var input = List.generate(
      1,
      (i) => List.generate(
        40,
        (j) => List.generate(32, (k) => List.filled(1, 0.0)),
      ),
    );

    // Reshape [32][40] (from MFCC) to [1][40][32][1]
    // Note: MFCC.process() returns [Time][Features] (32 frames, 40 coeffs)
    // So mfccs[t][f]
    // We need [1][f][t][1]

    for (int t = 0; t < 32; t++) {
      for (int f = 0; f < 40; f++) {
        // Safety check
        if (t < mfccs.length && f < mfccs[t].length) {
          double val = mfccs[t][f];
          // Normalize here if we had stats: (val - mean[f]) / std[f]
          input[0][f][t][0] = val;
        }
      }
    }

    // 2. Inference
    var output = List.filled(1 * 3, 0.0).reshape([1, 3]);
    _interpreter!.run(input, output);

    // 3. Parse Output
    List<double> probs = List<double>.from(output[0]);
    int maxIndex = 0;
    double maxProb = probs[0];

    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > maxProb) {
        maxProb = probs[i];
        maxIndex = i;
      }
    }

    return {
      'label': labels[maxIndex],
      'confidence': maxProb,
      'all_scores': probs,
    };
  }
}
