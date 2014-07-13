num = numeric

limit = (v, maxSpeed) ->
  speed = num.norm2(v)
  if speed > maxSpeed
    return num.mul(maxSpeed / speed, v)
  else
    return v



maxSpeed = 8
maxForce = 0.2

viewRadius = 30

separationMultiplier = 1.6
alignmentMultiplier = 3
clickForceMultiplier = 0.2

class Boid
  constructor: ->
    @position = [Math.random()*1000, Math.random()*1000]
    @velocity = [0, 0]
    @acceleration = [0, 0]

  update: ->
    goal = num.sub(mousePosition, @position)

    separate = [0, 0]
    alignment = [0, 0]

    for boid in boids
      continue if boid == this
      continue if num.norm2(num.sub(boid.position, @position)) > viewRadius

      away = num.sub(@position, boid.position)
      separate = num.add(separate, away)

      alignment = num.add(alignment, boid.velocity)

    separate = num.mul(separationMultiplier, separate)
    alignment = num.mul(alignmentMultiplier, alignment)


    # click force
    clickForce = [0, 0]
    # if distanceFromClick < clickTime*4
    if clickTime >= 0
      clickForce = num.sub(@position, clickPosition)
      distanceFromClick = num.norm2(num.sub(clickPosition, @position))
      clickForce = num.mul(50/distanceFromClick, clickForce)

    clickForce = num.mul(clickForceMultiplier, clickForce)


    desired = num.add(num.add(goal, separate), alignment)


    # desired = limit(desired, maxSpeed)
    steer = num.sub(desired, @velocity)
    steer = limit(steer, maxForce)
    @acceleration = num.add(steer, clickForce)

    @velocity = num.add(@velocity, @acceleration)
    @velocity = limit(@velocity, maxSpeed)
    @position = num.add(@position, @velocity)
    # TODO

  display: ->
    unless @el
      @el = document.createElement("input")
      @el.setAttribute("type", "checkbox")
      document.body.appendChild(@el)

    x = @position[0] - 12
    y = @position[1] - 12

    @el.style.transform = "translate(#{x}px, #{y}px)"
    @el.style.MozTransform = "translate(#{x}px, #{y}px)"
    @el.style.webkitTransform = "translate(#{x}px, #{y}px)"


    # @el.style.left = x + "px"
    # @el.style.top  = y + "px"


boids = []

for i in [0...100]
  boids.push(new Boid())




clickPosition = [0, 0]
clickTime = -1





mousePosition = [0, 0]
document.addEventListener "mousemove", (e) ->
  mousePosition = [e.clientX, e.clientY]

document.addEventListener "mousedown", (e) ->
  e.preventDefault()
  clickPosition = mousePosition
  clickTime = 0

  for boid in boids
    distance = num.norm2(num.sub(mousePosition, boid.position))
    if distance < 50
      boid.el.checked = !boid.el.checked



animationLoop = ->
  requestAnimationFrame(animationLoop)

  if clickTime != -1
    clickTime += 1
  if clickTime > 20
    clickTime = -1

  for boid in boids
    boid.update()
    boid.display()

requestAnimationFrame(animationLoop)
