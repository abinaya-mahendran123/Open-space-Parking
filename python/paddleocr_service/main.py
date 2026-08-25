"""
PaddleOCR HTTP service for Open Space Parking government-ID OCR.

Run locally:
  cd python/paddleocr_service
  pip install -r requirements.txt
  python main.py

Environment:
  PADDLEOCR_SERVICE_PORT  (default 8765)
  PADDLEOCR_LANGS         (default en,ta,hi — comma-separated)
  PADDLEOCR_USE_GPU       (default false)
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
import time
from typing import Any

import cv2
import numpy as np
from flask import Flask, jsonify, request

# Lazy-import PaddleOCR so --health works before models are installed.
_engines: dict[str, Any] = {}
_app = Flask(__name__)

DEFAULT_LANGS = ["en", "ta", "hi"]


def configured_langs() -> list[str]:
    raw = os.environ.get("PADDLEOCR_LANGS", ",".join(DEFAULT_LANGS))
    langs = [part.strip() for part in raw.split(",") if part.strip()]
    return langs or DEFAULT_LANGS


def get_engine(lang: str):
    if lang in _engines:
        return _engines[lang]
    from paddleocr import PaddleOCR

    use_gpu = os.environ.get("PADDLEOCR_USE_GPU", "false").lower() == "true"
    engine = PaddleOCR(
        use_angle_cls=True,
        lang=lang,
        use_gpu=use_gpu,
        show_log=False,
    )
    _engines[lang] = engine
    return engine


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
    langs = langs or configured_langs()
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

    # De-duplicate near-identical lines; keep highest confidence.
    deduped: dict[str, dict] = {}
    for item in items:
        if item.get("error"):
            continue
        key = item["text"].lower().strip()
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
    return jsonify(
        {
            "ok": True,
            "engine": "paddleocr",
            "langsConfigured": configured_langs(),
            "enginesLoaded": sorted(_engines.keys()),
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
            }
        )

    tmp_path = None
    try:
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
    _app.run(host=host, port=port, threaded=True)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "serve":
        serve()
    elif len(sys.argv) > 1:
        raise SystemExit(cli_main(sys.argv[1:]))
    else:
        serve()
