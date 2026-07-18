# SSAT Prep

**Grow your English vocabulary and reading skills on your Mac.** A fast, offline
study app built around the **SSAT Upper Level** — with vocabulary, analogy, and
reading practice that carries straight over to the **SAT** and everyday English.

![platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)
![swift](https://img.shields.io/badge/Swift-5.9-orange)
![license](https://img.shields.io/badge/license-MIT-blue)

It started from a real class: the core vocabulary was harvested from 61
photographed pages of a student's handwritten SSAT notebook (their own mnemonics
preserved), then expanded to **1,400+ hard, high-frequency words**. Everything
runs locally — no account, no network, all progress saved on your Mac.

> **Verbal-first.** The vocabulary, analogy, and reading work is general English
> skill-building and transfers directly to the SAT and other verbal tests. The
> math review and timed sections are SSAT-formatted.

## Features

- **Flashcards** — Anki-style **SM-2 spaced repetition** with in-session learning
  steps (1 min / 10 min) and four grades with interval previews. Flagged words
  (missed on a test or starred by hand) ride along in the mix and only clear once
  you truly master them (two Goods in a row, then a success the next day). The
  session **interleaves** review, flagged, and brand-new words so you always make
  progress on new material. Keyboard: `space` to flip, `1–4` to grade.
- **Word Test** — a straight audit of what you actually know: run all words, a
  section (30/50/80/100), your flagged set, or "yesterday's new," mark each
  right/wrong, and get the full miss list. Misses can auto-flag for drilling.
- **Synonym Quiz** — five-choice synonym questions generated from the deck;
  misses feed back into review.
- **Analogies** — the 12 bridge types, a solving method, and a bank of **180
  practice questions** — each built on a word from your own deck, with common-word
  answer choices and bridge-named explanations. Pick how many to drill; each set
  is a fresh random draw.
- **Word List** — searchable browser with a per-word study record, accuracy, and
  filters (flagged, learned, often-tested, added, struggling, mastered).
- **Reading** — a passage-mapping method and every question type with traps, plus
  **101 practice passages** — including original four-part retellings of **15
  classic books** so you can read a whole story in sections, each with explained
  questions.
- **Book Overviews** — chronological plot synopses for the featured books.
- **Math Review** — all four quantitative strands (numbers, algebra, geometry,
  data/probability/counting): **50 topics** with key facts, formulas, worked
  examples, traps, and **349 practice problems**.
- **Timed Sections** — **7 full timed sections (270 questions)** to build pacing.
- **Progress** — new-words-today, cards due, day streak, a review forecast, and
  quiz history.

## Install (downloaded release)

The app is **ad-hoc signed** (no paid Apple Developer account), so the first time
you open a downloaded copy, macOS Gatekeeper will warn that it's from an
"unidentified developer" — or, if you double-click it, say it "is damaged and
can't be opened." **It's not damaged or malware** — macOS just quarantines apps
from unidentified developers. Open it one of these ways:

**Easiest — right-click to open:**
1. Unzip `SSAT Prep.zip`.
2. **Right-click** (or Control-click) **`SSAT Prep.app` → Open**, then click **Open**
   in the dialog. You only do this once; afterward it launches normally.

**If macOS still blocks it (Sequoia / macOS 15+):**
1. Try to open it once (it gets blocked).
2. Go to  **System Settings → Privacy & Security**, scroll down to the
   "SSAT Prep was blocked" message, and click **Open Anyway**.

**Or clear the quarantine flag in Terminal** (fixes the "is damaged" error
directly):
```bash
xattr -cr "/path/to/SSAT Prep.app"    # e.g. ~/Downloads/SSAT Prep.app
open "/path/to/SSAT Prep.app"
```

Building it yourself (below) sidesteps all of this — locally built apps aren't
quarantined.

## Build & run

Requirements: **macOS 14+**, **Swift 5.9 / Xcode 15+**.

```bash
git clone <your-repo-url>
cd ssat-prep
./Scripts/make_app.sh        # → "SSAT Prep.app" (universal, ad-hoc signed)
open "SSAT Prep.app"
```

Prefer Xcode? Generate the project, then ⌘R:

```bash
python3 Scripts/generate_xcodeproj.py
open SSATPrep.xcodeproj
```

Run the tests (SM-2 scheduler, session queue, flag/mastery, quiz generator,
persistence, content validation):

```bash
swift test
```

## Content pipeline

All study content lives in `content/*.json` and is compiled into the binary — no
runtime resource loading:

```bash
python3 Scripts/gen_data.py   # content/*.json → Sources/SSATCore/Data/EmbeddedData.swift
```

Edit a JSON file (e.g. `content/words.json`), re-run the script, rebuild.

## Project structure

```
content/                 Study data (words, analogies, passages, math, books, sections)
Scripts/
  gen_data.py            content/*.json → embedded Swift
  make_app.sh            universal release build → "SSAT Prep.app"
  generate_xcodeproj.py  regenerate the Xcode project
Sources/
  SSATCore/              Model + logic: SM-2, StudySession, ProgressStore, content
  SSATPrep/              SwiftUI app (Flashcards, Quiz, Analogies, Reading, Math, …)
Tests/SSATCoreTests/     Unit tests
```

## Tech

SwiftUI + Swift Package Manager, an Anki-style SM-2 scheduler, JSON progress in
`~/Library/Application Support/SSATPrep/`. No third-party dependencies.

## Privacy

Fully offline. Nothing leaves your Mac; there is no account and no analytics.

## Disclaimer

Not affiliated with, authorized, or endorsed by the SSAT / Enrollment Management
Association or by the College Board (SAT). All study content here is original and
for educational use. "SSAT" and "SAT" are trademarks of their respective owners.

## License

[MIT](LICENSE) — © 2026 David Hu.
