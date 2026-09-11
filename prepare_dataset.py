import numpy as np
from pathlib import Path
from sklearn.model_selection import train_test_split

PROCESSED_DIR = Path("ml/data/features")
OUTPUT_DIR = Path("ml/data/dataset")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Define fixed class mapping
CLASS_MAP = {
    "gunshot": 0,
    "glass": 1,
    "crowd": 2
}

X_list = []
y_list = []

print("Loading features...")

for class_name, label in CLASS_MAP.items():
    file_path = PROCESSED_DIR / f"{class_name}.npy"
    if not file_path.exists():
        print(f"Warning: {file_path} not found. Skipping class '{class_name}'.")
        continue

    data = np.load(file_path)
    if data.size == 0:
        print(f"Warning: {file_path} is empty. Skipping.")
        continue
        
    print(f"Loaded {class_name}: {data.shape}")
    
    X_list.append(data)
    # Create labels array of same length
    y_list.append(np.full(len(data), label))

if not X_list:
    print("Error: No data found.")
    exit(1)

# Concatenate
X = np.concatenate(X_list, axis=0)
y = np.concatenate(y_list, axis=0)

print(f"Total samples: {len(X)}")

# Reshape for CNN input: (Batch, Rows, Cols, Channels)
# Our data is (Batch, 40, Time). We want (Batch, 40, Time, 1)
X = X[..., np.newaxis]

print(f"Reshaped X: {X.shape}")

# Split into Train and Val
# Stratify ensuring we keep class distribution (if possible)
# Note: if a class has very few samples, stratify might fail. 
# Glass has 200 samples, Gunshot 802.
X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

print(f"Training set: X={X_train.shape}, y={y_train.shape}")
print(f"Validation set: X={X_val.shape}, y={y_val.shape}")

# Save the dataset
np.save(OUTPUT_DIR / "X_train.npy", X_train)
np.save(OUTPUT_DIR / "y_train.npy", y_train)
np.save(OUTPUT_DIR / "X_val.npy", X_val)
np.save(OUTPUT_DIR / "y_val.npy", y_val)

print("Dataset saved to ml/data/dataset/")
