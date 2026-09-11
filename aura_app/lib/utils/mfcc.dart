import 'dart:math';
import 'dart:typed_data';

class MFCC {
  final int sampleRate;
  final int numMfcc;
  final int nFft;
  final int hopLength;
  late List<List<double>> melBasis;
  late List<double> window;

  MFCC({
    this.sampleRate = 16000,
    this.numMfcc = 40,
    this.nFft = 512, // Standard equivalent to 32ms frame approximately
    this.hopLength = 256, // Standard 50% overlap
  }) {
    _initializeMelBasis();
    _initializeWindow();
  }

  // --- Public Method: Process 1 second of audio ---
  List<List<double>> process(Float32List audio) {
    // 1. Frame signal
    List<List<double>> frames = _frameSignal(audio);

    List<List<double>> mfccs = [];

    for (var frame in frames) {
      // 2. Windowing
      for (int i = 0; i < frame.length; i++) {
        frame[i] *= window[i];
      }

      // 3. FFT Power Spectrum
      List<double> powerSpectrum = _computePowerSpectrum(frame);

      // 4. Mel Filterbank
      List<double> melEnergies = _applyMelFilterbank(powerSpectrum);

      // 5. Log Mel Energies
      List<double> logMelEnergies = melEnergies
          .map((e) => log(e + 1e-6))
          .toList();

      // 6. DCT (Discrete Cosine Transform) - Type II
      List<double> mfccFrame = _dct(logMelEnergies);

      mfccs.add(mfccFrame);
    }

    return mfccs;
  }

  // --- Internal Helpers ---

  void _initializeWindow() {
    window = List.generate(nFft, (i) {
      return 0.5 - 0.5 * cos(2 * pi * i / (nFft - 1)); // Hanning window
    });
  }

  void _initializeMelBasis() {
    int numMelBins =
        40; // Usually matches numMfcc or slightly higher for filterbank
    double lowFreq = 20.0;
    double highFreq = sampleRate / 2.0;

    double melLow = _hzToMel(lowFreq);
    double melHigh = _hzToMel(highFreq);

    List<double> melPoints = List.generate(numMelBins + 2, (i) {
      return _melToHz(melLow + (melHigh - melLow) * i / (numMelBins + 1));
    });

    List<int> binPoints = melPoints
        .map((freq) => ((nFft + 1) * freq / sampleRate).floor())
        .toList();

    melBasis = List.generate(numMelBins, (m) {
      List<double> filter = List.filled(nFft ~/ 2 + 1, 0.0);
      for (int k = 0; k < nFft ~/ 2 + 1; k++) {
        if (k >= binPoints[m] && k <= binPoints[m + 1]) {
          filter[k] = (k - binPoints[m]) / (binPoints[m + 1] - binPoints[m]);
        } else if (k >= binPoints[m + 1] && k <= binPoints[m + 2]) {
          filter[k] =
              (binPoints[m + 2] - k) / (binPoints[m + 2] - binPoints[m + 1]);
        }
      }
      return filter;
    });
  }

  double _hzToMel(double hz) => 2595 * log(1 + hz / 700);
  double _melToHz(double mel) => 700 * (exp(mel / 2595) - 1);

  List<List<double>> _frameSignal(Float32List audio) {
    List<List<double>> frames = [];
    int numFrames = 32; // Fixed to 32 as per requirement
    // If strict 32 frames needed, we can force or padding
    // Current hopLength 256 and nFft 512 on 16000 samples (1s) -> ~62 frames
    // Requirement says "approx 32 time frames".
    // 16000 samples / 32 frames = 500 samples per frame step approx.
    // Let's adjust stride to meet 32 frames specifically if needed,
    // or just take the first 32 frames effectively.

    // User asked for "approx 32 time frames".
    // If we use stride = 16000 / 32 = 500.
    // Let's try to fit standard framing.

    // Let's stick to standard calculation:
    // With 16000 samples, nFft 512, hop 500 (approx), we might get 32.
    // Let's dynamic hop for exactly 32 frames:
    int stride = (audio.length - nFft) ~/ (numFrames - 1);

    for (int i = 0; i < numFrames; i++) {
      int start = i * stride;
      if (start + nFft > audio.length) break;

      List<double> frame = audio
          .sublist(start, start + nFft)
          .map((e) => e.toDouble())
          .toList();
      frames.add(frame);
    }

    // Pad if necessary (though striving for exact 32)
    while (frames.length < 32) {
      frames.add(List.filled(nFft, 0.0));
    }

    return frames.sublist(0, 32);
  }

  List<double> _computePowerSpectrum(List<double> frame) {
    // Basic DFT implementation (O(N^2)) - for 512 points it's acceptable (~260k ops)
    // Optimization: Use FFT if available, but pure Dart simple FFT is complex to write inline.
    // Given 512 size, we can write a recursive or iterative FFT.

    // Implementing a simple Radix-2 FFT
    List<Complex> fftResult = _fft(frame.map((e) => Complex(e, 0)).toList());

    // Take magnitude squared for first half
    List<double> powerSpec = [];
    for (int i = 0; i < nFft ~/ 2 + 1; i++) {
      double mag = sqrt(
        fftResult[i].real * fftResult[i].real +
            fftResult[i].imag * fftResult[i].imag,
      );
      powerSpec.add((mag * mag) / nFft);
    }
    return powerSpec;
  }

  List<Complex> _fft(List<Complex> x) {
    int n = x.length;
    if (n <= 1) return x;

    List<Complex> even = _fft(List.generate(n ~/ 2, (i) => x[2 * i]));
    List<Complex> odd = _fft(List.generate(n ~/ 2, (i) => x[2 * i + 1]));

    List<Complex> result = List.generate(n, (i) => Complex(0, 0));
    for (int k = 0; k < n ~/ 2; k++) {
      double theta = -2 * pi * k / n;
      Complex t = Complex(cos(theta), sin(theta)) * odd[k];
      result[k] = even[k] + t;
      result[k + n ~/ 2] = even[k] - t;
    }
    return result;
  }

  List<double> _applyMelFilterbank(List<double> powerSpectrum) {
    List<double> energies = List.filled(melBasis.length, 0.0);
    for (int i = 0; i < melBasis.length; i++) {
      for (int j = 0; j < powerSpectrum.length; j++) {
        energies[i] += powerSpectrum[j] * melBasis[i][j];
      }
    }
    return energies;
  }

  List<double> _dct(List<double> logMelEnergies) {
    // Type II DCT
    int N = logMelEnergies.length;
    List<double> dctResult = List.filled(N, 0.0);

    for (int k = 0; k < N; k++) {
      double sum = 0.0;
      for (int n = 0; n < N; n++) {
        sum += logMelEnergies[n] * cos(pi * k * (2 * n + 1) / (2 * N));
      }
      // Orthogonalization usually typically doesn't scale first term in standard MFCC for ML unless specified
      // but standard DCT-II formula implies scaling.
      // Often in python librosa: dct_type=2, norm='ortho'
      // We will stick to unnormalized DCT-II often used in speech features
      dctResult[k] = sum;
    }
    return dctResult;
  }
}

class Complex {
  final double real;
  final double imag;
  Complex(this.real, this.imag);

  Complex operator +(Complex other) =>
      Complex(real + other.real, imag + other.imag);
  Complex operator -(Complex other) =>
      Complex(real - other.real, imag - other.imag);
  Complex operator *(Complex other) => Complex(
    real * other.real - imag * other.imag,
    real * other.imag + imag * other.real,
  );
}
