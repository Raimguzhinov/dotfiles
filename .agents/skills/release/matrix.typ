#let data = json(bytes(sys.inputs.data))

#let bg = rgb("#1e1e2e")
#let fg = rgb("#cdd6f4")
#let muted = rgb("#7f849c")
#let accent = rgb("#89b4fa")
#let track = rgb("#313244")
#let added = rgb("#a6e3a1")
#let removed = rgb("#f38ba8")

#set page(width: auto, height: auto, margin: 32pt, fill: bg)
#set text(font: "Inter", size: 13pt, fill: fg)

#let mark(state) = {
  let size = 12pt
  if state == "on" { circle(radius: size / 2, fill: accent) }
  else if state == "added" { circle(radius: size / 2, fill: added) }
  else if state == "removed" { circle(radius: size / 2 - 1pt, stroke: 2pt + removed) }
  else { circle(radius: size / 4, fill: track) }
}

#let row-area(i) = {
  let area = data.rows.at(i).area
  if i == 0 or data.rows.at(i - 1).area != area { text(fill: muted)[#area] }
}

#table(
  columns: (auto, auto, ..data.hosts.map(_ => auto)),
  align: (left + horizon, left + horizon, ..data.hosts.map(_ => center + horizon)),
  stroke: none,
  inset: (x: 14pt, y: 5pt),
  [], [], ..data.hosts.map(h => text(weight: "bold")[#h]),
  ..data
    .rows
    .enumerate()
    .map(((i, row)) => (
      row-area(i),
      text(font: "JetBrains Mono", size: 12pt)[#row.module],
      ..row.cells.map(mark),
    ))
    .flatten(),
)

#if data.diff {
  v(12pt)
  set text(size: 11pt, fill: muted)
  stack(
    dir: ltr,
    spacing: 20pt,
    ..(("added", "включён с прошлого релиза"), ("removed", "выключен с прошлого релиза")).map(((state, label)) => stack(
      dir: ltr,
      spacing: 6pt,
      box(baseline: 20%, mark(state)),
      label,
    )),
  )
}
