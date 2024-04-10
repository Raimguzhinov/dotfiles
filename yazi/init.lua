 function Header:render(area)
 	self.area = area
  		:constraints({ ui.Constraint.Percentage(50), ui.Constraint.Percentage(50) })
 		:split(area)
  	local right = ui.Line { self:tabs() }
 	return {
 		ui.Paragraph(chunks[1], { left }),
