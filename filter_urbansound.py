import pandas as pd
import shutil
from pathlib import Path

# Paths
US_ROOT = Path("datasets/UrbanSound8K/UrbanSound8K")
CSV_PATH = US_ROOT / "metadata" / "UrbanSound8K.csv"
AUDIO_ROOT = US_ROOT / "audio"

OUTPUT_ROOT = Path("ml/data/raw")

# Class mapping
CLASS_MAP = {
    "gun_shot": "gunshot",
    "glass_breaking": "glass",
    "crowd": "crowd"
}

df = pd.read_csv(CSV_PATH)

copied = 0

for _, row in df.iterrows():
    sound_class = row["class"]
    filename = row["slice_file_name"]
    fold = f"fold{row['fold']}"

    if sound_class in CLASS_MAP:
        src = AUDIO_ROOT / fold / filename
        dst = OUTPUT_ROOT / CLASS_MAP[sound_class] / filename

        if src.exists():
            shutil.copy(src, dst)
            copied += 1

print(f"UrbanSound8K: copied {copied} files.")
