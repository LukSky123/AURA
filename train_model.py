import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models, regularizers
from pathlib import Path
import matplotlib.pyplot as plt

# Load Data
DATA_DIR = Path("ml/data/dataset")
X_train = np.load(DATA_DIR / "X_train.npy")
y_train = np.load(DATA_DIR / "y_train.npy")
X_val = np.load(DATA_DIR / "X_val.npy")
y_val = np.load(DATA_DIR / "y_val.npy")

print(f"Loaded X_train: {X_train.shape}")
print(f"Loaded X_val: {X_val.shape}")

# Model Architecture
# Input shape: (40, 32, 1)
input_shape = X_train.shape[1:]
num_classes = 3

model = models.Sequential([
    layers.Input(shape=input_shape),
    
    # Block 1
    layers.Conv2D(16, (3, 3), padding='same'),
    layers.BatchNormalization(),
    layers.Activation('relu'),
    layers.MaxPooling2D((2, 2)), # -> (20, 16, 16)
    
    # Block 2
    layers.Conv2D(32, (3, 3), padding='same'),
    layers.BatchNormalization(),
    layers.Activation('relu'),
    layers.MaxPooling2D((2, 2)), # -> (10, 8, 32)
    
    # Block 3
    layers.Conv2D(64, (3, 3), padding='same'),
    layers.BatchNormalization(),
    layers.Activation('relu'),
    # No MaxPool here, let GAP handle it to preserve spatial features for GAP
    
    # Global Average Pooling (Replaces Flatten -> Dense, reducing params significantly)
    layers.GlobalAveragePooling2D(),
    
    # Output
    layers.Dropout(0.3),
    layers.Dense(num_classes, activation='softmax')
])

model.summary()

# Compile
model.compile(optimizer='adam',
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])

# Train
history = model.fit(X_train, y_train, 
                    epochs=20, 
                    batch_size=32, 
                    validation_data=(X_val, y_val))

# Save
MODELS_DIR = Path("ml/models")
MODELS_DIR.mkdir(parents=True, exist_ok=True)
model.save(MODELS_DIR / "audio_classifier.keras")
print(f"Model saved to {MODELS_DIR / 'audio_classifier.keras'}")

# Plot history
plt.figure(figsize=(10, 4))
plt.subplot(1, 2, 1)
plt.plot(history.history['accuracy'], label='Train')
plt.plot(history.history['val_accuracy'], label='Val')
plt.title('Accuracy')
plt.legend()

plt.subplot(1, 2, 2)
plt.plot(history.history['loss'], label='Train')
plt.plot(history.history['val_loss'], label='Val')
plt.title('Loss')
plt.legend()

plt.savefig(MODELS_DIR / "training_history.png")
print("History plot saved.")
