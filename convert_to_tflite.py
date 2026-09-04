import tensorflow as tf
from pathlib import Path
import os

MODELS_DIR = Path("ml/models")
KERAS_MODEL_PATH = MODELS_DIR / "audio_classifier.keras"
TFLITE_MODEL_PATH = MODELS_DIR / "audio_classifier.tflite"

if not KERAS_MODEL_PATH.exists():
    print(f"Error: {KERAS_MODEL_PATH} not found.")
    exit(1)

print("Loading Keras model...")
model = tf.keras.models.load_model(KERAS_MODEL_PATH)

print("Converting to TFLite...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# optimizations
converter.optimizations = [tf.lite.Optimize.DEFAULT]

tflite_model = converter.convert()

print(f"Saving to {TFLITE_MODEL_PATH}...")
with open(TFLITE_MODEL_PATH, "wb") as f:
    f.write(tflite_model)

# Check sizes
keras_size = os.path.getsize(KERAS_MODEL_PATH) / 1024
tflite_size = os.path.getsize(TFLITE_MODEL_PATH) / 1024

print(f"Conversion complete.")
print(f"Keras Model Size: {keras_size:.2f} KB")
print(f"TFLite Model Size: {tflite_size:.2f} KB")
print(f"Reduction: {(1 - tflite_size/keras_size)*100:.1f}%")
