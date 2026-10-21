#let data = json(bytes(sys.inputs.data))

#let bg = rgb("#1e1e2e")
#let fg = rgb("#cdd6f4")
#let muted = rgb("#7f849c")
#let accent = rgb("#89b4fa")
#let track = rgb("#313244")

#set page(width: 720pt, height: auto, margin: 32pt, fill: bg)
#set text(font: "Inter", size: 13pt, fill: fg)

#grid(
  columns: (1fr, auto),
  align: (left + bottom, right + bottom),
  text(size: 40pt, weight: "bold")[#data.version],
  text(fill: muted)[#data.date · #data.base],
)
#v(4pt)
#text(font: "JetBrains Mono", size: 11pt, fill: muted)[#data.range]
#v(20pt)
#text(size: 22pt, weight: "bold")[#data.commits] #text(fill: muted)[commits]
#v(12pt)

#let top = calc.max(1, ..data.areas.map(a => a.at(1)))
#grid(
  columns: (80pt, 1fr, 40pt),
  row-gutter: 8pt,
  column-gutter: 12pt,
  align: (left + horizon, left + horizon, right + horizon),
  ..data
    .areas
    .map(((name, count)) => (
      text(fill: if count > 0 { fg } else { muted })[#name],
      box(width: 100%, height: 10pt, fill: track, radius: 5pt, if count > 0 {
        box(width: 100% * count / top, height: 10pt, fill: accent, radius: 5pt)
      }),
      text(fill: if count > 0 { fg } else { muted })[#count],
    ))
    .flatten(),
)
