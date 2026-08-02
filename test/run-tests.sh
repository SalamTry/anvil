#!/bin/zsh
# anvil test harness — visual regression + pipeline validation
# Usage: ./run-tests.sh [--update-baselines]

export PATH="/Library/TeX/texbin:$PATH"

PRINT_DIR="$HOME/anvil"
TEST_DIR="$PRINT_DIR/test"
FIXTURES="$TEST_DIR/fixtures"
BASELINES="$TEST_DIR/baselines"
RESULTS="$TEST_DIR/results"
DEEPPRINT="$PRINT_DIR/anvil"

mkdir -p "$FIXTURES" "$BASELINES" "$RESULTS"

UPDATE_BASELINES=false
[[ "${1:-}" == "--update-baselines" ]] && UPDATE_BASELINES=true

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

render() {
  local input="$1" name="$2" flags="${3:-}"
  local bname=$(basename "$input" .md)
  local today=$(date +%Y-%m-%d)
  echo "0" > "$PRINT_DIR/.entry-counter"
  # Clean previous output with same name
  rm -f "$PRINT_DIR/output/001-${bname}-${today}.pdf"
  $DEEPPRINT --no-print $flags "$input" >/dev/null 2>&1 || true
  local pdf="$PRINT_DIR/output/001-${bname}-${today}.pdf"
  local png="$RESULTS/${name}.png"
  if [[ -f "$pdf" ]]; then
    sips -s format png "$pdf" --out "$png" >/dev/null 2>&1 || true
  fi
  echo "$png"
}

visual_diff() {
  local name="$1" result_png="$2"
  local baseline_png="$BASELINES/${name}.png"

  if [[ ! -f "$result_png" ]]; then
    fail "$name (result PNG missing)"
    return
  fi

  if $UPDATE_BASELINES; then
    cp "$result_png" "$baseline_png"
    pass "$name (baseline saved)"
    return
  fi

  if [[ ! -f "$baseline_png" ]]; then
    fail "$name (no baseline — run with --update-baselines)"
    return
  fi

  local b_w=$(sips -g pixelWidth "$baseline_png" 2>/dev/null | awk '/pixelWidth/{print $2}')
  local b_h=$(sips -g pixelHeight "$baseline_png" 2>/dev/null | awk '/pixelHeight/{print $2}')
  local r_w=$(sips -g pixelWidth "$result_png" 2>/dev/null | awk '/pixelWidth/{print $2}')
  local r_h=$(sips -g pixelHeight "$result_png" 2>/dev/null | awk '/pixelHeight/{print $2}')

  if [[ "$b_w" == "$r_w" && "$b_h" == "$r_h" ]]; then
    pass "$name (${r_w}x${r_h})"
  else
    fail "$name (size changed: ${b_w}x${b_h} -> ${r_w}x${r_h})"
  fi
}

# ─── Fixtures ───

cat > "$FIXTURES/basic.md" << 'EOF'
# Basic Test Page

This is body text.
Second line stands alone.

- bullet one
- bullet two
- bullet three

## A section

Some content here.

---

> A blockquote prompt
EOF

cat > "$FIXTURES/table.md" << 'EOF'
# Table Test

| Col A | Col B | Col C |
|-------|-------|-------|
| one   | two   | three |
| four  |       | six   |
EOF

cat > "$FIXTURES/rich-table.md" << 'EOF'
# Rich Table Test

| Feature | Status | Note |
|---------|--------|------|
| **bold** | *italic* | `code` |
| plain | plain | plain |
EOF

cat > "$FIXTURES/no-h1.md" << 'EOF'
This file has no H1 heading.

Just body text and bullets:
- one
- two
EOF

cat > "$FIXTURES/blank-before-h1.md" << 'EOF'

# Title After Blank Line

Body text here.
EOF

cat > "$FIXTURES/multi-h1.md" << 'EOF'
# First Title

Body.

# Second Title

More body.
EOF

# ─── Run ───

echo ""
echo "deepprint test suite"
echo "===================="
echo ""

echo "[1] Basic pipeline (A5)"
png=$(render "$FIXTURES/basic.md" "basic-a5")
[[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
visual_diff "basic-a5" "$png"

echo "[2] Basic pipeline (A6)"
png=$(render "$FIXTURES/basic.md" "basic-a6" "--a6")
[[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
visual_diff "basic-a6" "$png"

echo "[3] Table with grid lines"
png=$(render "$FIXTURES/table.md" "table")
[[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
visual_diff "table" "$png"

echo "[4] No H1 — fallback to filename"
png=$(render "$FIXTURES/no-h1.md" "no-h1")
[[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"

echo "[5] Blank line before H1"
png=$(render "$FIXTURES/blank-before-h1.md" "blank-before-h1")
[[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"

echo "[6] Multiple H1s"
png=$(render "$FIXTURES/multi-h1.md" "multi-h1")
[[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"

echo "[7] Rich table cells"
png=$(render "$FIXTURES/rich-table.md" "rich-table")
[[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
visual_diff "rich-table" "$png"

echo "[8] Color contract"
filter_colors=$(grep -oE '\\color\{[a-zA-Z]+\}' "$PRINT_DIR/grid-tables.lua" 2>/dev/null | sed 's/\\color{//;s/}//' | sort -u)
template_colors=$(grep -oE 'definecolor\{[a-zA-Z]+\}' "$PRINT_DIR/sketch-page.tex" 2>/dev/null | sed 's/definecolor{//;s/}//' | sort -u)
if [[ -z "$filter_colors" ]]; then
  pass "no colors in filter to check"
else
  for c in ${(f)filter_colors}; do
    if echo "$template_colors" | grep -q "^${c}$"; then
      pass "color '$c' defined"
    else
      fail "color '$c' missing from template"
    fi
  done
fi

echo "[9] Variable contract: deepprint -> template"
# Every -V variable passed by deepprint should be referenced in the template
script_vars=$(grep -oE '\-V [a-zA-Z_-]+=' "$DEEPPRINT" 2>/dev/null | sed 's/-V //;s/=//' | sort -u)
for v in ${(f)script_vars}; do
  if grep -q "\$${v}\$\|if(${v})" "$PRINT_DIR/sketch-page.tex" 2>/dev/null; then
    pass "variable '$v' used in template"
  else
    fail "variable '$v' passed by script but NOT referenced in template"
  fi
done

echo "[10] Variable contract: template -> deepprint"
# Every $variable$ in the template should be passed via -V by deepprint
# Exclude pandoc builtins (body) and template keywords (if/else/endif/for/endfor/sep)
template_vars=$(grep -oE '\$[a-zA-Z_-]+\$' "$PRINT_DIR/sketch-page.tex" 2>/dev/null | sed 's/\$//g' | grep -vE '^(body|if|else|endif|for|endfor|sep)$' | sort -u)
for v in ${(f)template_vars}; do
  if grep -q "\-V ${v}=" "$DEEPPRINT" 2>/dev/null || grep -q "\-V ${v} " "$DEEPPRINT" 2>/dev/null; then
    pass "template var '$v' provided by script"
  elif grep -qF "\$if(${v})\$" "$PRINT_DIR/sketch-page.tex" 2>/dev/null; then
    pass "template var '$v' optional (guarded by \$if\$)"
  else
    fail "template var '$v' NOT provided by script"
  fi
done

echo "[11] Paper: --paper=a4"
png=$(render "$FIXTURES/basic.md" "basic-a4" "--paper=a4")
[[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
visual_diff "basic-a4" "$png"

echo "[12] Paper: --paper=letter"
png=$(render "$FIXTURES/basic.md" "basic-letter" "--paper=letter")
[[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
visual_diff "basic-letter" "$png"

echo "[13] Paper: invalid size errors"
echo "0" > "$PRINT_DIR/.entry-counter"
err=$($DEEPPRINT --no-print --paper=nonsense "$FIXTURES/basic.md" 2>&1) && {
  fail "should have exited non-zero for invalid size"
} || {
  if echo "$err" | grep -q "unknown paper size"; then
    pass "error message for invalid size"
  else
    fail "missing error message (got: $err)"
  fi
}

echo "[14] Empty table cells — no crash"
cat > "$FIXTURES/empty-cells.md" << 'EOF'
# Empty Cells

| A | B | C |
|---|---|---|
|   |   |   |
| x |   | y |
EOF
png=$(render "$FIXTURES/empty-cells.md" "empty-cells")
[[ -f "$png" ]] && pass "PDF rendered with empty cells" || fail "PDF crashed on empty cells"

cat > "$FIXTURES/mixed-content.md" << 'EOF'
# Mixed Content

Body paragraph one.

Body paragraph two.

- list item alpha
- list item beta

## Section heading

After the heading.

| A | B |
|---|---|
| x | y |
| z | w |
EOF

cat > "$FIXTURES/headings.md" << 'EOF'
# Heading Test

Body after title.

## Section heading

Body after section.

### Subsection heading

Body after subsection.
EOF

echo "[15] Paper: --a6 alias still works"
png=$(render "$FIXTURES/basic.md" "a6-alias" "--a6")
[[ -f "$png" ]] && pass "--a6 alias renders PDF" || fail "--a6 alias failed"

echo "[16] Grid-snap: baselines on 5mm grid"
png=$(render "$FIXTURES/mixed-content.md" "mixed-content")
if [[ -f "$png" ]]; then
  pass "PDF rendered"
  today_date=$(date +%Y-%m-%d)
  pdf_path="$PRINT_DIR/output/001-mixed-content-${today_date}.pdf"
  grid_pt=14.173228  # 5mm in PDF points

  # Extract body-content Y positions: wide flows (>50pt) with body text height (<12pt),
  # skipping title (first flow) and footer (y>400). Table cells are narrow flows.
  body_tops=()
  first_skipped=false
  while IFS=$'\t' read -r level page par block line word left top width height conf text; do
    [[ "$level" != "3" ]] && continue
    [[ "$text" != "###FLOW###" ]] && continue
    (( $(echo "$top > 400" | bc -l) )) && continue
    (( $(echo "$width < 50" | bc -l) )) && continue
    if ! $first_skipped; then
      first_skipped=true
      continue
    fi
    body_tops+=("$top")
  done < <(pdftotext -tsv "$pdf_path" - 2>/dev/null)

  if [[ ${#body_tops[@]} -lt 3 ]]; then
    fail "grid-snap: too few body flows extracted (${#body_tops[@]})"
  else
    all_grid=true
    prev=""
    for y in "${body_tops[@]}"; do
      if [[ -n "$prev" ]]; then
        delta=$(echo "$y - $prev" | bc -l)
        quotient=$(echo "$delta / $grid_pt" | bc -l)
        rounded=$(printf "%.0f" "$quotient")
        snapped=$(echo "$rounded * $grid_pt" | bc -l)
        err=$(echo "d=$delta - $snapped; if (d < 0) -d else d" | bc -l)
        if (( $(echo "$err > 0.6" | bc -l) )); then
          fail "grid-snap: delta ${delta}pt not a 5mm multiple (error=${err}pt)"
          all_grid=false
          break
        fi
      fi
      prev="$y"
    done
    $all_grid && pass "all ${#body_tops[@]} body flows grid-aligned"
  fi
else
  fail "PDF not rendered"
fi

echo "[17] Grid-aligned headings: baselines on 5mm grid"
png=$(render "$FIXTURES/headings.md" "headings")
if [[ -f "$png" ]]; then
  pass "headings PDF rendered"
  today_date=$(date +%Y-%m-%d)
  pdf_path="$PRINT_DIR/output/001-headings-${today_date}.pdf"
  grid_pt=14.173228  # 5mm in PDF points

  body_tops=()
  first_skipped=false
  while IFS=$'\t' read -r level page par block line word left top width height conf text; do
    [[ "$level" != "3" ]] && continue
    [[ "$text" != "###FLOW###" ]] && continue
    (( $(echo "$top > 400" | bc -l) )) && continue
    (( $(echo "$width < 50" | bc -l) )) && continue
    if ! $first_skipped; then
      first_skipped=true
      continue
    fi
    body_tops+=("$top")
  done < <(pdftotext -tsv "$pdf_path" - 2>/dev/null)

  if [[ ${#body_tops[@]} -lt 3 ]]; then
    fail "headings grid: too few flows extracted (${#body_tops[@]}, need >=3 for heading levels)"
  else
    all_grid=true
    prev=""
    for y in "${body_tops[@]}"; do
      if [[ -n "$prev" ]]; then
        delta=$(echo "$y - $prev" | bc -l)
        quotient=$(echo "$delta / $grid_pt" | bc -l)
        rounded=$(printf "%.0f" "$quotient")
        snapped=$(echo "$rounded * $grid_pt" | bc -l)
        err=$(echo "d=$delta - $snapped; if (d < 0) -d else d" | bc -l)
        if (( $(echo "$err > 0.6" | bc -l) )); then
          fail "headings grid: delta ${delta}pt not a 5mm multiple (error=${err}pt)"
          all_grid=false
          break
        fi
      fi
      prev="$y"
    done
    $all_grid && pass "all ${#body_tops[@]} heading+body flows grid-aligned"
  fi
else
  fail "headings PDF not rendered"
fi

echo ""
echo "===================="
echo "Results: $PASS passed, $FAIL failed"
echo ""

[[ $FAIL -eq 0 ]]
