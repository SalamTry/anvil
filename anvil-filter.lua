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

-- Convert horizontal rules to dot separators
function HorizontalRule()
  return pandoc.RawBlock("latex",
    "\\vspace{0.2em}{\\color{gridline}\\centering\\small . \\quad . \\quad . \\quad . \\quad . \\quad . \\quad . \\quad .\\par}\\vspace{0.2em}")
end
