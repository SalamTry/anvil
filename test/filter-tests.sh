#!/bin/zsh
# Filter-seam tests for anvil-filter.lua
# Tests title extraction by running pandoc with the filter and checking LaTeX output.

set -euo pipefail

export PATH="/Library/TeX/texbin:$PATH"

PRINT_DIR="$HOME/anvil"
FILTER="$PRINT_DIR/anvil-filter.lua"
FIXTURES="$PRINT_DIR/test/fixtures"

PASS=0
FAIL=0
TMPOUT=$(mktemp)
trap "rm -f $TMPOUT" EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

run_filter() {
  pandoc -f markdown+hard_line_breaks --lua-filter="$FILTER" -t latex $2 "$1" 2>/dev/null > "$TMPOUT"
}

echo ""
echo "anvil filter-seam tests"
echo "======================="
echo ""

# --- Title extraction ---

echo "[1] First H1 extracted as title"
pandoc -f markdown+hard_line_breaks --lua-filter="$FILTER" -t latex --standalone "$FIXTURES/basic.md" 2>/dev/null > "$TMPOUT"
if grep -aq 'title{Basic Test Page}' "$TMPOUT"; then
  pandoc -f markdown+hard_line_breaks --lua-filter="$FILTER" -t latex "$FIXTURES/basic.md" 2>/dev/null > "$TMPOUT"
  if grep -aq 'section{Basic Test Page}' "$TMPOUT"; then
    fail "H1 still appears as section heading in body"
  else
    pass "first H1 extracted into metadata, not in body"
  fi
else
  fail "title not found in metadata"
fi

echo "[2] No H1 — fallback to source filename"
run_filter "$FIXTURES/no-h1.md" "-M source-file=no-h1.md"
if grep -q "no H1 heading" "$TMPOUT"; then
  pass "no-H1 file renders without crash"
else
  fail "no-H1 file body content missing"
fi

echo "[3] Multiple H1s — only first extracted"
run_filter "$FIXTURES/multi-h1.md" ""
if grep -q 'Second Title' "$TMPOUT"; then
  pass "second H1 remains in body"
else
  fail "second H1 missing from body"
fi

echo "[4] Blank line before H1 — still extracted"
run_filter "$FIXTURES/blank-before-h1.md" ""
if grep -q "Body text here" "$TMPOUT"; then
  if grep -aq 'section{Title After Blank Line}' "$TMPOUT"; then
    fail "H1 after blank line still in body as section"
  else
    pass "H1 after blank line extracted correctly"
  fi
else
  fail "body content missing after blank-line H1 extraction"
fi

echo "[5] H1 stripped from body — not duplicated"
run_filter "$FIXTURES/basic.md" ""
section_count=$(grep -ac 'section{Basic Test Page}' "$TMPOUT" || true)
if [[ "$section_count" -eq 0 ]]; then
  pass "H1 not duplicated in body"
else
  fail "H1 appears $section_count time(s) as section heading"
fi

echo "[6] Table rendering still works after filter rename"
run_filter "$FIXTURES/table.md" ""
if grep -q 'tabularx' "$TMPOUT"; then
  pass "tables still render via filter"
else
  fail "table rendering broken"
fi

echo "[7] Horizontal rule still works after filter rename"
run_filter "$FIXTURES/basic.md" ""
if grep -aq 'quad' "$TMPOUT"; then
  pass "horizontal rules still render"
else
  fail "horizontal rule rendering broken"
fi

echo "[8] Flow block renders as tikzpicture with numbered steps"
run_filter "$FIXTURES/flow.md" ""
if grep -q 'tikzpicture' "$TMPOUT"; then
  pass "flow block produces tikzpicture"
else
  fail "flow block did not produce tikzpicture"
fi
if grep -q 'anvilstepnum' "$TMPOUT"; then
  pass "flow block contains step number nodes"
else
  fail "flow block missing step number nodes"
fi
if grep -q 'draw.*accent' "$TMPOUT"; then
  pass "flow block contains accent-colored connectors"
else
  fail "flow block missing accent connectors"
fi

echo "[9] Flow block: correct step count"
run_filter "$FIXTURES/flow.md" ""
step_count=$(grep -c '\\node\[anvilstepnum\]' "$TMPOUT" || true)
if [[ "$step_count" -eq 5 ]]; then
  pass "flow block has 5 steps"
else
  fail "flow block has $step_count steps (expected 5)"
fi

echo "[10] Table block: fenced code renders as tabularx"
run_filter "$FIXTURES/table-block.md" ""
if grep -q 'tabularx' "$TMPOUT"; then
  pass "table block produces tabularx"
else
  fail "table block did not produce tabularx"
fi

echo "[11] Table block: header row has bold styling"
run_filter "$FIXTURES/table-block.md" ""
if grep -q 'bfseries' "$TMPOUT"; then
  pass "table block header is bold"
else
  fail "table block header missing bold"
fi

echo "[12] Table block: correct column count"
run_filter "$FIXTURES/table-block.md" ""
if grep -q '|X|X|X|' "$TMPOUT"; then
  pass "table block has 3 columns"
else
  fail "table block column count wrong"
fi

echo "[13] Table block: alternating row shading"
run_filter "$FIXTURES/table-block.md" ""
if grep -q 'rowcolor{gridline' "$TMPOUT"; then
  pass "table block has alternating row shading"
else
  fail "table block missing row shading"
fi

echo "[14] Table block: header row background"
run_filter "$FIXTURES/table-block.md" ""
if grep -q 'rowcolor{gridmajor' "$TMPOUT"; then
  pass "table block header has gridmajor background"
else
  fail "table block header missing gridmajor background"
fi

echo "[15] Standard markdown table: enhanced styling"
run_filter "$FIXTURES/table.md" ""
if grep -q 'rowcolor{gridmajor' "$TMPOUT"; then
  pass "standard table header has gridmajor background"
else
  fail "standard table header missing enhanced styling"
fi
if grep -q 'rowcolor{gridline' "$TMPOUT"; then
  pass "standard table has alternating row shading"
else
  fail "standard table missing alternating row shading"
fi

echo ""
echo "======================="
echo "Results: $PASS passed, $FAIL failed"
echo ""

[[ $FAIL -eq 0 ]]
