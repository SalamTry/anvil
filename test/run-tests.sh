#!/bin/zsh
# anvil test harness — visual regression + pipeline validation
# Usage: ./run-tests.sh [--update-baselines] [--filter=<name>]

export PATH="/Library/TeX/texbin:$PATH"

PRINT_DIR="$HOME/anvil"
TEST_DIR="$PRINT_DIR/test"
FIXTURES="$TEST_DIR/fixtures"
BASELINES="$TEST_DIR/baselines"
RESULTS="$TEST_DIR/results"
DEEPPRINT="$PRINT_DIR/anvil"

mkdir -p "$FIXTURES" "$BASELINES" "$RESULTS"

UPDATE_BASELINES=false
FILTER_PATTERN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update-baselines) UPDATE_BASELINES=true; shift ;;
    --filter=*) FILTER_PATTERN="${1#--filter=}"; shift ;;
    --filter) FILTER_PATTERN="$2"; shift 2 ;;
    *) shift ;;
  esac
done

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

should_run() { [[ -z "$FILTER_PATTERN" ]] || [[ "$1" == *"$FILTER_PATTERN"* ]]; }

# ─── Core helpers ───

render() {
  local input="$1" name="$2" flags="${3:-}"
  local bname=$(basename "$input" .md)
  local today=$(date +%Y-%m-%d)
  echo "0" > "$PRINT_DIR/.entry-counter"
  rm -f "$PRINT_DIR/output/001-${bname}-${today}.pdf"
  $DEEPPRINT --no-print $flags "$input" >/dev/null 2>&1 || true
  local pdf="$PRINT_DIR/output/001-${bname}-${today}.pdf"
  local png="$RESULTS/${name}.png"
  if [[ -f "$pdf" ]]; then
    sips -s format png "$pdf" --out "$png" >/dev/null 2>&1 || true
  fi
  echo "$png"
}

# ─── Assertion functions ───

assert_visual_match() {
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

assert_grid_aligned() {
  local label="$1" pdf_path="$2" min_flows="${3:-3}"
  local grid_pt=14.173228  # 5mm in PDF points

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

  if [[ ${#body_tops[@]} -lt $min_flows ]]; then
    fail "$label: too few body flows extracted (${#body_tops[@]}, need >=$min_flows)"
    return
  fi

  local all_grid=true prev=""
  for y in "${body_tops[@]}"; do
    if [[ -n "$prev" ]]; then
      local delta=$(echo "$y - $prev" | bc -l)
      local quotient=$(echo "$delta / $grid_pt" | bc -l)
      local rounded=$(printf "%.0f" "$quotient")
      local snapped=$(echo "$rounded * $grid_pt" | bc -l)
      local err=$(echo "d=$delta - $snapped; if (d < 0) -d else d" | bc -l)
      if (( $(echo "$err > 0.6" | bc -l) )); then
        fail "$label: delta ${delta}pt not a 5mm multiple (error=${err}pt)"
        all_grid=false
        break
      fi
    fi
    prev="$y"
  done
  $all_grid && pass "all ${#body_tops[@]} ${label} flows grid-aligned"
}

assert_contract() {
  # Color contract: every \color{name} in the filter must be defined in the template
  local filter_colors=$(grep -oE '\\color\{[a-zA-Z]+\}' "$PRINT_DIR/anvil-filter.lua" 2>/dev/null | sed 's/\\color{//;s/}//' | sort -u)
  local template_colors=$(grep -oE 'definecolor\{[a-zA-Z]+\}' "$PRINT_DIR/sketch-page.tex" 2>/dev/null | sed 's/definecolor{//;s/}//' | sort -u)
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

  # Variable contract: script -> template
  local script_vars=$(grep -oE '\-V [a-zA-Z_-]+=' "$DEEPPRINT" 2>/dev/null | sed 's/-V //;s/=//' | sort -u)
  for v in ${(f)script_vars}; do
    if grep -q "\$${v}\$\|if(${v})" "$PRINT_DIR/sketch-page.tex" 2>/dev/null; then
      pass "variable '$v' used in template"
    else
      fail "variable '$v' passed by script but NOT referenced in template"
    fi
  done

  # Variable contract: template -> script
  local template_vars=$(grep -oE '\$[a-zA-Z_-]+\$' "$PRINT_DIR/sketch-page.tex" 2>/dev/null | sed 's/\$//g' | grep -vE '^(body|if|else|endif|for|endfor|sep)$' | sort -u)
  for v in ${(f)template_vars}; do
    if grep -q "\-V ${v}=" "$DEEPPRINT" 2>/dev/null || grep -q "\-V ${v} " "$DEEPPRINT" 2>/dev/null; then
      pass "template var '$v' provided by script"
    elif grep -q "meta\.${v}\b\|meta\[.${v}.\]" "$PRINT_DIR/anvil-filter.lua" 2>/dev/null; then
      pass "template var '$v' provided by filter metadata"
    elif grep -qF "\$if(${v})\$" "$PRINT_DIR/sketch-page.tex" 2>/dev/null; then
      pass "template var '$v' optional (guarded by \$if\$)"
    else
      fail "template var '$v' NOT provided by script or filter"
    fi
  done
}

# ─── Tests ───

echo ""
echo "anvil test suite"
echo "===================="
echo ""

should_run "basic-a5" && {
  echo "[1] Basic pipeline (A5)"
  png=$(render "$FIXTURES/basic.md" "basic-a5")
  [[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
  assert_visual_match "basic-a5" "$png"
}

should_run "basic-a6" && {
  echo "[2] Basic pipeline (A6)"
  png=$(render "$FIXTURES/basic.md" "basic-a6" "--a6")
  [[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
  assert_visual_match "basic-a6" "$png"
}

should_run "table" && {
  echo "[3] Table with grid lines"
  png=$(render "$FIXTURES/table.md" "table")
  [[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
  assert_visual_match "table" "$png"
}

should_run "no-h1" && {
  echo "[4] No H1 — fallback to filename"
  png=$(render "$FIXTURES/no-h1.md" "no-h1")
  [[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
}

should_run "blank-before-h1" && {
  echo "[5] Blank line before H1"
  png=$(render "$FIXTURES/blank-before-h1.md" "blank-before-h1")
  [[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
}

should_run "multi-h1" && {
  echo "[6] Multiple H1s"
  png=$(render "$FIXTURES/multi-h1.md" "multi-h1")
  [[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
}

should_run "rich-table" && {
  echo "[7] Rich table cells"
  png=$(render "$FIXTURES/rich-table.md" "rich-table")
  [[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
  assert_visual_match "rich-table" "$png"
}

should_run "contract" && {
  echo "[8-10] Contract checks"
  assert_contract
}

should_run "paper-a4" && {
  echo "[11] Paper: --paper=a4"
  png=$(render "$FIXTURES/basic.md" "basic-a4" "--paper=a4")
  [[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
  assert_visual_match "basic-a4" "$png"
}

should_run "paper-letter" && {
  echo "[12] Paper: --paper=letter"
  png=$(render "$FIXTURES/basic.md" "basic-letter" "--paper=letter")
  [[ -f "$png" ]] && pass "PDF rendered" || fail "PDF not rendered"
  assert_visual_match "basic-letter" "$png"
}

should_run "paper-invalid" && {
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
}

should_run "empty-cells" && {
  echo "[14] Empty table cells — no crash"
  png=$(render "$FIXTURES/empty-cells.md" "empty-cells")
  [[ -f "$png" ]] && pass "PDF rendered with empty cells" || fail "PDF crashed on empty cells"
}

should_run "a6-alias" && {
  echo "[15] Paper: --a6 alias still works"
  png=$(render "$FIXTURES/basic.md" "a6-alias" "--a6")
  [[ -f "$png" ]] && pass "--a6 alias renders PDF" || fail "--a6 alias failed"
}

should_run "grid-snap" && {
  echo "[16] Grid-snap: baselines on 5mm grid"
  png=$(render "$FIXTURES/mixed-content.md" "mixed-content")
  if [[ -f "$png" ]]; then
    pass "PDF rendered"
    assert_grid_aligned "body" "$PRINT_DIR/output/001-mixed-content-$(date +%Y-%m-%d).pdf"
  else
    fail "PDF not rendered"
  fi
}

should_run "grid-headings" && {
  echo "[17] Grid-aligned headings: baselines on 5mm grid"
  png=$(render "$FIXTURES/headings.md" "headings")
  if [[ -f "$png" ]]; then
    pass "headings PDF rendered"
    assert_grid_aligned "heading+body" "$PRINT_DIR/output/001-headings-$(date +%Y-%m-%d).pdf"
  else
    fail "headings PDF not rendered"
  fi
}

# ─── Results ───

echo ""
echo "===================="
echo "Results: $PASS passed, $FAIL failed"
echo ""

[[ $FAIL -eq 0 ]]
