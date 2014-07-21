bigDistance = 3000
gridDistance = 100

n = numeric


mousePosition = [0, 0]
document.addEventListener "mousemove", (e) ->
  mousePosition = [e.clientX, e.clientY]



animationLoop = ->
  requestAnimationFrame(animationLoop)
  resizeCanvas()
  draw()

requestAnimationFrame(animationLoop)




resizeCanvas = ->
  canvasEl = document.getElementById("c")
  rect = canvasEl.getBoundingClientRect()
  canvasEl.width = rect.width
  canvasEl.height = rect.height


draw = ->
  canvasEl = document.getElementById("c")
  ctx = canvasEl.getContext("2d")

  rect = canvasEl.getBoundingClientRect()
  center = [rect.width/2, rect.height/2]

  ctx.strokeStyle = "#ccc"
  drawPolar(ctx, center, [1, 0])

  ctx.strokeStyle = "#7ca"
  drawCartesian(ctx, mousePosition, n.sub(mousePosition, center))



  # ctx.beginPath()
  # ctx.moveTo(0, 0)
  # ctx.lineTo(mousePosition...)
  # ctx.strokeStyle = "#bbb"
  # ctx.stroke()




drawPolar = (ctx, center, axisVector) ->
  ctx.save()
  ctx.translate(center...)
  ctx.rotate(Math.atan2(axisVector[1], axisVector[0]))

  spokes = 24

  for i in [0...spokes]
    ctx.save()
    ctx.rotate(2*Math.PI * i / spokes)

    ctx.beginPath()
    ctx.moveTo(0, 0)
    ctx.lineTo(bigDistance, 0)
    ctx.globalAlpha = if i == 0 then 1 else 0.2
    ctx.stroke()

    ctx.restore()

  for i in [0...bigDistance/gridDistance]
    distance = gridDistance * i
    ctx.beginPath()
    ctx.arc(0, 0, distance, 0, 2*Math.PI, false)
    ctx.globalAlpha = 0.2
    ctx.stroke()

  ctx.restore()


drawCartesian = (ctx, center, axisVector) ->
  ctx.save()
  ctx.translate(center...)
  ctx.rotate(Math.atan2(axisVector[1], axisVector[0]))

  drawGridLine = (start, end, strong) ->
    ctx.beginPath()
    ctx.moveTo(start...)
    ctx.lineTo(end...)
    ctx.globalAlpha = if strong then 1 else 0.2
    ctx.stroke()

  for i in [-bigDistance / gridDistance ... bigDistance / gridDistance]
    x = i * gridDistance
    start = [x, -bigDistance]
    end   = [x,  bigDistance]
    drawGridLine(start, end, x == 0)
  for i in [-bigDistance / gridDistance ... bigDistance / gridDistance]
    y = i * gridDistance
    start = [-bigDistance, y]
    end   = [ bigDistance, y]
    drawGridLine(start, end, y == 0)

  ctx.restore()




