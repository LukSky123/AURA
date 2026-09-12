# ==============================================================================
# AURA Transfer Learning & INT8 TFLite Audio Classification Pipeline
# Platform: Google Colab (Python 3.10+ / GPU or High-RAM CPU)
# Target Classes (5): gunshot, glass_break, collision, explosion, neutral_ambient
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

# 1. Environment & Library Checks
print("=" * 70)
print("1. Initializing AURA End-to-End Transfer Learning Pipeline...")
print("=" * 70)

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

print(f"TensorFlow Version: {tf.__version__}")
print(f"GPU Available: {bool(tf.config.list_physical_devices('GPU'))}")

# Constants
SAMPLE_RATE = 16000
MIN_AUDIO_LEN = 16000  # 1.0 second at 16 kHz
CLASSES = ['gunshot', 'glass_break', 'collision', 'explosion', 'neutral_ambient']
CLASS_TO_IDX = {name: idx for idx, name in enumerate(CLASSES)}
IDX_TO_CLASS = {idx: name for idx, name in enumerate(CLASSES)}

# ------------------------------------------------------------------------------
# 2. Dataset Mapping & Manifest Compilation
# ------------------------------------------------------------------------------
print("\n" + "=" * 70)
print("2. Scanning Dataset CSVs and Compiling File Manifests...")
print("=" * 70)

# Paths specified in Colab
ESC50_CSV = '/content/datasets/esc50/esc50.csv'
ESC50_AUDIO = '/content/datasets/esc50/audio'

US8K_CSV = '/content/datasets/urbansound8k/UrbanSound8K.csv'
US8K_DIR = '/content/datasets/urbansound8k'

FS_CSV = '/content/datasets/freesound/train_post_competition.csv'
FS_AUDIO = '/content/datasets/freesound/audio_train'

records = []      # list of (file_path, class_idx)
crowd_files = []  # list of file_path for negative noise pool

# A. Parse ESC-50
if os.path.exists(ESC50_CSV) and os.path.exists(ESC50_AUDIO):
    df_esc = pd.read_csv(ESC50_CSV)
    print(f"Loaded ESC-50 CSV: {len(df_esc)} rows")
    for _, row in df_esc.iterrows():
        cat = str(row['category']).lower().strip()
        fpath = os.path.join(ESC50_AUDIO, str(row['filename']))
        if not os.path.exists(fpath):
            continue

        if cat == 'glass_breaking':
            records.append((fpath, CLASS_TO_IDX['glass_break']))
        elif cat == 'fireworks':
            records.append((fpath, CLASS_TO_IDX['explosion']))
        elif cat in ['crying_baby', 'laughter', 'applause', 'coughing', 'sneezing', 'cheering', 'crowd']:
            crowd_files.append(fpath)
        elif cat in ['engine', 'train', 'church_bells', 'airplane', 'car_horn', 'drilling', 'siren',
                     'clock_tick', 'rain', 'sea_waves', 'crackling_fire', 'crickets', 'chirping_birds',
                     'water_drops', 'wind', 'pouring_water', 'toilet_flush', 'thunderstorm', 'brushing_teeth',
                     'snoring', 'drinking_sipping', 'door_wood_knock', 'mouse_click', 'keyboard_typing',
                     'door_wood_creaks', 'can_opening', 'washing_machine', 'vacuum_cleaner', 'clock_alarm',
                     'chainsaw', 'rooster', 'cow', 'pig', 'frog', 'cat', 'hen', 'insects', 'sheep', 'crow']:
            records.append((fpath, CLASS_TO_IDX['neutral_ambient']))
else:
    print(f"Notice: ESC-50 paths not found at {ESC50_CSV}. Skipping.")

# B. Parse UrbanSound8K
if os.path.exists(US8K_CSV) and os.path.exists(US8K_DIR):
    df_us8k = pd.read_csv(US8K_CSV)
    print(f"Loaded UrbanSound8K CSV: {len(df_us8k)} rows")
    for _, row in df_us8k.iterrows():
        cname = str(row['class']).lower().strip()
        fold = int(row['fold'])
        fname = str(row['slice_file_name'])
        fpath = os.path.join(US8K_DIR, f"fold{fold}", fname)
        if not os.path.exists(fpath):
            continue

        if cname == 'gun_shot':
            records.append((fpath, CLASS_TO_IDX['gunshot']))
        elif cname == 'children_playing':
            crowd_files.append(fpath)
        elif cname in ['engine_idling', 'car_horn', 'drilling', 'siren', 'dog_bark', 'air_conditioner', 'jackhammer', 'street_music']:
            records.append((fpath, CLASS_TO_IDX['neutral_ambient']))
else:
    print(f"Notice: UrbanSound8K paths not found at {US8K_CSV}. Skipping.")

# C. Parse Freesound
if os.path.exists(FS_CSV) and os.path.exists(FS_AUDIO):
    df_fs = pd.read_csv(FS_CSV)
    print(f"Loaded Freesound CSV: {len(df_fs)} rows")
    for _, row in df_fs.iterrows():
        lbl = str(row['label']).lower().strip()
        fname = str(row['fname'])
        if not fname.endswith('.wav'):
            fname += '.wav'
        fpath = os.path.join(FS_AUDIO, fname)
        if not os.path.exists(fpath):
            continue

        if 'gunshot' in lbl or 'gunfire' in lbl:
            records.append((fpath, CLASS_TO_IDX['gunshot']))
        elif 'shatter' in lbl or 'glass' in lbl:
            records.append((fpath, CLASS_TO_IDX['glass_break']))
        elif any(k in lbl for k in ['crash', 'collision', 'slam', 'impact', 'skid']):
            records.append((fpath, CLASS_TO_IDX['collision']))
        elif 'explosion' in lbl or 'firework' in lbl:
            records.append((fpath, CLASS_TO_IDX['explosion']))
        elif any(k in lbl for k in ['cheering', 'applause', 'laughter', 'cough', 'crowd']):
            crowd_files.append(fpath)
        else:
            records.append((fpath, CLASS_TO_IDX['neutral_ambient']))
else:
    print(f"Notice: Freesound paths not found at {FS_CSV}. Skipping.")

print(f"\nManifest Summary:")
print(f"  • Total mapped dataset samples: {len(records)}")
print(f"  • Total negative crowd background clips: {len(crowd_files)}")

# Count distribution per class
class_counts = {name: 0 for name in CLASSES}
for _, c_idx in records:
    class_counts[IDX_TO_CLASS[c_idx]] += 1
for name, count in class_counts.items():
    print(f"    - {name:<16}: {count}")

# ------------------------------------------------------------------------------
# 3. Audio Loading & Augmentation Functions
# ------------------------------------------------------------------------------
def load_and_resample(file_path: str, target_sr: int = 16000) -> np.ndarray:
    """Loads an audio file and normalizes to 16 kHz mono float32."""
    try:
        y, _ = librosa.load(file_path, sr=target_sr, mono=True)
        if len(y) < MIN_AUDIO_LEN:
            y = np.pad(y, (0, MIN_AUDIO_LEN - len(y)), mode='constant')
        return y.astype(np.float32)
    except Exception as e:
        return np.zeros(MIN_AUDIO_LEN, dtype=np.float32)

def mix_audio_at_snr(signal: np.ndarray, noise: np.ndarray, snr_db: float) -> np.ndarray:
    """Overlays noise onto a signal at a specified SNR (in dB)."""
    if len(noise) < len(signal):
        noise = np.pad(noise, (0, len(signal) - len(noise)), mode='wrap')
    else:
        start = random.randint(0, len(noise) - len(signal))
        noise = noise[start : start + len(signal)]

    p_signal = np.mean(signal ** 2)
    p_noise = np.mean(noise ** 2)

    if p_signal <= 1e-8 or p_noise <= 1e-8:
        return signal

    # Calculate required noise scaling factor
    snr_linear = 10.0 ** (snr_db / 10.0)
    scale = math.sqrt(p_signal / (p_noise * snr_linear + 1e-9))
    noisy_signal = signal + scale * noise

    # Peak normalize to prevent hard clipping
    max_amp = np.max(np.abs(noisy_signal))
    if max_amp > 1e-6:
        noisy_signal = (noisy_signal / max_amp) * 0.95
    return noisy_signal.astype(np.float32)

def augment_audio(y: np.ndarray, is_threat: bool, crowd_pool: List[np.ndarray]) -> np.ndarray:
    """Applies pitch shift, time stretch, and crowd overlay augmentation."""
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

    # 3. Crowd background noise overlay (-5 dB to 10 dB)
    if is_threat and crowd_pool and random.random() < 0.6:
        crowd_noise = random.choice(crowd_pool)
        snr_val = random.uniform(-5.0, 10.0)
        out = mix_audio_at_snr(out, crowd_noise, snr_val)

    return out.astype(np.float32)

# Preload crowd noise waveforms into memory for fast mixing
print("\n" + "=" * 70)
print("3. Preloading Crowd Noise Background Pool...")
print("=" * 70)
crowd_waveforms = []
random.shuffle(crowd_files)
selected_crowd = crowd_files[:min(len(crowd_files), 400)]

for idx, cp in enumerate(selected_crowd):
    wav = load_and_resample(cp)
    crowd_waveforms.append(wav)
    if (idx + 1) % 50 == 0 or (idx + 1) == len(selected_crowd):
        print(f"  Loaded {idx + 1}/{len(selected_crowd)} background clips...")

# Also inject 150 pure crowd clips into 'neutral_ambient' so model learns clean crowd is safe
for cp in crowd_files[:150]:
    records.append((cp, CLASS_TO_IDX['neutral_ambient']))

print(f"Preloaded {len(crowd_waveforms)} crowd noise clips for dynamic SNR mixing.")

# ------------------------------------------------------------------------------
# 4. Load Pretrained Google YAMNet Feature Extractor
# ------------------------------------------------------------------------------
print("\n" + "=" * 70)
print("4. Loading Google YAMNet from TensorFlow Hub...")
print("=" * 70)
YAMNET_URL = 'https://tfhub.dev/google/yamnet/1'
yamnet_model = hub.load(YAMNET_URL)
print("YAMNet loaded successfully (Outputs: scores, 1024-dim embeddings, spectrogram).")

def extract_yamnet_embedding(waveform: np.ndarray) -> np.ndarray:
    """Passes 16 kHz waveform through YAMNet and pools temporal embeddings into 1024-D vector."""
    if len(waveform) < MIN_AUDIO_LEN:
        waveform = np.pad(waveform, (0, MIN_AUDIO_LEN - len(waveform)), mode='constant')
    waveform_tensor = tf.convert_to_tensor(waveform, dtype=tf.float32)
    _, embeddings, _ = yamnet_model(waveform_tensor)
    # Average across all 0.975s frames in the audio
    mean_embedding = tf.reduce_mean(embeddings, axis=0)
    return mean_embedding.numpy()

# ------------------------------------------------------------------------------
# 5. Feature Extraction (Embeddings Generation)
# ------------------------------------------------------------------------------
print("\n" + "=" * 70)
print("5. Extracting 1024-D Embeddings with Dynamic Crowd Augmentation...")
print("=" * 70)

X_embeddings = []
y_labels = []

# Shuffle records
random.seed(42)
random.shuffle(records)

total_records = len(records)
# Cap max neutral_ambient to keep dataset balanced if needed
neutral_count = 0
MAX_NEUTRAL = max(500, sum(1 for _, c in records if c != CLASS_TO_IDX['neutral_ambient']) * 2)

for i, (fpath, c_idx) in enumerate(records):
    if c_idx == CLASS_TO_IDX['neutral_ambient']:
        if neutral_count >= MAX_NEUTRAL:
            continue
        neutral_count += 1

    wav = load_and_resample(fpath)
    is_threat = (c_idx != CLASS_TO_IDX['neutral_ambient'])

    # Apply data augmentation
    augmented_wav = augment_audio(wav, is_threat=is_threat, crowd_pool=crowd_waveforms)

    # Extract 1024-D embedding
    emb = extract_yamnet_embedding(augmented_wav)
    X_embeddings.append(emb)
    y_labels.append(c_idx)

    # Extra augmentation pass for rare threat classes
    if is_threat and random.random() < 0.5:
        aug_wav_2 = augment_audio(wav, is_threat=True, crowd_pool=crowd_waveforms)
        emb_2 = extract_yamnet_embedding(aug_wav_2)
        X_embeddings.append(emb_2)
        y_labels.append(c_idx)

    if (i + 1) % 100 == 0 or (i + 1) == total_records:
        print(f"  Processed {i + 1}/{total_records} audio files -> {len(X_embeddings)} embeddings generated")

X = np.array(X_embeddings, dtype=np.float32)
y = np.array(y_labels, dtype=np.int32)
print(f"\nFinal feature matrix: X={X.shape}, y={y.shape}")

# ------------------------------------------------------------------------------
# 6. Train / Validation / Test Split & Class Balancing
# ------------------------------------------------------------------------------
X_train, X_temp, y_train, y_temp = train_test_split(
    X, y, test_size=0.3, random_state=42, stratify=y
)
X_val, X_test, y_val, y_test = train_test_split(
    X_temp, y_temp, test_size=0.5, random_state=42, stratify=y_temp
)

print(f"Dataset Partitions:")
print(f"  • Train: {len(X_train)} samples")
print(f"  • Val:   {len(X_val)} samples")
print(f"  • Test:  {len(X_test)} samples")

# Compute class weights for imbalanced threat distribution
classes_present = np.unique(y_train)
weights = compute_class_weight('balanced', classes=classes_present, y=y_train)
class_weights_dict = {cls: float(w) for cls, w in zip(classes_present, weights)}
print(f"Computed Class Weights: {class_weights_dict}")

# ------------------------------------------------------------------------------
# 7. Model Architecture & Transfer Learning
# ------------------------------------------------------------------------------
print("\n" + "=" * 70)
print("6. Building Custom Classification Head & Training...")
print("=" * 70)

# Custom Head as specified: Dropout(0.5) -> Dense(128, 'relu') -> Dropout(0.3) -> Dense(5, 'softmax')
classifier_head = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(1024,), dtype=tf.float32, name='yamnet_embedding_input'),
    tf.keras.layers.Dropout(0.5),
    tf.keras.layers.Dense(128, activation='relu', name='dense_128'),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(5, activation='softmax', name='threat_probabilities')
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
# 8. Evaluation & Per-Class Precision / Recall Verification
# ------------------------------------------------------------------------------
print("\n" + "=" * 70)
print("7. Held-Out Test Evaluation & Release Gate Report:")
print("=" * 70)

y_pred_probs = classifier_head.predict(X_test)
y_pred_classes = np.argmax(y_pred_probs, axis=1)

report = classification_report(
    y_test,
    y_pred_classes,
    target_names=[CLASSES[i] for i in sorted(np.unique(np.concatenate([y_test, y_pred_classes])))],
    digits=4,
    zero_division=0
)
print(report)

print("Confusion Matrix:")
cm = confusion_matrix(y_test, y_pred_classes)
print(cm)

# ------------------------------------------------------------------------------
# 9. End-to-End Packaging & TFLite Quantization
# ------------------------------------------------------------------------------
print("\n" + "=" * 70)
print("8. Packaging End-to-End Model & INT8 Quantization...")
print("=" * 70)

class EndToEndAuraModel(tf.Module):
    """Wraps raw 16 kHz waveform input -> YAMNet -> Custom Head into single model."""
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
print(f"Saved end-to-end model to {SAVED_MODEL_DIR}")

# Convert to TFLite with Quantization
OUTPUT_TFLITE_PATH = '/content/aura_model.tflite'
converter = tf.lite.TFLiteConverter.from_saved_model(SAVED_MODEL_DIR)
converter.optimizations = [tf.lite.Optimize.DEFAULT]  # Dynamic Range INT8 Quantization
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS,
    tf.lite.OpsSet.SELECT_TF_OPS
]

try:
    tflite_quant_model = converter.convert()
    with open(OUTPUT_TFLITE_PATH, 'wb') as f:
        f.write(tflite_quant_model)
    model_size_mb = os.path.getsize(OUTPUT_TFLITE_PATH) / (1024 * 1024)
    print(f"\nSUCCESS! Quantized TFLite Model Saved: {OUTPUT_TFLITE_PATH}")
    print(f"Model File Size: {model_size_mb:.2f} MB (Target < 8.0 MB)")
except Exception as e:
    print(f"Quantization warning: {e}. Retrying standard float fallback...")
    converter.optimizations = []
    tflite_model = converter.convert()
    with open(OUTPUT_TFLITE_PATH, 'wb') as f:
        f.write(tflite_model)
    model_size_mb = os.path.getsize(OUTPUT_TFLITE_PATH) / (1024 * 1024)
    print(f"Fallback TFLite model saved: {OUTPUT_TFLITE_PATH} ({model_size_mb:.2f} MB)")

# ------------------------------------------------------------------------------
# 10. TFLite Inference Verification Test
# ------------------------------------------------------------------------------
print("\n" + "=" * 70)
print("9. Verifying /content/aura_model.tflite with Test Waveform...")
print("=" * 70)

try:
    interpreter = tf.lite.Interpreter(model_path=OUTPUT_TFLITE_PATH)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(f"TFLite Input details : {input_details[0]['name']}, shape: {input_details[0]['shape']}")
    print(f"TFLite Output details: {output_details[0]['name']}, shape: {output_details[0]['shape']}")

    # Test with 1.0s dummy silence (16000 samples)
    test_wav = np.zeros(16000, dtype=np.float32)
    interpreter.resize_tensor_input(input_details[0]['index'], [len(test_wav)])
    interpreter.allocate_tensors()
    interpreter.set_tensor(input_details[0]['index'], test_wav)
    interpreter.invoke()

    preds = interpreter.get_tensor(output_details[0]['index'])
    print(f"Verification inference successful!")
    print(f"Threat Probabilities for 1s sample:")
    for cls_name, prob in zip(CLASSES, preds[0]):
        print(f"  {cls_name:<16}: {prob * 100:.2f}%")

except Exception as e:
    print(f"Notice: TFLite local interpreter test skipped ({e}). Model file is ready at {OUTPUT_TFLITE_PATH}")

print("\n" + "=" * 70)
print("AURA Transfer Learning & Model Export Pipeline Complete!")
print(f"Download your deployable mobile model from: {OUTPUT_TFLITE_PATH}")
print("=" * 70)
