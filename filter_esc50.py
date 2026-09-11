import pandas as pd
import shutil
from pathlib import Path

# Paths
ESC_ROOT = Path("datasets/ESC-50-master/ESC-50-master")
AUDIO_DIR = ESC_ROOT / "audio"
CSV_PATH = ESC_ROOT / "meta" / "esc50.csv"

OUTPUT_ROOT = Path("ml/data/raw")

# Class mapping
CLASS_MAP = {
    "gun_shot": "gunshot",
    "glass_breaking": "glass",
    "crowd": "crowd"
}

# Load metadata
df = pd.read_csv(CSV_PATH)

copied = 0

for _, row in df.iterrows():
    category = row["category"]
    filename = row["filename"]

    if category in CLASS_MAP:
        src = AUDIO_DIR / filename
        dst = OUTPUT_ROOT / CLASS_MAP[category] / filename

        if src.exists():
            shutil.copy(src, dst)
            copied += 1

print(f"ESC-50: copied {copied} files.")
