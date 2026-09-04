"""
PaddleOCR HTTP service for Open Space Parking government-ID OCR.

Run locally:
  cd python/paddleocr_service
  pip install -r requirements.txt
  python main.py

Environment:
  PADDLEOCR_SERVICE_PORT  (default 8765)
  PADDLEOCR_LANGS         (default en — add ta,hi only when RAM allows)
  PADDLEOCR_USE_GPU       (default false)
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
import threading
import time
from typing import Any

import cv2
import numpy as np
from flask import Flask, jsonify, request

# Lazy-import PaddleOCR so --health works before models are installed.
_engines: dict[str, Any] = {}
_engine_lock = threading.Lock()
_models_ready = False
_models_error: str | None = None
_app = Flask(__name__)
_MAX_INFLIGHT = max(1, int(os.environ.get("PADDLEOCR_MAX_INFLIGHT", "2")))
_OCR_ACQUIRE_TIMEOUT_SEC = float(os.environ.get("PADDLEOCR_ACQUIRE_TIMEOUT_SEC", "180"))
_ocr_semaphore = threading.Semaphore(_MAX_INFLIGHT)
_active_ocr = 0
_active_lock = threading.Lock()

# Prefer English first on small hosts; add ta,hi via PADDLEOCR_LANGS when RAM allows.
DEFAULT_LANGS = ["en"]


def configured_langs() -> list[str]:
    raw = os.environ.get("PADDLEOCR_LANGS", ",".join(DEFAULT_LANGS))
    langs = [part.strip() for part in raw.split(",") if part.strip()]
    return langs or DEFAULT_LANGS


def resolve_langs(requested: list[str] | None) -> list[str]:
    """Only run OCR with languages that were warmed at startup."""
    configured = configured_langs()
    if not requested:
        return configured
    filtered = [lang for lang in requested if lang in configured]
    if filtered:
        skipped = [lang for lang in requested if lang not in configured]
        if skipped:
            print(
                f"[PaddleOCR] ignoring langs not in PADDLEOCR_LANGS: {skipped}",
                flush=True,
            )
        return filtered
    return configured


def get_engine(lang: str):
    with _engine_lock:
        if lang in _engines:
            return _engines[lang]
        from paddleocr import PaddleOCR

        print(f"[PaddleOCR] loading model lang={lang} (may download on first run)...")
        use_gpu = os.environ.get("PADDLEOCR_USE_GPU", "false").lower() == "true"
        use_angle_cls = os.environ.get("PADDLEOCR_USE_ANGLE_CLS", "true").lower() == "true"
        engine = PaddleOCR(
            use_angle_cls=use_angle_cls,
            lang=lang,
            use_gpu=use_gpu,
            show_log=False,
        )
        _engines[lang] = engine
        print(f"[PaddleOCR] model ready lang={lang}")
        return engine


def warmup_models() -> None:
    global _models_ready, _models_error
    try:
        for lang in configured_langs():
            get_engine(lang)
        _models_ready = True
        _models_error = None
        print(f"[PaddleOCR] warmup complete langs={list(_engines.keys())}")
    except Exception as exc:  # noqa: BLE001
        _models_ready = False
        _models_error = str(exc)
        print(f"[PaddleOCR] warmup failed: {exc}")


def bbox_top_left(bbox: list) -> tuple[float, float]:
    xs = [p[0] for p in bbox]
    ys = [p[1] for p in bbox]
    return min(ys), min(xs)


def normalize_confidence(value: Any) -> float:
    try:
        conf = float(value)
    except (TypeError, ValueError):
        return 0.0
    if conf > 1.0:
        conf = conf / 100.0
    return max(0.0, min(conf, 1.0))


def read_image(path: str) -> np.ndarray:
    data = np.fromfile(path, dtype=np.uint8)
    image = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Could not decode image.")
    return image


def run_ocr_on_image(image_path: str, langs: list[str] | None = None) -> dict:
    started = time.time()
    langs = resolve_langs(langs)
    image = read_image(image_path)
    items: list[dict] = []
    langs_used: list[str] = []

    for lang in langs:
        try:
            engine = get_engine(lang)
            result = engine.ocr(image, cls=True)
            langs_used.append(lang)
        except Exception as exc:  # noqa: BLE001 — report per-lang failure
            items.append(
                {
                    "text": "",
                    "confidence": 0.0,
                    "bbox": [],
                    "lang": lang,
                    "error": str(exc),
                }
            )
            continue

        if not result:
            continue
        for block in result:
            if not block:
                continue
            for line in block:
                if not line or len(line) < 2:
                    continue
                bbox, payload = line[0], line[1]
                if not payload or len(payload) < 1:
                    continue
                text = str(payload[0] or "").strip()
                if not text:
                    continue
                conf = normalize_confidence(payload[1] if len(payload) > 1 else 0)
                items.append(
                    {
                        "text": text,
                        "confidence": conf,
                        "bbox": bbox,
                        "lang": lang,
                    }
                )

    # Keep both language variants when text differs (e.g. Tamil + English name).
    deduped: dict[str, dict] = {}
    for item in items:
        if item.get("error"):
            continue
        key = item["text"].strip()
        if not key:
            continue
        prev = deduped.get(key)
        if prev is None or item["confidence"] > prev["confidence"]:
            deduped[key] = item

    merged = list(deduped.values())
    merged.sort(key=lambda row: bbox_top_left(row.get("bbox") or [[0, 0]]))

    elapsed_ms = int((time.time() - started) * 1000)
    return {
        "engine": "paddleocr",
        "text": merged,
        "processingTimeMs": elapsed_ms,
        "langsUsed": langs_used,
    }


@_app.get("/")
def index():
    return jsonify(
        {
            "service": "Open Space Parking PaddleOCR",
            "ok": True,
            "endpoints": {
                "health": "GET /health",
                "ocr": "POST /ocr",
            },
            "note": "Open /health in the browser. OCR runs via POST /ocr from the Node backend.",
        }
    )


@_app.get("/health")
def health():
    with _active_lock:
        active = _active_ocr
    return jsonify(
        {
            "ok": True,
            "engine": "paddleocr",
            "modelsReady": _models_ready,
            "modelsError": _models_error,
            "langsConfigured": configured_langs(),
            "enginesLoaded": sorted(_engines.keys()),
            "maxInflight": _MAX_INFLIGHT,
            "activeOcr": active,
        }
    )


@_app.route("/ocr", methods=["GET", "POST"])
def ocr_http():
    if request.method == "GET":
        return jsonify(
            {
                "ok": True,
                "endpoint": "POST /ocr",
                "usage": "Called by the Node backend with JSON { imagePath, langs }. Not for browser GET.",
                "health": "GET /health",
                "modelsReady": _models_ready,
            }
        )

    if not _models_ready:
        return jsonify(
            {
                "error": "PaddleOCR models are still downloading/loading. Retry in a minute.",
                "engine": "paddleocr",
                "modelsReady": False,
            }
        ), 503

    acquired = _ocr_semaphore.acquire(timeout=_OCR_ACQUIRE_TIMEOUT_SEC)
    if not acquired:
        return jsonify(
            {
                "error": "OCR worker is at capacity. Retry shortly.",
                "engine": "paddleocr",
                "retryAfterSeconds": 15,
            }
        ), 503

    tmp_path = None
    try:
        with _active_lock:
            global _active_ocr
            _active_ocr += 1
        if request.is_json:
            body = request.get_json(silent=True) or {}
            image_path = body.get("imagePath")
            langs = body.get("langs")
            if not image_path or not os.path.isfile(image_path):
                return jsonify({"error": "imagePath must point to an existing file."}), 400
            result = run_ocr_on_image(image_path, langs=langs)
            return jsonify(result)

        upload = request.files.get("file")
        if upload is None:
            return jsonify({"error": "Provide JSON imagePath or multipart file."}), 400

        suffix = os.path.splitext(upload.filename or "image.jpg")[1] or ".jpg"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            upload.save(tmp.name)
            tmp_path = tmp.name
        langs_raw = request.form.get("langs")
        langs = [p.strip() for p in langs_raw.split(",")] if langs_raw else None
        result = run_ocr_on_image(tmp_path, langs=langs)
        return jsonify(result)
    except Exception as exc:  # noqa: BLE001
        return jsonify({"error": str(exc), "engine": "paddleocr"}), 500
    finally:
        with _active_lock:
            _active_ocr = max(0, _active_ocr - 1)
        _ocr_semaphore.release()
        if tmp_path and os.path.isfile(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass


def cli_main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="PaddleOCR CLI for Node subprocess fallback")
    parser.add_argument("--image", required=True, help="Path to image file")
    parser.add_argument("--langs", default=",".join(DEFAULT_LANGS), help="Comma-separated langs")
    parser.add_argument("--health", action="store_true", help="Print health JSON and exit")
    args = parser.parse_args(argv)

    if args.health:
        print(json.dumps({"ok": True, "engine": "paddleocr"}))
        return 0

    langs = [part.strip() for part in args.langs.split(",") if part.strip()]
    result = run_ocr_on_image(args.image, langs=langs)
    print(json.dumps(result))
    return 0


def serve():
    port = int(os.environ.get("PADDLEOCR_SERVICE_PORT", "8765"))
    host = os.environ.get("PADDLEOCR_SERVICE_HOST", "127.0.0.1")
    print(f"[PaddleOCR] listening on http://{host}:{port}")
    print(f"[PaddleOCR] langs={configured_langs()}")

    # Warm models in the background so /health stays reachable during downloads.
    threading.Thread(target=warmup_models, name="paddle-warmup", daemon=True).start()

    _app.run(host=host, port=port, threaded=True)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "serve":
        serve()
    elif len(sys.argv) > 1:
        raise SystemExit(cli_main(sys.argv[1:]))
    else:
        serve()
