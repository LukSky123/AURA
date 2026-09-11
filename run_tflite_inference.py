import numpy as np
import tensorflow as tf
from pathlib import Path
import random

MODELS_DIR = Path("ml/models")
DATA_DIR = Path("ml/data/dataset")
TFLITE_MODEL_PATH = MODELS_DIR / "audio_classifier.tflite"

# Load TFLite model
interpreter = tf.lite.Interpreter(model_path=str(TFLITE_MODEL_PATH))
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()
input_index = input_details[0]['index']
output_index = output_details[0]['index']

# Load Validation Data
X_val = np.load(DATA_DIR / "X_val.npy")
y_val = np.load(DATA_DIR / "y_val.npy")

CLASS_MAP = {0: "gunshot", 1: "glass", 2: "crowd"}
NUM_SAMPLES = 10

# Helper to predict
def predict(input_data):
    input_data = input_data.astype(np.float32)
    interpreter.set_tensor(input_index, input_data)
    interpreter.invoke()
    return interpreter.get_tensor(output_index)[0]

print(f"{'Index':<6} {'True Label':<12} {'Predicted':<12} {'Conf':<6} {'Result':<6}")
print("-" * 50)

# Random Indices
indices = random.sample(range(len(X_val)), NUM_SAMPLES)
correct_count = 0

for idx in indices:
    # Get sample with batch dim (1, 40, 32, 1)
    sample_input = X_val[idx:idx+1]
    true_label_idx = y_val[idx]
    
    probs = predict(sample_input)
    pred_label_idx = np.argmax(probs)
    confidence = probs[pred_label_idx]
    
    match = "YES" if pred_label_idx == true_label_idx else "NO "
    if match == "YES": correct_count += 1
    
    t_lbl = CLASS_MAP.get(true_label_idx, str(true_label_idx))
    p_lbl = CLASS_MAP.get(pred_label_idx, str(pred_label_idx))
    
    print(f"{idx:<6} {t_lbl:<12} {p_lbl:<12} {confidence:.2f}   {match}")

print("-" * 50)
print(f"Accuracy: {correct_count}/{NUM_SAMPLES} ({correct_count/NUM_SAMPLES*100:.0f}%)")
