# LLD-007 — Computer Vision Self-Checkout
## EnterpriseRetailAI · YOLOv8 Pipeline, Item Detection, Weight Integration, Anti-theft

---

| Document ID | LLD-007 | Version | 1.0 | Status | Approved | Date | June 2026 |

---

## 1. CV Pipeline Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                  SELF-CHECKOUT CV PIPELINE                          │
│                                                                      │
│  Camera Array (USB/GigE)                                             │
│  ├── Top-down scan camera (1080p, 30fps)                             │
│  ├── Side camera (anti-theft, wide-angle)                            │
│  └── Barcode scanner (primary, fastest path)                         │
│              │                                                       │
│              ▼                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  ITEM RECOGNITION PIPELINE (IoT Edge — store edge)         │    │
│  │                                                             │    │
│  │  Frame Capture → Pre-processing → YOLOv8n Inference        │    │
│  │                                                             │    │
│  │  Pre-processing:                                            │    │
│  │  ├ Resize to 640×640 (letterbox padding)                   │    │
│  │  ├ BGR → RGB conversion                                     │    │
│  │  ├ Normalize pixel values to [0,1]                         │    │
│  │  └ Tensor shape: [1, 3, 640, 640] (NCHW)                  │    │
│  │                                                             │    │
│  │  YOLOv8n ONNX Inference:                                   │    │
│  │  └ Output: [N, 85] = (x,y,w,h,conf, 80 class probs)       │    │
│  │    (extended to # of tenant SKU classes)                    │    │
│  └─────────────────────────────────────────────────────────────┘    │
│              │                                                       │
│              ▼                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  DECISION ENGINE                                           │    │
│  │                                                             │    │
│  │  Confidence ≥ 0.92 → Auto-add to basket                   │    │
│  │  0.70–0.92         → Request re-present                   │    │
│  │  < 0.70            → Call attendant                        │    │
│  │                                                             │    │
│  │  Weight verification:                                       │    │
│  │  |expected_g – actual_g| / expected_g > 0.05 → Attendant  │    │
│  │                                                             │    │
│  │  Anti-theft:                                                │    │
│  │  Unscanned item in bagging area → FREEZE + Alert           │    │
│  └─────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. YOLOv8 Model Training Pipeline

```python
from ultralytics import YOLO
import torch

def train_item_recognition_model(
    tenant_id: str,
    dataset_yaml: str,         # YOLO format dataset descriptor
    base_model: str = "yolov8n.pt",
    epochs: int = 100,
    imgsz: int = 640,
) -> str:
    """
    Fine-tune YOLOv8n on per-tenant SKU image dataset.
    Returns path to best.pt weights.
    
    Dataset requirements:
    - Minimum 200 images per SKU class
    - Augmented: random flip, rotation ±15°, brightness ±20%
    - Split: 80% train / 10% val / 10% test
    - Format: YOLO txt labels (class cx cy w h — normalised)
    """
    # Load base model (pre-trained on COCO)
    model = YOLO(base_model)

    # Fine-tune on tenant dataset
    results = model.train(
        data        = dataset_yaml,
        epochs      = epochs,
        imgsz       = imgsz,
        batch       = 16,
        device      = "cuda" if torch.cuda.is_available() else "cpu",
        workers     = 4,
        patience    = 20,           # early stopping patience
        optimizer   = "AdamW",
        lr0         = 0.001,
        lrf         = 0.01,
        momentum    = 0.937,
        weight_decay = 0.0005,
        augment     = True,
        mosaic      = 1.0,          # mosaic augmentation
        mixup       = 0.15,
        copy_paste  = 0.1,
        hsv_h       = 0.015,        # HSV augmentation
        hsv_s       = 0.7,
        hsv_v       = 0.4,
        fliplr      = 0.5,
        project     = f"/models/{tenant_id}",
        name        = "cv-item-recog",
        exist_ok    = True,
    )

    best_model_path = results.save_dir / "weights" / "best.pt"
    return str(best_model_path)


def evaluate_model(model_path: str, test_dataset: str) -> dict:
    """
    Evaluate model on held-out test set.
    Gate: mAP50 ≥ 0.985 required for deployment.
    """
    model = YOLO(model_path)
    metrics = model.val(data=test_dataset, split="test")

    results = {
        "mAP50":       float(metrics.box.map50),
        "mAP50_95":    float(metrics.box.map),
        "precision":   float(metrics.box.mp),
        "recall":      float(metrics.box.mr),
    }

    assert results["mAP50"] >= 0.985, \
        f"mAP50 {results['mAP50']:.4f} below 0.985 gate threshold"

    return results
```

---

## 3. ONNX Export for Edge Deployment

```python
def export_to_onnx(model_path: str, output_path: str, opset: int = 17):
    """
    Export YOLOv8 to ONNX for IoT Edge deployment.
    Applies dynamic batching and simplification.
    """
    model = YOLO(model_path)

    # Export with dynamic batch size, simplify graph
    success = model.export(
        format     = "onnx",
        imgsz      = 640,
        opset      = opset,
        simplify   = True,       # onnx-simplifier
        dynamic    = False,      # fixed batch=1 for edge latency
        half       = False,      # FP32 (INT8 quant done separately)
        device     = "cpu",
    )

    # INT8 quantisation for CPU-only edge nodes
    from onnxruntime.quantization import quantize_static, CalibrationDataReader, QuantType

    quantize_static(
        model_input    = output_path.replace(".onnx", "_fp32.onnx"),
        model_output   = output_path,
        calibration_data_reader = EdgeCalibrationReader(n_samples=500),
        quant_format   = QuantFormat.QOperator,
        weight_type    = QuantType.QInt8,
        activation_type = QuantType.QInt8,
    )

    # Compute SHA-256 for integrity check at edge startup
    import hashlib
    with open(output_path, "rb") as f:
        sha256 = hashlib.sha256(f.read()).hexdigest()

    print(f"Exported ONNX INT8: {output_path}")
    print(f"SHA-256: {sha256}")
    return sha256
```

---

## 4. Inference Service (IoT Edge Module)

```python
import onnxruntime as ort
import cv2, numpy as np
from dataclasses import dataclass

@dataclass
class DetectionResult:
    class_id:    int
    class_name:  str
    sku_id:      str
    confidence:  float
    bbox:        tuple[int, int, int, int]   # x1, y1, x2, y2

class CVItemRecognitionService:
    CONF_AUTO_ADD   = 0.92
    CONF_RETRY      = 0.70
    INPUT_SIZE      = 640

    def __init__(self, model_path: str, class_map: dict[int, dict]):
        # class_map: {class_id: {"name": str, "sku_id": str, "weight_g": float}}
        self.class_map = class_map

        opts = ort.SessionOptions()
        opts.intra_op_num_threads = 4
        opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        self.session = ort.InferenceSession(
            model_path,
            sess_options = opts,
            providers    = ["CUDAExecutionProvider", "CPUExecutionProvider"],
        )

    def detect(self, frame: np.ndarray) -> list[DetectionResult]:
        """
        Run YOLOv8 inference on a single BGR frame.
        Returns list of detected items with confidence scores.
        """
        # Pre-process
        input_tensor = self._preprocess(frame)

        # Inference
        outputs = self.session.run(
            ["output0"],
            {"images": input_tensor}
        )

        # Post-process: NMS + decode boxes
        detections = self._postprocess(outputs[0], frame.shape)
        return detections

    def _preprocess(self, frame: np.ndarray) -> np.ndarray:
        # Letterbox resize to 640x640
        img = cv2.resize(frame, (self.INPUT_SIZE, self.INPUT_SIZE))
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        img = img.astype(np.float32) / 255.0
        img = np.transpose(img, (2, 0, 1))          # HWC → CHW
        img = np.expand_dims(img, axis=0)           # add batch dim
        return img

    def _postprocess(
        self,
        output: np.ndarray,
        orig_shape: tuple,
        conf_threshold: float = 0.25,
        iou_threshold:  float = 0.45,
    ) -> list[DetectionResult]:
        # YOLOv8 output: [1, 4+num_classes, num_anchors]
        predictions = np.squeeze(output).T   # [num_anchors, 4+classes]

        # Filter by confidence
        scores = np.max(predictions[:, 4:], axis=1)
        mask   = scores >= conf_threshold
        predictions = predictions[mask]
        scores      = scores[mask]

        if len(predictions) == 0:
            return []

        # Decode boxes (cx cy w h → x1 y1 x2 y2)
        boxes = predictions[:, :4].copy()
        class_ids = np.argmax(predictions[:, 4:], axis=1)

        # Scale boxes to original frame size
        scale_x = orig_shape[1] / self.INPUT_SIZE
        scale_y = orig_shape[0] / self.INPUT_SIZE
        boxes[:, [0, 2]] *= scale_x
        boxes[:, [1, 3]] *= scale_y

        # Non-maximum suppression via cv2
        indices = cv2.dnn.NMSBoxes(
            boxes.tolist(), scores.tolist(),
            conf_threshold, iou_threshold
        )

        results = []
        for i in indices.flatten():
            cls_id   = int(class_ids[i])
            cls_info = self.class_map.get(cls_id, {})
            x1, y1 = int(boxes[i][0] - boxes[i][2]/2), int(boxes[i][1] - boxes[i][3]/2)
            x2, y2 = int(boxes[i][0] + boxes[i][2]/2), int(boxes[i][1] + boxes[i][3]/2)
            results.append(DetectionResult(
                class_id   = cls_id,
                class_name = cls_info.get("name", "unknown"),
                sku_id     = cls_info.get("sku_id", ""),
                confidence = float(scores[i]),
                bbox       = (x1, y1, x2, y2),
            ))
        return results
```

---

## 5. Weight Scale Integration

```python
class WeightScaleIntegration:
    """
    Communicates with load cell via RS-232/USB serial or Modbus TCP.
    Validates detected item weight against catalogue expected weight.
    """
    TOLERANCE_PCT = 0.05   # ±5% weight tolerance

    def __init__(self, port: str, baud_rate: int = 9600):
        import serial
        self.serial = serial.Serial(port, baud_rate, timeout=1.0)

    def read_weight_grams(self) -> float | None:
        """
        Read current weight from scale.
        Returns None if scale is unstable or communication fails.
        """
        self.serial.write(b"W\r\n")
        response = self.serial.readline().decode("ascii").strip()
        # Example scale response: "ST,GS, 1234.5g"
        if response.startswith("ST,GS,"):
            weight_str = response.split(",")[-1].replace("g","").strip()
            return float(weight_str)
        return None  # unstable / error

    def validate(
        self,
        expected_weight_g: float,
        actual_weight_g: float,
    ) -> tuple[bool, float]:
        """
        Returns (is_valid, deviation_pct).
        """
        deviation = abs(expected_weight_g - actual_weight_g) / expected_weight_g
        return deviation <= self.TOLERANCE_PCT, deviation
```

---

## 6. Anti-Theft Detection

```python
class AntiTheftDetector:
    """
    Detects items placed in bagging area that were not scanned.
    Uses background subtraction + CV object tracking.
    """
    def __init__(self):
        self.bg_subtractor = cv2.createBackgroundSubtractorMOG2(
            history=500, varThreshold=50, detectShadows=True
        )
        self.scanned_items: list[str] = []  # list of scanned sku_ids this transaction
        self.bagging_area_rect = None       # set during calibration

    def update_bagging_area(self, frame: np.ndarray) -> float:
        """
        Compute foreground change in bagging area.
        Returns fraction of bagging area pixels that changed.
        """
        fg_mask = self.bg_subtractor.apply(frame)
        if self.bagging_area_rect:
            x, y, w, h = self.bagging_area_rect
            roi = fg_mask[y:y+h, x:x+w]
        else:
            roi = fg_mask
        fg_pct = np.sum(roi > 128) / roi.size
        return fg_pct

    def detect_unscanned_item(
        self,
        frame: np.ndarray,
        detected_items: list[DetectionResult],
        fg_threshold: float = 0.15,
    ) -> bool:
        """
        Returns True if significant object movement in bagging area
        without a corresponding recently scanned item.
        """
        fg_pct = self.update_bagging_area(frame)
        if fg_pct < fg_threshold:
            return False  # no significant movement

        # Movement detected — check if we have a recent scan
        if not detected_items and not self.scanned_items:
            return True   # unscanned item placed

        # Check that detected items match scanned SKUs
        detected_skus = {d.sku_id for d in detected_items if d.confidence >= 0.70}
        unscanned = detected_skus - set(self.scanned_items[-3:])
        return len(unscanned) > 0
```

---

## 7. IoT Edge Module Spec

```json
{
  "cv-item-recognition": {
    "type": "docker",
    "settings": {
      "image": "retailai.azurecr.io/cv-item-recognition:1.8.0",
      "createOptions": {
        "HostConfig": {
          "Memory": 1073741824,
          "Devices": [
            {"PathOnHost": "/dev/video0", "PathInContainer": "/dev/video0"},
            {"PathOnHost": "/dev/video1", "PathInContainer": "/dev/video1"}
          ],
          "PortBindings": {
            "8090/tcp": [{"HostPort": "8090"}]
          }
        }
      }
    },
    "env": {
      "MODEL_PATH":      {"value": "/models/cv_item_recog_int8.onnx"},
      "MODEL_SHA256":    {"value": "<<sha256_from_registry>>"},
      "CONF_AUTO_ADD":   {"value": "0.92"},
      "CONF_RETRY":      {"value": "0.70"},
      "SCALE_PORT":      {"value": "/dev/ttyUSB0"},
      "ENABLE_GPU":      {"value": "false"},
      "STORE_ID":        {"value": "<<store_id>>"},
      "LOG_LEVEL":       {"value": "INFO"}
    }
  }
}
```

---

## 8. REST API (served by cv-item-recognition module)

```
POST /api/v1/cv/detect
Content-Type: multipart/form-data
Body:  frame=<JPEG bytes>

Response 200:
{
  "detections": [
    {
      "sku_id":     "sku_001",
      "class_name": "Organic Whole Milk 2L",
      "confidence": 0.974,
      "action":     "AUTO_ADD",   // or "RETRY" or "ATTENDANT"
      "bbox":       [120, 80, 420, 380]
    }
  ],
  "inference_ms": 38,
  "model_version": "1.8.0"
}

POST /api/v1/cv/weight-check
Body: { "sku_id": "sku_001", "actual_weight_g": 2080 }

Response 200:
{
  "expected_weight_g": 2050,
  "actual_weight_g":   2080,
  "deviation_pct":     0.0146,
  "is_valid":          true
}

POST /api/v1/cv/antitheft/report
Body: { "transaction_id": "...", "frame_timestamp": "..." }
→ Triggers attendant alert + logs security event
```

---

## 9. Performance Targets

| Metric | Target | Hardware Basis |
|---|---|---|
| Inference latency (CPU) | < 120ms per frame | Intel Core i5 (12th gen) |
| Inference latency (GPU) | < 30ms per frame | NVIDIA Jetson Orin NX |
| Item recognition accuracy (mAP50) | ≥ 98.5% | Per-tenant test set |
| False accept rate (wrong item) | < 0.1% | Audit sample |
| Weight validation latency | < 50ms | Scale serial read |
| Anti-theft detection latency | < 200ms | Background subtraction |
| Model load time at startup | < 10 seconds | SSD on edge node |

---

## 10. Related Documents

- HLD-005: AI/ML Platform
- LLD-003: Store Edge Orchestration
- LLD-015: MLOps Pipeline Design
