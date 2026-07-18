#!/usr/bin/env python3
"""Validates the content JSON in content/ and regenerates
Sources/SSATCore/Data/EmbeddedData.swift (single-line raw-string literals, so
the app needs no resource bundle in either build system).

Run after editing any content file:  python3 Scripts/gen_data.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
OUT = ROOT / "Sources" / "SSATCore" / "Data" / "EmbeddedData.swift"

errors = []
warnings = []


def load(name):
    path = CONTENT / name
    if not path.exists():
        errors.append(f"missing {path}")
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as e:
        errors.append(f"{name}: invalid JSON — {e}")
        return None


def check_words(doc):
    seen = set()
    for w in doc.get("words", []):
        word = (w.get("word") or "").strip().lower()
        if not word:
            errors.append("words: entry with empty headword")
            continue
        if word in seen:
            errors.append(f"words: duplicate '{word}'")
        seen.add(word)
        if not w.get("definition", "").strip():
            errors.append(f"words: '{word}' has no definition")
        if len(w.get("synonyms", [])) < 2:
            warnings.append(f"words: '{word}' has fewer than 2 synonyms (quiz can't target it)")
        if w.get("source") not in ("notebook", "supplement"):
            errors.append(f"words: '{word}' bad source {w.get('source')!r}")
        if w.get("difficulty") not in (1, 2, 3):
            warnings.append(f"words: '{word}' difficulty {w.get('difficulty')!r} not in 1-3")
    doc["words"] = sorted(doc.get("words", []), key=lambda w: (w.get("word") or "").lower())
    return len(seen)


def check_unique(name, values):
    seen = set()
    for v in values:
        if v in seen:
            errors.append(f"{name}: duplicate id {v!r} (SwiftUI Identifiable ids must be unique)")
        seen.add(v)


def check_mcq(name, items, prompt_key, required=()):
    for i, q in enumerate(items):
        if not (q.get(prompt_key) or "").strip():
            errors.append(f"{name}[{i}]: missing {prompt_key}")
        for key in required:
            if not (q.get(key) or "").strip():
                errors.append(f"{name}[{i}]: missing {key}")
        choices = q.get("choices", [])
        if len(choices) != 5:
            errors.append(f"{name}[{i}] ({(q.get(prompt_key) or '')[:40]!r}): {len(choices)} choices, want 5")
        ai = q.get("answerIndex")
        if not isinstance(ai, int) or not (0 <= ai < max(len(choices), 1)):
            errors.append(f"{name}[{i}]: answerIndex {ai!r} out of range")


def check_sections(name, doc):
    titles = []
    for i, s in enumerate(doc.get("sections", [])):
        if not (s.get("title") or "").strip():
            errors.append(f"{name}: section [{i}] has no title")
        titles.append(s.get("title"))
    check_unique(f"{name} section titles", titles)


def check_math(doc):
    n_topics = 0
    n_practice = 0
    check_unique("math strand names", [s.get("strand") for s in doc.get("strands", [])])
    all_topic_titles = []
    for strand in doc.get("strands", []):
        sname = (strand.get("strand") or "").strip()
        if not sname:
            errors.append("math: strand with no name")
            sname = "?"
        for topic in strand.get("topics", []):
            n_topics += 1
            title = (topic.get("title") or "").strip()
            if not title:
                errors.append(f"math {sname}: topic with no title")
            all_topic_titles.append(title)
            for j, ex in enumerate(topic.get("examples", [])):
                if not (ex.get("problem") or "").strip() or not (ex.get("solution") or "").strip():
                    errors.append(f"math {sname}/{title} example[{j}]: missing problem or solution")
            for j, p in enumerate(topic.get("practice", [])):
                n_practice += 1
                if not (p.get("problem") or "").strip():
                    errors.append(f"math {sname}/{title}[{j}]: missing problem")
                choices = p.get("choices", [])
                ans = (p.get("answer") or "").strip()
                if choices:
                    if len(choices) != 5:
                        warnings.append(f"math {sname}/{title}[{j}]: {len(choices)} choices")
                    letter = ans[:1].upper()
                    if letter not in ("A", "B", "C", "D", "E") or ord(letter) - 65 >= len(choices):
                        errors.append(f"math {sname}/{title}[{j}]: answer {ans!r} doesn't map to a choice")
                if not (p.get("solution") or "").strip():
                    warnings.append(f"math {sname}/{title}[{j}]: no solution text")
    check_unique("math topic titles", all_topic_titles)
    return n_topics, n_practice


def swift_literal(doc):
    js = json.dumps(doc, ensure_ascii=True, separators=(",", ":"), sort_keys=False)
    hashes = 1
    while f'"{"#" * hashes}' in js or f'\\{"#" * hashes}' in js:
        hashes += 1
    h = "#" * hashes
    return f'{h}"{js}"{h}'


def main():
    words = load("words.json")
    reading = load("reading_guide.json")
    overview = load("overview.json")
    math = load("math.json")
    passages = load("passages.json")
    analogies = load("analogies.json")
    practice = load("sections.json")
    books = load("books.json")
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    n_words = check_words(words)
    check_unique("passage titles", [p.get("title") for p in passages.get("passages", [])])
    for p in passages.get("passages", []):
        for key in ("title", "genre", "text"):
            if not (p.get(key) or "").strip():
                errors.append(f"passage {p.get('title', '?')!r}: missing {key}")
        check_mcq(f"passage '{p.get('title', '?')}'", p.get("questions", []), "prompt")
    check_mcq("analogies", analogies.get("practice", []), "stem", required=("bridge", "explanation"))
    check_unique("analogy bridge names", [b.get("name") for b in analogies.get("bridges", [])])
    for i, b in enumerate(analogies.get("bridges", [])):
        for key in ("name", "pattern", "example", "tip"):
            if not (b.get(key) or "").strip():
                errors.append(f"analogies bridge[{i}]: missing {key}")
    for i, h in enumerate(analogies.get("howTo", [])):
        if not (h.get("heading") or "").strip() or not (h.get("body") or "").strip():
            errors.append(f"analogies howTo[{i}]: missing heading or body")
    check_sections("reading_guide", reading)
    check_sections("overview", overview)
    n_topics, n_practice = check_math(math)

    check_unique("practice section names", [s.get("name") for s in practice.get("sections", [])])
    n_section_q = 0
    for s in practice.get("sections", []):
        if not (s.get("name") or "").strip():
            errors.append("sections: section with no name")
        for p in s.get("passages", []):
            if not (p.get("text") or "").strip():
                errors.append(f"sections {s.get('name')}: passage {p.get('title', '?')!r} missing text")
            n_section_q += len(p.get("questions", []))
            check_mcq(f"section '{s.get('name')}' passage '{p.get('title', '?')}'", p.get("questions", []), "prompt")

    for w in warnings:
        print(f"warning: {w}")
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    OUT.write_text(
        "// GENERATED by Scripts/gen_data.py — do not edit by hand.\n"
        "// Edit content/*.json and re-run the script.\n\n"
        "enum EmbeddedData {\n"
        f"    static let wordsJSON = {swift_literal(words)}\n\n"
        f"    static let readingGuideJSON = {swift_literal(reading)}\n\n"
        f"    static let overviewJSON = {swift_literal(overview)}\n\n"
        f"    static let mathJSON = {swift_literal(math)}\n\n"
        f"    static let passagesJSON = {swift_literal(passages)}\n\n"
        f"    static let analogiesJSON = {swift_literal(analogies)}\n\n"
        f"    static let practiceSectionsJSON = {swift_literal(practice)}\n\n"
        f"    static let booksJSON = {swift_literal(books)}\n"
        "}\n"
    )
    nb = sum(1 for w in words["words"] if w["source"] == "notebook")
    print(f"Wrote {OUT.relative_to(ROOT)}")
    print(f"  words: {n_words} ({nb} notebook, {n_words - nb} supplement)")
    print(f"  reading sections: {len(reading.get('sections', []))}, overview sections: {len(overview.get('sections', []))}")
    print(f"  math: {len(math.get('strands', []))} strands, {n_topics} topics, {n_practice} practice problems")
    print(f"  passages: {len(passages.get('passages', []))}, analogy practice: {len(analogies.get('practice', []))}")
    print(f"  timed sections: {len(practice.get('sections', []))} ({n_section_q} questions)")
    print(f"  books: {len(books.get('books', []))}")


if __name__ == "__main__":
    main()
