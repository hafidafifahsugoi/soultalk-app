import os
import io
import base64
import numpy as np
import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

# Determine model asset path
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(CURRENT_DIR, "models", "face_landmarker.task")

_detector = None

def get_detector():
    global _detector
    if _detector is None:
        if not os.path.exists(MODEL_PATH):
            raise FileNotFoundError(f"Model face landmarker tidak ditemukan di: {MODEL_PATH}")
        
        base_options = python.BaseOptions(model_asset_path=MODEL_PATH)
        options = vision.FaceLandmarkerOptions(
            base_options=base_options,
            output_face_blendshapes=True,
            output_facial_transformation_matrixes=False,
            num_faces=1
        )
        _detector = vision.FaceLandmarker.create_from_options(options)
    return _detector

def detect_emotion_from_bytes(image_bytes: bytes) -> dict:
    """
    Mendeteksi emosi wajah dari raw bytes gambar (JPEG, PNG, dll.)
    Mengembalikan dict dengan field:
      face_detected: bool
      emotion: str ('Senang', 'Sedih', 'Biasa', 'Cemas', 'Lelah', 'Tidak Terdeteksi')
      emoji: str
      confidence: float (0.0 - 1.0)
      metrics: dict (skor blendshapes terkait)
    """
    try:
        # Decode image using OpenCV
        np_arr = np.frombuffer(image_bytes, np.uint8)
        bgr_image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if bgr_image is None:
            return {
                "face_detected": False,
                "emotion": "Tidak Terdeteksi",
                "emoji": "👤",
                "confidence": 0.0,
                "message": "Gagal membaca format gambar"
            }

        # Convert to RGB for MediaPipe
        rgb_image = cv2.cvtColor(bgr_image, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_image)

        detector = get_detector()
        detection_result = detector.detect(mp_image)

        if not detection_result.face_blendshapes or len(detection_result.face_blendshapes) == 0:
            return {
                "face_detected": False,
                "emotion": "Tidak Terdeteksi",
                "emoji": "👤",
                "confidence": 0.0,
                "message": "Tidak ada wajah terdeteksi dalam frame"
            }

        blendshapes = detection_result.face_blendshapes[0]
        scores = {b.category_name: b.score for b in blendshapes}

        # Ekstrak nilai blendshape kunci
        smile_left = scores.get("mouthSmileLeft", 0.0)
        smile_right = scores.get("mouthSmileRight", 0.0)
        smile = (smile_left + smile_right) / 2.0

        frown_left = scores.get("mouthFrownLeft", 0.0)
        frown_right = scores.get("mouthFrownRight", 0.0)
        frown = (frown_left + frown_right) / 2.0

        brow_down_left = scores.get("browDownLeft", 0.0)
        brow_down_right = scores.get("browDownRight", 0.0)
        brow_down = (brow_down_left + brow_down_right) / 2.0

        brow_inner_up = scores.get("browInnerUp", 0.0)

        eye_wide_left = scores.get("eyeWideLeft", 0.0)
        eye_wide_right = scores.get("eyeWideRight", 0.0)
        eye_wide = (eye_wide_left + eye_wide_right) / 2.0

        eye_blink_left = scores.get("eyeBlinkLeft", 0.0)
        eye_blink_right = scores.get("eyeBlinkRight", 0.0)
        eye_blink = (eye_blink_left + eye_blink_right) / 2.0

        pucker = scores.get("mouthPucker", 0.0)
        shrug_lower = scores.get("mouthShrugLower", 0.0)
        roll_lower = scores.get("mouthRollLower", 0.0)

        metrics = {
            "smile": round(float(smile), 3),
            "frown": round(float(frown), 3),
            "pucker": round(float(pucker), 3),
            "shrug_lower": round(float(shrug_lower), 3),
            "brow_down": round(float(brow_down), 3),
            "brow_inner_up": round(float(brow_inner_up), 3),
            "eye_wide": round(float(eye_wide), 3),
            "eye_blink": round(float(eye_blink), 3),
        }

        # Klasifikasi Emosi (Mendeteksi Senang, Sedih/Manyun/Murung, Cemas, Lelah, Biasa)
        if smile > 0.26:
            emotion = "Senang"
            emoji = "😊"
            confidence = min(1.0, round(float(smile * 1.6), 2))
        elif (
            frown > 0.14
            or (pucker > 0.20 and smile < 0.15)
            or (shrug_lower > 0.20 and smile < 0.15)
            or (brow_inner_up > 0.20 and smile < 0.18)
            or (brow_down > 0.28 and smile < 0.12)
            or (smile < 0.06 and (frown > 0.08 or pucker > 0.16 or brow_down > 0.20))
        ):
            emotion = "Sedih"
            emoji = "😢"
            confidence = min(1.0, round(float(max(frown * 1.6, pucker * 1.4, brow_inner_up * 1.3, brow_down * 1.2, 0.75)), 2))
        elif brow_down > 0.35 and eye_wide > 0.25:
            emotion = "Cemas"
            emoji = "😰"
            confidence = min(1.0, round(float(max(brow_down, eye_wide)), 2))
        elif eye_blink > 0.70 and brow_down > 0.18:
            emotion = "Lelah"
            emoji = "😔"
            confidence = min(1.0, round(float(eye_blink), 2))
        else:
            emotion = "Biasa"
            emoji = "🙂"
            confidence = 0.85

        return {
            "face_detected": True,
            "emotion": emotion,
            "emoji": emoji,
            "confidence": confidence,
            "metrics": metrics
        }

    except Exception as e:
        return {
            "face_detected": False,
            "emotion": "Error",
            "emoji": "⚠️",
            "confidence": 0.0,
            "message": str(e)
        }

def detect_emotion_from_base64(b64_string: str) -> dict:
    """Menerima string base64 (dengan atau tanpa prefix data:image/...;base64,)"""
    if "," in b64_string:
        b64_string = b64_string.split(",", 1)[1]
    image_bytes = base64.b64decode(b64_string)
    return detect_emotion_from_bytes(image_bytes)
