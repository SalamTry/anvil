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

-- Convert pandoc tables to full-width gridded LaTeX tabularx
function Table(el)
  local ncols = #el.colspecs
  local colspec = "|"
  for i = 1, ncols do
    colspec = colspec .. "X|"
  end

  local lines = {}
  table.insert(lines, "\\noindent\\begin{tabularx}{\\textwidth}{" .. colspec .. "}")
  table.insert(lines, "\\hline")

  -- Header row
  if el.head and el.head.rows and #el.head.rows > 0 then
    for _, row in ipairs(el.head.rows) do
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

  -- Body rows
  for _, body in ipairs(el.bodies) do
    for _, row in ipairs(body.body) do
      local cells = {}
      for _, cell in ipairs(row.cells) do
        local content = cell_to_latex(cell.contents)
        table.insert(cells, "{\\small " .. content .. "}")
      end
      table.insert(lines, table.concat(cells, " & ") .. " \\\\")
      table.insert(lines, "\\hline")
    end
  end

  table.insert(lines, "\\end{tabularx}")
  table.insert(lines, "\\vspace{\\gridunit}")

  return pandoc.RawBlock("latex", table.concat(lines, "\n"))
end

-- Render d2 code fences as sketch-style diagrams
function CodeBlock(el)
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
