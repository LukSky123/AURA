import librosa
import numpy as np
from pathlib import Path
import warnings

warnings.filterwarnings("ignore")

SAMPLE_RATE = 16000
N_MFCC = 40

PROCESSED_DIR = Path("ml/data/processed")
FEATURES_DIR = Path("ml/data/features")
FEATURES_DIR.mkdir(parents=True, exist_ok=True)

CLASSES = ["gunshot", "glass", "crowd"]

for class_name in CLASSES:
    class_dir = PROCESSED_DIR / class_name
    output_path = FEATURES_DIR / f"{class_name}.npy"
    
    if not class_dir.exists():
        print(f"Skipping {class_name} (not found)")
        continue

    print(f"Extracting features for {class_name}...")
    
    features_list = []
    files = list(class_dir.glob("*.wav"))
    
    if not files:
        print(f"No files found for {class_name}")
        continue

    for file_path in files:
        try:
            y, sr = librosa.load(file_path, sr=SAMPLE_RATE)
            
            # Extract MFCCs
            mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=N_MFCC)
            
            # Normalize (Standardize) per sample across time
            mean = np.mean(mfcc, axis=1, keepdims=True)
            std = np.std(mfcc, axis=1, keepdims=True)
            mfcc_norm = (mfcc - mean) / (std + 1e-6) # Add epsilon just in case
            
            features_list.append(mfcc_norm)
            
        except Exception as e:
            print(f"Error processing {file_path.name}: {e}")

    if features_list:
        # Stack to create (N, 40, Time) array
        features_array = np.array(features_list)
        np.save(output_path, features_array)
        print(f"Saved {output_path}: {features_array.shape}")
    else:
        print(f"No features extracted for {class_name}")

print("Feature extraction complete.")
