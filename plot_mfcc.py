import librosa
import librosa.display
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import random
from pathlib import Path

# Setup paths
DATA_DIR = Path("ml/data/raw")
OUTPUT_FILE = "mfcc_plot.png"

# Find all wav files
all_files = list(DATA_DIR.rglob("*.wav"))

if not all_files:
    print("No WAV files found in ml/data/raw")
    exit(1)

# Select random file
selected_file = random.choice(all_files)
print(f"Selected file: {selected_file}")

# Load audio
y, sr = librosa.load(selected_file)

# Compute MFCC
mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)

# Plot
plt.figure(figsize=(10, 4))
librosa.display.specshow(mfccs, x_axis='time')
plt.colorbar()
plt.title(f'MFCC: {selected_file.name}')
plt.tight_layout()
plt.savefig(OUTPUT_FILE)
print(f"Plot saved to {OUTPUT_FILE}")
