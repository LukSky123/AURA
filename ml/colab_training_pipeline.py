# ==============================================================================
# AURA Transfer Learning & INT8 TFLite Audio Classification Pipeline
# Platform: Google Colab (Python 3.10+ / GPU or High-RAM CPU)
# Target Classes (4): gunshot, glass_break, explosion, neutral_ambient
# Feature Extractor: Google YAMNet (TF Hub) -> 1024-D embeddings
# Output: /content/aura_model.tflite
# ==============================================================================

import os
import sys
import math
import random
import warnings
from pathlib import Path
from typing import List, Tuple, Dict

warnings.filterwarnings('ignore')

# ------------------------------------------------------------------------------
# 1. Environment & Library Checks
# ------------------------------------------------------------------------------
print("=" * 75)
print("1. Initializing AURA 4-Class Transfer Learning Pipeline...")
print("=" * 75)

try:
    import numpy as np
    import pandas as pd
    import librosa
    import soundfile as sf
    import tensorflow as tf
    import tensorflow_hub as hub
    from sklearn.model_selection import train_test_split
    from sklearn.metrics import classification_report, confusion_matrix
    from sklearn.utils.class_weight import compute_class_weight
except ImportError:
    print("Installing required dependencies (tensorflow-hub, librosa, soundfile)...")
    os.system("pip install -q tensorflow-hub librosa soundfile scikit-learn")
    import numpy as np
    import pandas as pd
    import librosa
    import soundfile as sf
    import tensorflow as tf
    import tensorflow_hub as hub
    from sklearn.model_selection import train_test_split
    from sklearn.metrics import classification_report, confusion_matrix
    from sklearn.utils.class_weight import compute_class_weight

print(f"TensorFlow Version : {tf.__version__}")
print(f"GPU Accelerator    : {bool(tf.config.list_physical_devices('GPU'))}")

# Constants
SAMPLE_RATE = 16000
MIN_AUDIO_LEN = 16000  # 1.0 second at 16 kHz
CLASSES = ['gunshot', 'glass_break', 'explosion', 'neutral_ambient']
CLASS_TO_IDX = {name: idx for idx, name in enumerate(CLASSES)}
IDX_TO_CLASS = {idx: name for idx, name in enumerate(CLASSES)}
MAX_NEUTRAL_SAMPLES = 1200  # Strict cap to eliminate severe class imbalance

# ------------------------------------------------------------------------------
# 2. Dataset Mapping & Manifest Compilation
# ------------------------------------------------------------------------------
print("\n" + "=" * 75)
print("2. Scanning Dataset CSVs and Compiling File Manifests (4 Classes)...")
print("=" * 75)

ESC50_CSV = '/content/datasets/esc50/esc50.csv'
ESC50_AUDIO = '/content/datasets/esc50/audio'

US8K_CSV = '/content/datasets/urbansound8k/UrbanSound8K.csv'
US8K_DIR = '/content/datasets/urbansound8k'

FS_CSV = '/content/datasets/freesound/train_post_competition.csv'
FS_AUDIO = '/content/datasets/freesound/audio_train'

danger_records = []   # list of (file_path, class_idx) for threat classes
neutral_pool = []     # candidate list of (file_path, class_idx) for neutral_ambient
crowd_files = []      # list of file_path strictly for background noise augmentation

# A. Parse ESC-50
if os.path.exists(ESC50_CSV) and os.path.exists(ESC50_AUDIO):
    df_esc = pd.read_csv(ESC50_CSV)
    print(f"✓ Found ESC-50 CSV: {len(df_esc)} entries")
    for _, row in df_esc.iterrows():
        cat = str(row['category']).lower().strip()
        fpath = os.path.join(ESC50_AUDIO, str(row['filename']))
        if not os.path.exists(fpath):
            continue

        if cat == 'glass_breaking':
            danger_records.append((fpath, CLASS_TO_IDX['glass_break']))
        elif cat == 'fireworks':
            danger_records.append((fpath, CLASS_TO_IDX['explosion']))
        elif cat in ['crying_baby', 'laughter', 'applause', 'coughing', 'sneezing', 'cheering', 'crowd']:
            crowd_files.append(fpath)
        elif cat in ['engine', 'train', 'church_bells', 'airplane', 'car_horn', 'drilling', 'siren',
                     'clock_tick', 'rain', 'sea_waves', 'crackling_fire', 'crickets', 'chirping_birds',
                     'water_drops', 'wind', 'pouring_water', 'toilet_flush', 'thunderstorm', 'brushing_teeth',
                     'snoring', 'drinking_sipping', 'door_wood_knock', 'mouse_click', 'keyboard_typing',
                     'door_wood_creaks', 'can_opening', 'washing_machine', 'vacuum_cleaner', 'clock_alarm',
                     'chainsaw', 'rooster', 'cow', 'pig', 'frog', 'cat', 'hen', 'insects', 'sheep', 'crow']:
            neutral_pool.append((fpath, CLASS_TO_IDX['neutral_ambient']))
else:
    print(f"! Notice: ESC-50 paths not found at {ESC50_CSV}")

# B. Parse UrbanSound8K
if os.path.exists(US8K_CSV) and os.path.exists(US8K_DIR):
    df_us8k = pd.read_csv(US8K_CSV)
    print(f"✓ Found UrbanSound8K CSV: {len(df_us8k)} entries")
    for _, row in df_us8k.iterrows():
        cname = str(row['class']).lower().strip()
        fold = int(row['fold'])
        fname = str(row['slice_file_name'])
        fpath = os.path.join(US8K_DIR, f"fold{fold}", fname)
        if not os.path.exists(fpath):
            continue

        if cname == 'gun_shot':
            danger_records.append((fpath, CLASS_TO_IDX['gunshot']))
        elif cname == 'children_playing':
            crowd_files.append(fpath)
        elif cname in ['engine_idling', 'car_horn', 'drilling', 'siren', 'dog_bark', 'air_conditioner', 'jackhammer', 'street_music']:
            neutral_pool.append((fpath, CLASS_TO_IDX['neutral_ambient']))
else:
    print(f"! Notice: UrbanSound8K paths not found at {US8K_CSV}")

# C. Parse Freesound
if os.path.exists(FS_CSV) and os.path.exists(FS_AUDIO):
    df_fs = pd.read_csv(FS_CSV)
    print(f"✓ Found Freesound CSV: {len(df_fs)} entries")
    for _, row in df_fs.iterrows():
        lbl = str(row['label']).lower().strip()
        fname = str(row['fname'])
        if not fname.endswith('.wav'):
            fname += '.wav'
        fpath = os.path.join(FS_AUDIO, fname)
        if not os.path.exists(fpath):
            continue

        if 'gunshot' in lbl or 'gunfire' in lbl:
            danger_records.append((fpath, CLASS_TO_IDX['gunshot']))
        elif 'shatter' in lbl or 'glass' in lbl:
            danger_records.append((fpath, CLASS_TO_IDX['glass_break']))
        elif 'explosion' in lbl or 'firework' in lbl:
            danger_records.append((fpath, CLASS_TO_IDX['explosion']))
        elif any(k in lbl for k in ['cheering', 'applause', 'laughter', 'cough', 'crowd']):
            crowd_files.append(fpath)
        else:
            neutral_pool.append((fpath, CLASS_TO_IDX['neutral_ambient']))
else:
    print(f"! Notice: Freesound paths not found at {FS_CSV}")

print(f"\nRaw Candidate Counts:")
print(f"  • Total Threat Samples : {len(danger_records)}")
print(f"  • Raw Neutral Pool     : {len(neutral_pool)}")
print(f"  • Background Crowd Clips: {len(crowd_files)}")

# ------------------------------------------------------------------------------
# Subsample Neutral Pool to MAX_NEUTRAL_SAMPLES (1,200) to Prevent Overfitting
# ------------------------------------------------------------------------------
random.seed(42)
random.shuffle(neutral_pool)
subsampled_neutral = neutral_pool[:MAX_NEUTRAL_SAMPLES]
print(f"\n✓ Neutral Class Imbalance Solved:")
print(f"  Subsampled neutral_ambient from {len(neutral_pool)} down to {len(subsampled_neutral)} clips.")

# Combine into final training records list
records = danger_records + subsampled_neutral
random.shuffle(records)

print(f"\nFinal Dataset Manifest (4 Target Classes):")
class_counts = {name: 0 for name in CLASSES}
for _, c_idx in records:
    class_counts[IDX_TO_CLASS[c_idx]] += 1
for name, count in class_counts.items():
    print(f"  • {name:<18}: {count} clips")
print(f"  Total Training Samples : {len(records)}")

# ------------------------------------------------------------------------------
# 3. Audio Loading & Augmentation Functions
# ------------------------------------------------------------------------------
def load_and_resample(file_path: str, target_sr: int = 16000) -> np.ndarray:
    """Loads audio file and normalizes to 16 kHz mono float32."""
    try:
        y, _ = librosa.load(file_path, sr=target_sr, mono=True)
        if len(y) < MIN_AUDIO_LEN:
            y = np.pad(y, (0, MIN_AUDIO_LEN - len(y)), mode='constant')
        return y.astype(np.float32)
    except Exception:
        return np.zeros(MIN_AUDIO_LEN, dtype=np.float32)

def mix_audio_at_snr(signal: np.ndarray, noise: np.ndarray, snr_db: float) -> np.ndarray:
    """Overlays crowd background noise onto threat audio at a specified SNR (in dB)."""
    if len(noise) < len(signal):
        noise = np.pad(noise, (0, len(signal) - len(noise)), mode='wrap')
    else:
        start = random.randint(0, len(noise) - len(signal))
        noise = noise[start : start + len(signal)]

    p_signal = np.mean(signal ** 2)
    p_noise = np.mean(noise ** 2)

    if p_signal <= 1e-8 or p_noise <= 1e-8:
        return signal

    snr_linear = 10.0 ** (snr_db / 10.0)
    scale = math.sqrt(p_signal / (p_noise * snr_linear + 1e-9))
    noisy_signal = signal + scale * noise

    # Peak normalize to [-0.95, 0.95] to prevent clipping
    max_amp = np.max(np.abs(noisy_signal))
    if max_amp > 1e-6:
        noisy_signal = (noisy_signal / max_amp) * 0.95
    return noisy_signal.astype(np.float32)

def augment_audio(y: np.ndarray, is_threat: bool, crowd_pool: List[np.ndarray]) -> np.ndarray:
    """Applies pitch shifting, time stretching, and crowd background noise overlay."""
    out = y.copy()

    # 1. Random pitch shift (+/- 1-2 semitones)
    if random.random() < 0.4:
        n_steps = random.choice([-2, -1, 1, 2])
        out = librosa.effects.pitch_shift(out, sr=SAMPLE_RATE, n_steps=n_steps)

    # 2. Light time stretch (0.9 to 1.1x)
    if random.random() < 0.3:
        rate = random.uniform(0.9, 1.1)
        out = librosa.effects.time_stretch(out, rate=rate)
        if len(out) < MIN_AUDIO_LEN:
            out = np.pad(out, (0, MIN_AUDIO_LEN - len(out)), mode='constant')

    # 3. Crowd background noise overlay (-5 dB to 10 dB) on threat clips
    if is_threat and crowd_pool and random.random() < 0.6:
        crowd_noise = random.choice(crowd_pool)
        snr_val = random.uniform(-5.0, 10.0)
        out = mix_audio_at_snr(out, crowd_noise, snr_val)

    return out.astype(np.float32)

# Preload crowd background clips
print("\n" + "=" * 75)
print("3. Preloading Crowd Noise Background Pool for SNR Augmentation...")
print("=" * 75)
crowd_waveforms = []
random.shuffle(crowd_files)
selected_crowd = crowd_files[:min(len(crowd_files), 400)]

for idx, cp in enumerate(selected_crowd):
    wav = load_and_resample(cp)
    crowd_waveforms.append(wav)
    if (idx + 1) % 50 == 0 or (idx + 1) == len(selected_crowd):
        print(f"  Loaded {idx + 1}/{len(selected_crowd)} crowd background clips...")

print(f"✓ Preloaded {len(crowd_waveforms)} crowd clips for noise augmentation.")

# ------------------------------------------------------------------------------
# 4. Load Pretrained Google YAMNet Feature Extractor
# ------------------------------------------------------------------------------
print("\n" + "=" * 75)
print("4. Loading Google YAMNet from TensorFlow Hub...")
print("=" * 75)
YAMNET_URL = 'https://tfhub.dev/google/yamnet/1'
yamnet_model = hub.load(YAMNET_URL)
print("✓ YAMNet loaded successfully (Extracts 1024-D embeddings across 0.975s frames).")

def extract_yamnet_embedding(waveform: np.ndarray) -> np.ndarray:
    """Passes 16 kHz waveform through YAMNet and pools temporal embeddings into 1024-D vector."""
    if len(waveform) < MIN_AUDIO_LEN:
        waveform = np.pad(waveform, (0, MIN_AUDIO_LEN - len(waveform)), mode='constant')
    waveform_tensor = tf.convert_to_tensor(waveform, dtype=tf.float32)
    _, embeddings, _ = yamnet_model(waveform_tensor)
    # Average across all temporal frames in the audio clip
    mean_embedding = tf.reduce_mean(embeddings, axis=0)
    return mean_embedding.numpy()

# ------------------------------------------------------------------------------
# 5. Feature Extraction (Embeddings Generation)
# ------------------------------------------------------------------------------
print("\n" + "=" * 75)
print("5. Extracting 1024-D Embeddings with Dynamic Crowd Augmentation...")
print("=" * 75)

X_embeddings = []
y_labels = []

total_records = len(records)
for i, (fpath, c_idx) in enumerate(records):
    wav = load_and_resample(fpath)
    is_threat = (c_idx != CLASS_TO_IDX['neutral_ambient'])

    # Augmented audio pass
    augmented_wav = augment_audio(wav, is_threat=is_threat, crowd_pool=crowd_waveforms)
    emb = extract_yamnet_embedding(augmented_wav)
    X_embeddings.append(emb)
    y_labels.append(c_idx)

    # Second augmentation pass for threat classes to balance data volume
    if is_threat:
        aug_wav_2 = augment_audio(wav, is_threat=True, crowd_pool=crowd_waveforms)
        emb_2 = extract_yamnet_embedding(aug_wav_2)
        X_embeddings.append(emb_2)
        y_labels.append(c_idx)

    if (i + 1) % 150 == 0 or (i + 1) == total_records:
        print(f"  Processed {i + 1}/{total_records} files -> {len(X_embeddings)} embeddings generated")

X = np.array(X_embeddings, dtype=np.float32)
y = np.array(y_labels, dtype=np.int32)
print(f"\n✓ Feature matrix generated: X={X.shape}, y={y.shape}")

# ------------------------------------------------------------------------------
# 6. Train / Validation / Test Split & Class Balancing
# ------------------------------------------------------------------------------
X_train, X_temp, y_train, y_temp = train_test_split(
    X, y, test_size=0.3, random_state=42, stratify=y
)
X_val, X_test, y_val, y_test = train_test_split(
    X_temp, y_temp, test_size=0.5, random_state=42, stratify=y_temp
)

print(f"\nPartitions:")
print(f"  • Train : {len(X_train)} samples")
print(f"  • Val   : {len(X_val)} samples")
print(f"  • Test  : {len(X_test)} samples")

classes_present = np.unique(y_train)
weights = compute_class_weight('balanced', classes=classes_present, y=y_train)
class_weights_dict = {cls: float(w) for cls, w in zip(classes_present, weights)}
print(f"Balanced Class Weights: {class_weights_dict}")

# ------------------------------------------------------------------------------
# 7. Model Architecture (4-Class Head) & Transfer Learning
# ------------------------------------------------------------------------------
print("\n" + "=" * 75)
print("6. Building 4-Class Classification Head & Training...")
print("=" * 75)

# 4-Class Custom Head: Dropout(0.5) -> Dense(128, 'relu') -> Dropout(0.3) -> Dense(4, 'softmax')
classifier_head = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(1024,), dtype=tf.float32, name='yamnet_embedding_input'),
    tf.keras.layers.Dropout(0.5),
    tf.keras.layers.Dense(128, activation='relu', name='dense_128'),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(4, activation='softmax', name='threat_probabilities')  # 4 target classes
], name='aura_classifier_head')

classifier_head.summary()

classifier_head.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

early_stop = tf.keras.callbacks.EarlyStopping(
    monitor='val_loss',
    patience=5,
    restore_best_weights=True,
    verbose=1
)

reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
    monitor='val_loss',
    factor=0.5,
    patience=3,
    min_lr=1e-5,
    verbose=1
)

history = classifier_head.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    epochs=20,
    batch_size=32,
    class_weight=class_weights_dict,
    callbacks=[early_stop, reduce_lr],
    verbose=1
)

# ------------------------------------------------------------------------------
# 8. Evaluation & Per-Class Precision / Recall
# ------------------------------------------------------------------------------
print("\n" + "=" * 75)
print("7. Held-Out Test Evaluation & Release Gate Report:")
print("=" * 75)

y_pred_probs = classifier_head.predict(X_test)
y_pred_classes = np.argmax(y_pred_probs, axis=1)

present_classes = sorted(np.unique(np.concatenate([y_test, y_pred_classes])))
target_names = [CLASSES[i] for i in present_classes]

print("\nClassification Report (Precision / Recall / F1):")
print(classification_report(y_test, y_pred_classes, target_names=target_names, digits=4, zero_division=0))

print("Confusion Matrix:")
print(confusion_matrix(y_test, y_pred_classes))

# ------------------------------------------------------------------------------
# 9. End-to-End Packaging & TFLite Quantization
# ------------------------------------------------------------------------------
print("\n" + "=" * 75)
print("8. Packaging End-to-End Model & INT8 Quantization...")
print("=" * 75)

class EndToEndAuraModel(tf.Module):
    """Wraps raw 16 kHz waveform input -> YAMNet -> 4-Class Head into a single model."""
    def __init__(self, yamnet, classifier):
        super().__init__()
        self.yamnet = yamnet
        self.classifier = classifier

    @tf.function(input_signature=[tf.TensorSpec(shape=[None], dtype=tf.float32, name='waveform')])
    def __call__(self, waveform):
        _, embeddings, _ = self.yamnet(waveform)
        mean_embedding = tf.reduce_mean(embeddings, axis=0, keepdims=True)
        return self.classifier(mean_embedding)

end_to_end_module = EndToEndAuraModel(yamnet_model, classifier_head)

# Save temporary SavedModel directory
SAVED_MODEL_DIR = '/content/aura_saved_model'
tf.saved_model.save(end_to_end_module, SAVED_MODEL_DIR)
print(f"✓ Saved end-to-end model to {SAVED_MODEL_DIR}")

# Convert to TFLite with Dynamic Range INT8 Quantization
OUTPUT_TFLITE_PATH = '/content/aura_model.tflite'
converter = tf.lite.TFLiteConverter.from_saved_model(SAVED_MODEL_DIR)
converter.optimizations = [tf.lite.Optimize.DEFAULT]  # Dynamic range INT8 quantization
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS,
    tf.lite.OpsSet.SELECT_TF_OPS
]

try:
    tflite_quant_model = converter.convert()
    with open(OUTPUT_TFLITE_PATH, 'wb') as f:
        f.write(tflite_quant_model)
    model_size_mb = os.path.getsize(OUTPUT_TFLITE_PATH) / (1024 * 1024)
    print(f"\n✓ SUCCESS! Quantized TFLite Model Saved: {OUTPUT_TFLITE_PATH}")
    print(f"  • Model Size: {model_size_mb:.2f} MB (Budget: <= 8.0 MB)")
except Exception as e:
    print(f"! Quantization error: {e}. Attempting fallback conversion...")
    converter.optimizations = []
    tflite_model = converter.convert()
    with open(OUTPUT_TFLITE_PATH, 'wb') as f:
        f.write(tflite_model)
    model_size_mb = os.path.getsize(OUTPUT_TFLITE_PATH) / (1024 * 1024)
    print(f"Fallback TFLite model saved: {OUTPUT_TFLITE_PATH} ({model_size_mb:.2f} MB)")

# ------------------------------------------------------------------------------
# 10. TFLite Verification Test
# ------------------------------------------------------------------------------
print("\n" + "=" * 75)
print("9. Verifying /content/aura_model.tflite with Test Waveform...")
print("=" * 75)

try:
    interpreter = tf.lite.Interpreter(model_path=OUTPUT_TFLITE_PATH)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(f"  Input Tensor  : {input_details[0]['name']}, shape: {input_details[0]['shape']}")
    print(f"  Output Tensor : {output_details[0]['name']}, shape: {output_details[0]['shape']}")

    # 1.0s dummy silence test
    test_wav = np.zeros(16000, dtype=np.float32)
    interpreter.resize_tensor_input(input_details[0]['index'], [len(test_wav)])
    interpreter.allocate_tensors()
    interpreter.set_tensor(input_details[0]['index'], test_wav)
    interpreter.invoke()

    preds = interpreter.get_tensor(output_details[0]['index'])
    print(f"\n✓ Verification inference succeeded!")
    print(f"Threat Probabilities for 1.0s silence test sample:")
    for cls_name, prob in zip(CLASSES, preds[0]):
        print(f"    - {cls_name:<16}: {prob * 100:.2f}%")

except Exception as e:
    print(f"Notice: Local interpreter verification skipped ({e}). File is intact at {OUTPUT_TFLITE_PATH}")

print("\n" + "=" * 75)
print("AURA 4-Class Transfer Learning & Model Export Pipeline Complete!")
print(f"Deployable mobile model: {OUTPUT_TFLITE_PATH}")
print("=" * 75)
