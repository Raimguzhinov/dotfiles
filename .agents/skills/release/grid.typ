#let data = json(bytes(sys.inputs.data))

#let bg = rgb("#1e1e2e")
#let fg = rgb("#cdd6f4")
#let muted = rgb("#7f849c")
#let track = rgb("#313244")
#let added = rgb("#a6e3a1")
#let removed = rgb("#f38ba8")

#set page(width: 720pt, height: auto, margin: 32pt, fill: bg)
#set text(font: "Inter", size: 13pt, fill: fg)

#let area-width = 656pt
#let area-height = 360pt
#let count = data.apps.len()
#let fit(cols) = calc.min(area-width / cols, area-height / calc.ceil(count / cols))
#let cols = range(1, count + 1).fold(1, (best, c) => if fit(c) > fit(best) { c } else { best })
#let tile = calc.min(fit(cols), 112pt)
#let icon-size = tile * 0.5
#let label-size = calc.min(tile * 0.12, 11pt)

#let icon(app) = if app.icon == none {
  box(width: icon-size, height: icon-size, fill: track, radius: icon-size * 0.22, align(
    center + horizon,
    text(size: icon-size * 0.5, weight: "bold")[#upper(app.name.first())],
  ))
} else {
  image(app.icon, width: icon-size, height: icon-size, fit: "contain")
}

#let app-tile(app) = {
  let gone = app.state == "removed"
  let picture = if gone {
    box({
      icon(app)
      place(top + left, rect(width: icon-size, height: icon-size, fill: bg.transparentize(35%)))
    })
  } else { icon(app) }
  let label = text(size: label-size, fill: if gone { muted } else { fg })[#app.name]
  box(
    width: tile - 4pt,
    height: tile - 4pt,
    radius: tile * 0.12,
    fill: if app.state == "added" { added.transparentize(85%) },
    stroke: if app.state == "added" { 1.5pt + added } else if gone { (paint: removed, thickness: 1.5pt, dash: "dashed") },
    align(center + horizon, stack(
      spacing: tile * 0.06,
      picture,
      box(width: tile * 0.94, height: label-size * 2.5, clip: true, align(center + top, par(leading: 0.3em, if gone { strike(label) } else { label }))),
    )),
  )
}

#grid(
  columns: (1fr, auto),
  align: (left + bottom, right + bottom),
  text(size: 22pt, weight: "bold")[#data.host],
  text(fill: muted)[#data.count],
)
#v(16pt)
#box(width: area-width, height: area-height, align(center + horizon, grid(
  columns: (tile,) * cols,
  rows: tile,
  align: center + horizon,
  ..data.apps.map(app-tile),
)))

#if data.diff {
  v(12pt)
  set text(size: 11pt, fill: muted)
  stack(
    dir: ltr,
    spacing: 20pt,
    ..(
      (added.transparentize(85%), 1.5pt + added, "добавлено с прошлого релиза"),
      (none, (paint: removed, thickness: 1.5pt, dash: "dashed"), "удалено с прошлого релиза"),
    ).map(((fill, stroke, label)) => stack(
      dir: ltr,
      spacing: 6pt,
      box(baseline: 20%, width: 14pt, height: 14pt, radius: 3pt, fill: fill, stroke: stroke),
      label,
    )),
  )
}
