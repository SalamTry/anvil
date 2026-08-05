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

echo "[8-9] Flow block rendering"
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
step_count=$(grep -c '\\node\[anvilstepnum\]' "$TMPOUT" || true)
if [[ "$step_count" -eq 5 ]]; then
  pass "flow block has 5 steps"
else
  fail "flow block has $step_count steps (expected 5)"
fi

echo "[10-14] Table block rendering"
run_filter "$FIXTURES/table-block.md" ""
if grep -q 'tabularx' "$TMPOUT"; then
  pass "table block produces tabularx"
else
  fail "table block did not produce tabularx"
fi
if grep -q 'bfseries' "$TMPOUT"; then
  pass "table block header is bold"
else
  fail "table block header missing bold"
fi
if grep -q '|X|X|X|' "$TMPOUT"; then
  pass "table block has 3 columns"
else
  fail "table block column count wrong"
fi
if grep -q 'rowcolor{table-row-alt' "$TMPOUT"; then
  pass "table block has alternating row shading"
else
  fail "table block missing row shading"
fi
if grep -q 'rowcolor{table-header-bg' "$TMPOUT"; then
  pass "table block header has table-header-bg background"
else
  fail "table block header missing table-header-bg background"
fi

echo "[15] Standard markdown table: enhanced styling"
run_filter "$FIXTURES/table.md" ""
if grep -q 'rowcolor{table-header-bg' "$TMPOUT"; then
  pass "standard table header has table-header-bg background"
else
  fail "standard table header missing enhanced styling"
fi
if grep -q 'rowcolor{table-row-alt' "$TMPOUT"; then
  pass "standard table has alternating row shading"
else
  fail "standard table missing alternating row shading"
fi

echo "[16-20] Card block rendering"
run_filter "$FIXTURES/card.md" ""
if grep -q 'tikzpicture' "$TMPOUT"; then
  pass "card block produces tikzpicture"
else
  fail "card block did not produce tikzpicture"
fi
if grep -q 'card-bg' "$TMPOUT"; then
  pass "card block uses card-bg color"
else
  fail "card block missing card-bg color"
fi
if grep -q 'card-border' "$TMPOUT"; then
  pass "card block uses card-border color"
else
  fail "card block missing card-border color"
fi
if grep -q 'fill\[card-border\]' "$TMPOUT"; then
  pass "card block has left accent border"
else
  fail "card block missing left border"
fi
if grep -q 'textbf\|bfseries' "$TMPOUT"; then
  pass "card block renders bold content"
else
  fail "card block did not render bold content"
fi

echo ""
echo "======================="
echo "Results: $PASS passed, $FAIL failed"
echo ""

[[ $FAIL -eq 0 ]]
