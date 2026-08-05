function Pandoc(doc)
  for i, block in ipairs(doc.blocks) do
    if block.t == "Header" and block.level == 1 then
      doc.meta.title = block.content
      table.remove(doc.blocks, i)
      return doc
    end
  end
  if not doc.meta.title and doc.meta["source-file"] then
    local name = pandoc.utils.stringify(doc.meta["source-file"])
    doc.meta.title = {pandoc.Str(name:gsub("%.md$", ""))}
  end
  return doc
end

local function cell_to_latex(contents)
  if #contents == 0 then return "" end
  local latex = pandoc.write(pandoc.Pandoc(contents), "latex")
  return latex:gsub("%s+$", "")
end

-- Convert pandoc tables to full-width gridded LaTeX tabularx with enhanced styling
function Table(el)
  local ncols = #el.colspecs
  local colspec = "|"
  for i = 1, ncols do
    colspec = colspec .. "X|"
  end

  local lines = {}
  table.insert(lines, "\\noindent\\begin{tabularx}{\\textwidth}{" .. colspec .. "}")
  table.insert(lines, "\\hline")

  -- Header row — gridmajor background
  if el.head and el.head.rows and #el.head.rows > 0 then
    for _, row in ipairs(el.head.rows) do
      table.insert(lines, "\\rowcolor{gridmajor!20}")
      local cells = {}
      for _, cell in ipairs(row.cells) do
        local content = cell_to_latex(cell.contents)
        if content ~= "" then
          table.insert(cells, "{\\bfseries\\small " .. content .. "}")
        else
          table.insert(cells, "")
        end
      end
      table.insert(lines, table.concat(cells, " & ") .. " \\\\")
      table.insert(lines, "\\hline")
    end
  end

  -- Body rows — alternating shading
  local row_idx = 0
  for _, body in ipairs(el.bodies) do
    for _, row in ipairs(body.body) do
      if row_idx % 2 == 1 then
        table.insert(lines, "\\rowcolor{gridline!10}")
      end
      local cells = {}
      for _, cell in ipairs(row.cells) do
        local content = cell_to_latex(cell.contents)
        table.insert(cells, "{\\small " .. content .. "}")
      end
      table.insert(lines, table.concat(cells, " & ") .. " \\\\")
      table.insert(lines, "\\hline")
      row_idx = row_idx + 1
    end
  end

  table.insert(lines, "\\end{tabularx}")
  table.insert(lines, "\\vspace{\\gridunit}")

  return pandoc.RawBlock("latex", table.concat(lines, "\n"))
end

-- Escape LaTeX special characters in plain text
local function escape_latex(s)
  s = s:gsub("\\", "\\textbackslash{}")
  s = s:gsub("([&%%$#_{}])", "\\%1")
  s = s:gsub("~", "\\textasciitilde{}")
  s = s:gsub("%^", "\\textasciicircum{}")
  return s
end

-- Render ```flow fenced blocks as numbered steps with visual connectors
local function render_flow(el)
  local steps = {}
  for line in el.text:gmatch("[^\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      table.insert(steps, trimmed)
    end
  end

  if #steps == 0 then return nil end

  local step_sep = 12  -- mm between step centers — generous spacing
  local circle_r = 3   -- mm from center to connector start/end

  local lines = {}
  table.insert(lines, "\\par\\noindent")
  table.insert(lines, "\\begin{tikzpicture}[")
  table.insert(lines, "  anvilstepnum/.style={circle, fill=accent, text=white, font=\\footnotesize\\bfseries, inner sep=0pt, minimum size=1.6em},")
  table.insert(lines, "  anvilsteptxt/.style={anchor=north west, text width=\\linewidth-2.5em, font=\\small\\color{body}},")
  table.insert(lines, "]")

  for i, step in ipairs(steps) do
    local y = -(i - 1) * step_sep
    -- Step number circle
    table.insert(lines, string.format(
      "\\node[anvilstepnum] (n%d) at (0, %dmm) {%d};",
      i, y, i
    ))
    -- Step text
    table.insert(lines, string.format(
      "\\node[anvilsteptxt] at (1.4em, %dmm + 0.5ex) {%s};",
      y, escape_latex(step)
    ))
    -- Connector line to next step
    if i < #steps then
      local line_top = y - circle_r
      local line_bottom = y - step_sep + circle_r
      table.insert(lines, string.format(
        "\\draw[accent, line width=0.6pt] (0, %dmm) -- (0, %dmm);",
        line_top, line_bottom
      ))
    end
  end

  table.insert(lines, "\\end{tikzpicture}")
  table.insert(lines, "\\par\\vspace{\\gridunit}")

  return pandoc.RawBlock("latex", table.concat(lines, "\n"))
end

-- Render ```table fenced blocks as styled tables
local function render_table(el)
  local rows = {}
  for line in el.text:gmatch("[^\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      local cells = {}
      for cell in (trimmed .. "|"):gmatch("(.-)%s*|%s*") do
        table.insert(cells, cell:match("^%s*(.-)%s*$"))
      end
      table.insert(rows, cells)
    end
  end

  if #rows == 0 then return nil end

  local ncols = #rows[1]
  local colspec = "|"
  for i = 1, ncols do
    colspec = colspec .. "X|"
  end

  local lines = {}
  table.insert(lines, "\\noindent\\begin{tabularx}{\\textwidth}{" .. colspec .. "}")
  table.insert(lines, "\\hline")

  -- First row is header — gridmajor background
  table.insert(lines, "\\rowcolor{gridmajor!20}")
  local header_cells = {}
  for _, cell in ipairs(rows[1]) do
    if cell ~= "" then
      table.insert(header_cells, "{\\bfseries\\small " .. escape_latex(cell) .. "}")
    else
      table.insert(header_cells, "")
    end
  end
  table.insert(lines, table.concat(header_cells, " & ") .. " \\\\")
  table.insert(lines, "\\hline")

  -- Body rows — alternating shading
  for i = 2, #rows do
    if (i - 2) % 2 == 1 then
      table.insert(lines, "\\rowcolor{gridline!10}")
    end
    local body_cells = {}
    for _, cell in ipairs(rows[i]) do
      table.insert(body_cells, "{\\small " .. escape_latex(cell) .. "}")
    end
    table.insert(lines, table.concat(body_cells, " & ") .. " \\\\")
    table.insert(lines, "\\hline")
  end

  table.insert(lines, "\\end{tabularx}")
  table.insert(lines, "\\vspace{\\gridunit}")

  return pandoc.RawBlock("latex", table.concat(lines, "\n"))
end

-- Render d2 code fences as sketch-style diagrams
function CodeBlock(el)
  if el.classes:includes("table") then
    return render_table(el)
  end

  if el.classes:includes("flow") then
    return render_flow(el)
  end

  if not el.classes:includes("d2") then return nil end

  local d2_bin = os.getenv("ANVIL_D2_BIN") or "d2"
  local rsvg_bin = os.getenv("ANVIL_RSVG_BIN") or "rsvg-convert"

  local tmpdir = os.tmpname()
  os.remove(tmpdir)
  os.execute("mkdir -p " .. tmpdir)
  local d2_file = tmpdir .. "/diagram.d2"
  local svg_file = tmpdir .. "/diagram.svg"
  local pdf_file = tmpdir .. "/diagram.pdf"

  local f = io.open(d2_file, "w")
  f:write(el.text)
  f:close()

  local d2_ok = os.execute(d2_bin .. " --sketch --pad 20 " .. d2_file .. " " .. svg_file .. " 2>/dev/null")
  if d2_ok ~= 0 and d2_ok ~= true then
    local check = os.execute("command -v " .. d2_bin .. " >/dev/null 2>&1")
    if check ~= 0 and check ~= true then
      io.stderr:write("anvil: d2 not found — install with: brew install d2\n")
    else
      io.stderr:write("anvil: d2 failed to render diagram\n")
    end
    os.execute("rm -rf " .. tmpdir)
    return pandoc.RawBlock("latex",
      "{\\small\\color{muted}[diagram: d2 rendering failed]}")
  end

  local rsvg_ok = os.execute(rsvg_bin .. " -f pdf " .. svg_file .. " -o " .. pdf_file .. " 2>/dev/null")
  if rsvg_ok ~= 0 and rsvg_ok ~= true then
    io.stderr:write("anvil: rsvg-convert not found — install with: brew install librsvg\n")
    os.execute("rm -rf " .. tmpdir)
    return pandoc.RawBlock("latex",
      "{\\small\\color{muted}[diagram: rsvg-convert not found]}")
  end

  local latex = "\\noindent\\includegraphics[width=\\linewidth,height=0.45\\textheight,keepaspectratio]{"
    .. pdf_file .. "}\\par\\vspace{\\gridunit}"

  return pandoc.RawBlock("latex", latex)
end

-- Convert horizontal rules to dot separators
function HorizontalRule()
  return pandoc.RawBlock("latex",
    "\\vspace{0.2em}{\\color{gridline}\\centering\\small . \\quad . \\quad . \\quad . \\quad . \\quad . \\quad . \\quad .\\par}\\vspace{0.2em}")
end
