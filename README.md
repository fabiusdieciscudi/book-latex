# Book Publishing Pipeline

A LaTeX-based book authoring system that compiles a single source into multiple output formats: typeset PDF, plain text, spellcheck-annotated text, and TTS-ready audio files.

---

## Architecture

The core idea is a single LaTeX source controlled by a `\purpose` variable, set at compile time, that switches the rendering behaviour of every command that cares about output format. The same `.tex` files produce radically different outputs depending on the target.

```
LaTeX source (.tex)
       │
       ▼
  \purpose switch
  ┌─────┬──────┬───────────┐
  │     │      │           │   
  pdf  txt  spellcheck   audio
  │     │      │           │
lualatex  make4ht (three separate configs)
  │     │      │           │
  PDF  HTML   HTML        HTML
        │      │           │
     html2txt.py (skips unchanged files)
        │      │           │
       TXT  TXT-spell   TXT-audio
                │           │
          BookAssistant  BookAssistant
           spellcheck       TTS
                         │
                       MP3
```

### The `\purpose` values

| Value               | Compiler         | Effect |
|---------------------|------------------|---|
| `pdf`               | lualatex         | Full typeset: drop caps, EBGaramond font, illustrations, decorative hyperlinks |
| `pdf` (via make4ht) | make4ht + tex4ht | Plain HTML intermediate for text extraction |
| `spellcheck`        | make4ht + tex4ht | Injects `@lang text @prevlang` markers around every foreign-language span so `BookAssistant` can verify hyphenation and detect mismatched guillemets per language |
| `audio`             | make4ht + tex4ht | Strips all visual formatting; reformats dialogue as `[Character]: speech` paragraphs for TTS voice assignment |

### Key design decisions

**`html2txt.py` as an intermediate step.** `make4ht` always regenerates all HTML files. `html2txt.py` only overwrites a `.txt` file if its content has actually changed, giving Make correct timestamps. This means only chapters that were edited trigger downstream audio regeneration — important because TTS synthesis is slow.

**Dialogue and thought commands.** `\spoken{character}{text}{hint}` and `\thought{character}{text}{hint}` are the central commands for all direct speech and interior monologue. In `pdf` mode they emit `«text»` with automatic drop-cap integration. In `audio` mode they emit `[character, hint]: text` as a standalone paragraph, which the TTS pipeline uses to assign and modulate voices.

**Foreign language handling.** `\frenchname`, `\englishname`, etc. call `\myforeignlanguage`, which in `pdf` mode delegates to Babel's `\foreignlanguage` for correct hyphenation, and in `spellcheck` mode emits language-change markers instead. These commands must not be used inside `\chapter` arguments, as they are fragile in moving contexts.

---

## Makefile goals

All goals assume the environment variable `TITLE` is set to the book's title (without `.tex`).

| Goal               | Description |
|--------------------|---|
| `all`              | Alias for `pdf` |
| `prepare`          | Creates `target/`, symlinks all `.tex` files and resource directories (`illustrazioni`, `comuni`, `fonts`, `frammenti`, `note di lavoro`) into it so the compiler finds everything in one place |
| `pdf`              | Runs `prepare`, then compiles the main book and the working notes (`Note di lavoro.tex`) with `lualatex` twice each (double pass for cross-references and TOC), then runs `post-clean` |
| `txt`              | Runs `html`, then `txt-files`, then `post-clean` |
| `txt-files`        | Converts all HTML files in `target/html/` to `.txt` via `html2txt.py`, only updating files whose content has changed |
| `html`             | Runs `prepare`, then runs `make4ht` with `make4ht-txt.cfg` to produce split XHTML files in `target/html/` |
| `txt-spell`        | Runs `html-spell`, then `txt-spell-files`, then `post-clean` |
| `txt-spell-files`  | Converts all HTML files in `target/html-spellcheck/` to `.txt`, only updating changed files |
| `html-spell`       | Runs `prepare`, then runs `make4ht` with `make4ht-spellcheck.cfg` to produce language-tagged XHTML in `target/html-spellcheck/` |
| `check-guillemets` | Runs `txt-spell`, then calls `BookAssistant check-guillemets` on the spellcheck text files to verify correct guillemet usage per language |
| `spellcheck`       | Runs `txt-spell`, then calls `BookAssistant spellcheck` against the project dictionaries (`config/Dizionario.txt` and `Dizionario.txt`) |
| `echo-check`       | Runs `txt-spell`, then calls `BookAssistant echo` for a diagnostic dump of the spellcheck text |
| `txt-audio`        | Runs `html-audio`, then `txt-audio-files`, then `post-clean` |
| `txt-audio-files`  | Converts all HTML files in `target/html-audio/` to `.txt`, only updating changed files |
| `html-audio`       | Runs `prepare`, then runs `make4ht` with `make4ht-audio.cfg` to produce dialogue-tagged XHTML in `target/html-audio/` |
| `audio`            | Runs `txt-audio`, then `audio-files`, then `post-clean` |
| `audio-files`      | For each `.txt` file in `target/txt-audio/`, calls `BookAssistant tts` to synthesise an MP3 in `target/audio/`, using standard-quality voice configs (excludes `voices-hq*.conf`) |
| `hq-audio`         | Runs `txt-audio`, then `hq-audio-files`, then `post-clean` |
| `hq-audio-files`   | Like `audio-files` but uses high-quality voice configs (`voices-hq*.conf`) and writes to `target/audio-hq/` |
| `clean`            | Removes the entire `target/` directory |
| `post-clean`       | Removes all intermediate compiler artefacts from `target/` (`.aux`, `.log`, `.4ct`, `.epub`, `.html`, `.css`, etc.) while leaving the final outputs intact |

---

## LaTeX commands

### Structure and layout

**`\cover{title}{subtitle}{image}`**
Typesets the book cover page: large bold centred title, subtitle, and an illustration. Sets `\thispagestyle{empty}`, followed by a blank page.

**`\disclaimer`**
Typesets a standard fiction disclaimer page (`\thispagestyle{empty}`): *"Questa è un'opera di fantasia…"*

**`\epigraph{text}`**
Typesets a right-aligned italic epigraph on its own page, vertically centred, with empty page style.

**`\blankpage`**
Inserts a completely empty page with no header, footer, or page number.

**`\threestars`**
Inserts a centred `***` section break with appropriate vertical spacing. Used to mark scene breaks within a chapter.

**`\entrelacement`**
Alias for `\threestars`. Used specifically to mark entrelacement breaks (interleaved plot threads).

**`\temporaljump`**
Inserts a `\bigskip`. Used to mark a time skip within a scene without a full section break.

---

### Drop caps

**`\dropcap{letter}{rest}`**
Typesets a drop cap using `\lettrine` in `pdf` mode. In other modes emits `letter` + `rest` as plain text. The number of lines is controlled by the counter `dropcaplines` (default 3).

**`\smartdropcap{text}`**
Extracts the first Unicode character of `text` via LuaTeX and calls `\mylettrine` automatically, also picking up any pending `\spokenAnteToks` (the opening guillemet set by `\spoken`). Handles `\xspace` and `\frenchname`/`\englishname` wrappers correctly. **Note:** the argument must not contain fragile commands that expand to control sequences before the Lua extraction step; pass the plain name string, not a `\*name` macro, if the chapter opens with a foreign name.

---

### Foreign languages

All language commands come in two flavours: `\langname{text}` for proper nouns (no italics) and `\lang{text}` for foreign words or phrases (italicised). In `pdf` mode both switch Babel to the appropriate language for hyphenation. In `spellcheck` mode they emit ` @lang text @prevlang` markers.

| Command                               | Language                                          |
|---------------------------------------|---------------------------------------------------|
| `\frenchname{t}` / `\french{t}`       | French                                            |
| `\englishname{t}` / `\english{t}`     | English                                           |
| `\germanname{t}` / `\german{t}`       | German                                            |
| `\dutchname{t}` / `\dutch{t}`         | Dutch                                             |
| `\irishname{t}` / `\irish{t}`         | Irish                                             |
| `\latinname{t}` / `\latin{t}`         | Latin                                             |
| `\swedishname{t}` / `\swedish{t}`     | Swedish                                           |
| `\turkishname{t}` / `\turkish{t}`     | Turkish                                           |
| `\provencalname{t}` / `\provencal{t}` | Provençal (mapped to French)                      |
| `\japanesename{t}` / `\japanese{t}`   | Japanese (wrapped in `\mbox`, no Babel switching) |

---

### Dialogue and thought

**`\spoken{character}{text}{hint}`**
The primary dialogue command. In `pdf` mode emits `«text»`, integrating with `\smartdropcap` via `\spokenAnteToks` when the speech opens a chapter. In `audio` mode emits `[character, hint]: text` as a standalone paragraph for TTS voice assignment. The `hint` argument (e.g. a tone or emotional cue) is optional and may be empty.

**`\thought{character}{text}{hint}`**
Like `\spoken` but for interior monologue. In `pdf` mode emits `"text"` (straight double quotes). In `audio` mode same format as `\spoken`.

**`\sq{text}`**
Short inline quotation: emits `"text"` (straight double quotes). For brief citations within narration.

The following shorthand commands are pre-defined for the named characters. Each takes an optional hint as `[hint]` and the speech text as the mandatory argument:

| Command         | Character                          |
|-----------------|------------------------------------|
| `\sxx` / `\txx` | unnamed default (spoken / thought) |
| `\sxa` … `\sxf` | unnamed a–f                        |

---

### Text blocks

**`\letter{text}`**
Typesets a letter or handwritten note: italic, ragged-right, indented left margin, hyphenation suppressed.

**`\poetry{text}`**
Typesets a verse block: italic text inside a `quoting` environment.

**`\quotationx[style]{text}`**
Typesets a generic indented quotation. The optional `style` argument defaults to `\itshape`; pass an empty group `{}` for upright text.

**`\newspaper{text}`**
Typesets a newspaper excerpt: italic, slightly smaller than body text, inside a `quoting` environment.

**`\email{from}{to}{subject}{body}{speaker}`**
In `pdf` mode typesets a formatted email block with To/From/Subject header in a smaller font. In `audio` mode emits the subject and body as a `\spoken` block attributed to `speaker` (pass empty `{}` for no speaker attribution).

**`\note{text}`**
In `pdf` mode typesets an editorial note in small red italic text (for author's working notes embedded in the source). In `audio` mode suppressed entirely.

---

### Illustrations

**`\illustration{file}`**
Inserts an image centred on its own page, scaled to fit within the text area, with equal elastic space above and below. Does nothing if the boolean `illustrations` is false.

**`\fullpageillustration[width]{file}`**
Inserts a full-page illustration on the next page (via `\afterpage`), with empty page style. Default width is `1\textwidth`.

**`\afterpageillustration[width]{file}`**
Like `\fullpageillustration` but vertically centred with equal space above and below. Default width `0.95\textwidth`.

**`\afterpagetopillustration[width]{file}`**
Inserts an illustration anchored to the top of the next page, followed by vertical space. Default width `0.95\textwidth`.

---

### Typography and miscellaneous

**`\acronym{text}`**
In `pdf` mode renders `text` as small caps (`\textsc{\lowercase{…}}`). In other modes emits `text` as-is.

**`\yellow{text}`**
Highlights `text` with a pale yellow background (25% yellow). Intended for marking passages under review.

**`\comment{text}`**
Suppresses `text` entirely. Used for author margin comments that should never appear in any output.

**`\ellipsis`**
Emits `\ldots` followed by `\xspace`. Use instead of `...` for correct spacing.

**`\interruption`**
Emits an em-dash (`---`). Used for an abrupt interruption of dialogue.

**`\Pffft`**
Emits `Pffft…`

**`\Mmmh`**
Emits `Mmmh…`

**`\beh` / `\Beh`**
Emits `be'` / `Be'` (Italian colloquial truncation of *beh*).

---

### Punctuation helpers

**`\Pffft`**, **`\Mmmh`**, **`\beh`**, **`\Beh`**, **`\ellipsis`**, **`\interruption`** — see Typography section above.