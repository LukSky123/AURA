import librosa
import numpy as np
from pathlib import Path
import warnings

# Suppress warnings
warnings.filterwarnings("ignore")

DATA_DIR = Path("ml/data/raw")
CLASSES = ["gunshot", "glass", "crowd"]

print(f"{'Class':<15} {'Count':<10} {'Min (s)':<10} {'Max (s)':<10} {'Avg (s)':<10}")
print("-" * 60)

for class_name in CLASSES:
    class_dir = DATA_DIR / class_name
    if not class_dir.exists():
        print(f"{class_name:<15} {'NOT FOUND':<10}")
        continue

    durations = []
    files = list(class_dir.glob("*.wav"))
    
    for wav_file in files:
        try:
            # Using librosa.get_duration(path=...) which is faster as it doesn't decode audio fully if not needed
            # or usage of load if version is older, but simplest is to try-except or just load
            # Let's just use load to be safe across versions or check doc. 
            # safe: librosa.get_duration(y=y, sr=sr)
             d = librosa.get_duration(path=wav_file)
             durations.append(d)
        except Exception as e:
            print(f"Error reading {wav_file}: {e}")

    if durations:
        d_min = np.min(durations)
        d_max = np.max(durations)
        d_avg = np.mean(durations)
        print(f"{class_name:<15} {len(durations):<10} {d_min:<10.2f} {d_max:<10.2f} {d_avg:<10.2f}")
    else:
        print(f"{class_name:<15} {0:<10} {'-':<10} {'-':<10} {'-':<10}")
