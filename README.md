# anvil

**Forge digital knowledge into printed study pages.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

anvil turns Markdown into printed study pages on dot-grid, lined, graph, or blank paper. Pipe in notes from an AI coding agent or a text file, get a PDF designed for pen-and-paper thinking — sparse seeds with open space to write on.

```
echo "# TCP Handshake\n\nSYN → SYN-ACK → ACK" | anvil
```

## Install

### Homebrew (macOS / Linux)

```sh
brew tap SalamTry/anvil
brew install anvil
brew install --cask basictex   # LuaLaTeX — required for PDF rendering
```

### Manual

Clone the repo and ensure dependencies are on your PATH:

```sh
git clone https://github.com/SalamTry/anvil.git ~/anvil
export PATH="$HOME/anvil:$PATH"
```

**Dependencies:**

| Tool | Install | Purpose |
|------|---------|---------|
| pandoc | `brew install pandoc` | Markdown → LaTeX |
| lualatex | `brew install --cask basictex` | LaTeX → PDF |
| Python 3 + Pillow | `brew install python3 && pip3 install Pillow` | Theme background generators |
| d2 *(optional)* | `brew install d2` | Sketch-style diagrams |
| librsvg *(optional)* | `brew install librsvg` | SVG → PDF for d2 diagrams |

**Font:** [Indie Flower](https://fonts.google.com/specimen/Indie+Flower) — the handwritten body font. Install it system-wide.

## Usage

```sh
# From a file
anvil notes.md

# From stdin
echo "# Pointers\n\nA pointer stores a memory address." | anvil

# Skip printing, just generate the PDF
anvil --no-print notes.md

# Open the PDF after generating
anvil --preview notes.md
```

Output goes to `~/anvil/output/NNN-name-YYYY-MM-DD.pdf` with an auto-incrementing entry number.

### Themes

Themes control the page background. Pick one with `--theme=`:

```sh
anvil --theme=dot notes.md       # Dot grid (default) — minor dots every 5mm, major every 15mm
anvil --theme=lined notes.md     # Horizontal ruled lines — notebook paper
anvil --theme=graph notes.md     # Full grid — horizontal and vertical lines
anvil --theme=blank notes.md     # Clean white — no grid marks
```

### Schemes

Schemes control colors and fonts. Pick one with `--scheme=`:

```sh
anvil --scheme=pencil notes.md   # Pencil — muted grays, handwritten feel (default)
```

Themes and schemes are independent — combine them freely:

```sh
anvil --theme=lined --scheme=pencil notes.md
```

### Paper sizes

```sh
anvil --paper=a5 notes.md        # A5 — default, 148×210mm
anvil --paper=a6 notes.md        # A6 — pocket, 105×148mm
anvil --paper=a4 notes.md        # A4 — full page, 210×297mm
anvil --paper=letter notes.md    # Letter — US standard, 8.5×11in
```

Shorthand: `--a5`, `--a6`.

### Visual blocks

Visual blocks are fenced code blocks in your Markdown that render as styled layouts instead of code.

**Flow** — numbered steps with visual connectors:

````md
```flow
Clone the repo
Install dependencies
Run the tests
Deploy to production
```
````

Each line becomes a numbered step with an accent-colored circle and connector lines between steps.

**Table** — pipe-delimited rows with header styling and alternating shading:

````md
```table
Feature | React | Vue | Svelte
Virtual DOM | Yes | Yes | No
Bundle size | 42kb | 33kb | 1.6kb
Learning curve | Moderate | Easy | Easy
```
````

The first row becomes a bold header. Even rows get subtle shading.

Standard Markdown tables (`| Col | Col |` with `|---|---|` separator) also render with the same enhanced styling automatically.

**Card** — tinted callout box with accent left border:

````md
```card
**Spaced repetition** works by increasing the interval between reviews each time you recall something correctly.

- First review: 1 day
- Second review: 3 days
- Third review: 7 days

*The forgetting curve flattens with each successful recall.*
```
````

Content inside cards supports full Markdown formatting — bold, italic, and lists. Cards use the scheme's accent color for the left border and a light tint for the background fill.

**d2 diagrams** — sketch-style diagrams via [d2](https://d2lang.com):

````md
```d2
client -> server: request
server -> db: query
db -> server: result
server -> client: response
```
````

Requires `d2` and `librsvg` installed. Falls back to a placeholder if missing.

## AI agent integration

### Claude Code

This repo ships a `/anvil` skill. In any Claude Code session inside the repo, type `/anvil` to forge a study page from conversation context. The skill picks the right page type, selects visual blocks, generates sparse markdown, and previews before printing.

### Any agent (Codex, OpenCode, etc.)

anvil is built for the pipe. Any AI coding agent that runs shell commands can generate study pages:

```sh
# Basic pipe
echo "# Hash Tables\n\nKey concepts:\n- Hash function maps keys to indices\n- Collisions resolved by chaining or open addressing" | anvil --no-print

# With visual blocks
echo '# Deploy Flow\n\n```flow\nBuild the image\nPush to registry\nRoll out pods\nVerify health checks\n```' | anvil --no-print

# Customize theme and paper
echo "markdown content" | anvil --no-print --theme=lined --paper=a4
```

The `--no-print` flag generates the PDF without sending it to a printer — useful when the agent doesn't have access to a physical printer.

## Contributing

### Adding a theme

Create a directory under `themes/` with a `generate` executable:

```
themes/
  yourtheme/
    generate     # Script that outputs a cached PNG path
```

The generator interface:

```sh
./themes/yourtheme/generate <paper-size> <minor-color-hex> <major-color-hex>
# Outputs: /path/to/cached/background.png
```

Paper sizes: `a5`, `a6`, `a4`, `letter`. Colors are 6-digit hex without `#`. Cache results in `$ANVIL_GRID_CACHE` (default: `~/.cache/anvil/grids`).

For a theme with no background (like `blank`), output nothing — the LaTeX template skips `\includegraphics` when `grid-bg` is empty.

### Adding a scheme

Drop a `.sh` file in `schemes/`:

```sh
# schemes/midnight.sh
typeset -A COLORS=(
  [gridline]=334455
  [gridmajor]=556677
  [accent]=88AACC
  [muted]=667788
  [body]=DDEEFF
)
FONT_MAIN="Indie Flower"
FONT_MONO="Menlo"
```

### Running tests

```sh
# Full pipeline tests (end-to-end: markdown → PDF → visual regression)
./test/run-tests.sh

# Filter-seam tests (Lua filter in isolation)
./test/filter-tests.sh

# Python unit tests (theme generators)
pytest test/

# Filter a specific test
./test/run-tests.sh --filter=theme
```

### Project structure

```
anvil                  # Main CLI script (zsh)
anvil-filter.lua       # Pandoc Lua filter — title, tables, flow, card, d2
sketch-page.tex        # LaTeX template — geometry, fonts, colors, grid-snap
grid-snap.lua          # LuaTeX callback — snaps baselines to 5mm pitch
themes/
  dot/generate         # Dot grid background (Python/Pillow)
  lined/generate       # Horizontal ruled lines (Python/Pillow)
  graph/generate       # Full grid squares (Python/Pillow)
  blank/generate       # No background (outputs nothing)
schemes/
  pencil.sh            # Muted pencil-gray color scheme
Formula/
  anvil.rb             # Homebrew formula
test/
  run-tests.sh         # Pipeline integration tests
  filter-tests.sh      # Filter-seam unit tests
  test_grid_png.py     # Dot theme generator tests (pytest)
  test_lined_png.py    # Lined theme generator tests (pytest)
  test_graph_png.py    # Graph theme generator tests (pytest)
  fixtures/            # Markdown test fixtures
  baselines/           # PNG baselines for visual regression
```

## CLI reference

```
anvil — forge digital knowledge into printed study pages

Usage: anvil [options] <file.md>
       echo "markdown" | anvil [options]

Options:
  --paper=SIZE    Paper size: a5 (default), a6, a4, letter
  --scheme=NAME   Color/font scheme (default: pencil)
  --theme=NAME    Background theme: dot, blank, graph, lined (default: dot)
  --preview       Open PDF after generating
  --no-print      Skip sending to printer
  -h, --help      Show this help
```

**Environment variables:**

| Variable | Default | Purpose |
|----------|---------|---------|
| `ANVIL_DATA_DIR` | `~/anvil` | User data directory (output PDFs, entry counter) |
| `ANVIL_GRID_CACHE` | `~/.cache/anvil/grids` | Cache directory for theme-generated PNGs |
| `ANVIL_D2_BIN` | `d2` | Path to the d2 binary |
| `ANVIL_RSVG_BIN` | `rsvg-convert` | Path to the rsvg-convert binary |

## License

[MIT](LICENSE)
