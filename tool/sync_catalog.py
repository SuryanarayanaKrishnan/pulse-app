#!/usr/bin/env python3
"""Regenerate assets/catalog/cards.json from the backend card data.

Usage: python3 tool/sync_catalog.py /path/to/pulse   (needs the backend repo's
python deps, e.g. its .venv). The bundled catalog is what the app shows when no
backend is reachable, so it must be the full catalog, not a sample.
"""
import json
import pathlib
import sys

backend = pathlib.Path(sys.argv[1]).resolve()
sys.path.insert(0, str(backend))
from app.services.card_catalog import load_catalog, public_catalog  # noqa: E402

doc = public_catalog(load_catalog())
out = pathlib.Path(__file__).resolve().parent.parent / "assets/catalog/cards.json"
out.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print(f"wrote {len(doc['cards'])} cards, version {doc['version']}")
