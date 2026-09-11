import librosa
import soundfile as sf
import numpy as np
from pathlib import Path
import warnings

warnings.filterwarnings("ignore")

SAMPLE_RATE = 16000
TARGET_DURATION = 1.0
TARGET_SAMPLES = int(SAMPLE_RATE * TARGET_DURATION)

RAW_DIR = Path("ml/data/raw")
PROCESSED_DIR = Path("ml/data/processed")

CLASSES = ["gunshot", "glass", "crowd"]

for class_name in CLASSES:
    src_dir = RAW_DIR / class_name
    dst_dir = PROCESSED_DIR / class_name
    
    if not src_dir.exists():
        continue
        
    dst_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Processing {class_name}...")
    
    files = list(src_dir.glob("*.wav"))
    for file_path in files:
        try:
            # Load: Resample to 16k, Force Mono
            y, sr = librosa.load(file_path, sr=SAMPLE_RATE, mono=True)
            
            # Pad if too short
            if len(y) < TARGET_SAMPLES:
                padding = TARGET_SAMPLES - len(y)
                y = np.pad(y, (0, padding), 'constant')
                
                out_name = dst_dir / f"{file_path.stem}.wav"
                sf.write(out_name, y, SAMPLE_RATE)
                
            # Split if too long
            else:
                num_chunks = int(np.ceil(len(y) / TARGET_SAMPLES))
                for i in range(num_chunks):
                    start = i * TARGET_SAMPLES
                    end = start + TARGET_SAMPLES
                    chunk = y[start:end]
                    
                    # Pad last chunk if needed
                    if len(chunk) < TARGET_SAMPLES:
                        padding = TARGET_SAMPLES - len(chunk)
                        chunk = np.pad(chunk, (0, padding), 'constant')
                    
                    out_name = dst_dir / f"{file_path.stem}_chunk{i}.wav"
                    sf.write(out_name, chunk, SAMPLE_RATE)
                    
        except Exception as e:
            print(f"Error processing {file_path.name}: {e}")

print("Preprocessing complete.")
