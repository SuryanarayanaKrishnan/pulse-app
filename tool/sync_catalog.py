#!/usr/bin/env python3
"""Regenerate assets/catalog/cards.json from the backend card data.

Usage: python3 tool/sync_catalog.py /path/to/pulse [--check]   (needs the backend
repo's python deps, e.g. its .venv). With --check nothing is written and the exit
code is 1 when the bundled catalog differs from the backend's (the weekly drift
check, .github/workflows/catalog-drift.yml). The bundled catalog is what the app shows when no
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
text = json.dumps(doc, ensure_ascii=False, separators=(",", ":"))
if "--check" in sys.argv:
    same = out.read_text(encoding="utf-8") == text
    print("bundled catalog matches the backend" if same else "DRIFT: bundled cards.json differs from the backend catalog; run tool/sync_catalog.py")
    sys.exit(0 if same else 1)
out.write_text(text, encoding="utf-8")
print(f"wrote {len(doc['cards'])} cards, version {doc['version']}")
