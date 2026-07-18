#!/usr/bin/env python3
"""One-time assembly: merges the harvested content (content_build/, gen/,
undefined/gen/) into content/*.json, preferring the notebook version of a word
over the supplement version when both exist. Then run Scripts/gen_data.py.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD_DIRS = [ROOT / "content_build", ROOT / "gen", ROOT / "undefined" / "gen"]
CONTENT = ROOT / "content"
CONTENT.mkdir(exist_ok=True)


def find(pattern):
    hits = []
    for d in BUILD_DIRS:
        if d.exists():
            hits.extend(sorted(d.glob(pattern)))
    return hits


def text(w, key):
    return (w.get(key) or "").strip()


def norm_word(w, source):
    return {
        "word": text(w, "word").lower(),
        "pos": text(w, "pos"),
        "definition": text(w, "definition"),
        "synonyms": [s.strip() for s in (w.get("synonyms") or []) if isinstance(s, str) and s.strip()],
        "mnemonic": text(w, "mnemonic"),
        "root": text(w, "root"),
        "example": text(w, "example"),
        "yourNote": text(w, "yourNote") if source == "notebook" else "",
        "source": source,
        "difficulty": w.get("difficulty", 2) if w.get("difficulty") in (1, 2, 3) else 2,
    }


notebook = {}
dropped = []
for f in find("enriched_*.json"):
    for w in json.loads(f.read_text()).get("words", []):
        if w.get("drop"):
            dropped.append(w.get("word", "?"))
            continue
        e = norm_word(w, "notebook")
        if e["word"] and e["definition"]:
            notebook[e["word"]] = e

supplement = {}
for f in find("supplement_*.json"):
    for w in json.loads(f.read_text()).get("words", []):
        e = norm_word(w, "supplement")
        if e["word"] and e["definition"]:
            supplement[e["word"]] = e

overlap = sorted(set(notebook) & set(supplement))
merged = dict(supplement)
merged.update(notebook)  # notebook wins: it carries the student's own notes

words = sorted(merged.values(), key=lambda w: w["word"])
(CONTENT / "words.json").write_text(json.dumps({"words": words}, indent=1, ensure_ascii=False))

strands = []
for key in ("numbers", "algebra", "geometry", "data"):
    hits = find(f"math_{key}.json")
    if not hits:
        print(f"MISSING math_{key}.json")
        continue
    doc = json.loads(hits[0].read_text())
    if "strand" not in doc or "topics" not in doc:
        print(f"BAD math_{key}.json: missing strand/topics keys")
        continue
    strands.append({"strand": doc["strand"], "topics": doc["topics"]})
(CONTENT / "math.json").write_text(json.dumps({"strands": strands}, indent=1, ensure_ascii=False))

for name in ("reading_guide", "passages", "analogies", "overview"):
    hits = find(f"{name}.json")
    if not hits:
        print(f"MISSING {name}.json")
        continue
    (CONTENT / f"{name}.json").write_text(hits[0].read_text())

print(f"notebook: {len(notebook)} (dropped {len(dropped)}: {dropped})")
print(f"supplement: {len(supplement)}, overlap resolved to notebook: {len(overlap)}")
print(f"total words: {len(words)}")
print(f"math strands: {len(strands)}")
