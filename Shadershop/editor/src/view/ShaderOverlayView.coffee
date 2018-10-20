Glod = require("./plot/glod")


R.create "ShaderOverlayView",

  initializeGlod: ->
    @glod = new Glod()
    canvas = @getDOMNode()
    @glod.canvas(canvas, {antialias: true})

    gl = @glod.gl()
    gl.enable(gl.SCISSOR_TEST)
    gl.lineWidth(1.25)

    bufferQuad(@glod)
    bufferCartesianSamples(@glod, 20000)

    @programs = {}

  sizeCanvas: ->
    canvas = @getDOMNode()
    rect = canvas.getBoundingClientRect()
    devicePixelRatio = window.devicePixelRatio || 1 # Scale canvas for HiDPI displays
    if canvas.width != rect.width or canvas.height != rect.height
      canvas.width = rect.width * devicePixelRatio
      canvas.height = rect.height * devicePixelRatio

  draw: ->
    canvas = @getDOMNode()

    usedPrograms = {}

    shaderEls = document.querySelectorAll(".Shader")
    for shaderEl in shaderEls
      continue unless shaderEl.isOnScreen()

      rect = shaderEl.getBoundingClientRect()
      clippingRect = shaderEl.getClippingRect()

      continue if clippingRect.height <= 0 or clippingRect.width <= 0

      setViewport(@glod, rect, clippingRect)

      shaderView = shaderEl.dataFor
      fns = shaderView.fns
      plot = shaderView.plot

      if shaderView.isThumbnail
        scaleFactor = window.innerHeight / rect.height # kinda hacky?
      else
        scaleFactor = 1

      for fnHolder in fns
        glsl = Compiler.getGlsl(fnHolder.fn)
        name = plot.type + "," + glsl
        unless @programs[name]

          if plot.type == "cartesian" or plot.type == "cartesian2"
            createCartesianProgram(@glod, name, glsl)
          else if plot.type == "colorMap"
            createColorMapProgram(@glod, name, glsl)

          @programs[name] = true
        usedPrograms[name] = true

        if plot.type == "cartesian" or plot.type == "cartesian2"
          drawCartesianProgram(@glod, name, fnHolder.color, plot, rect.width, rect.height, scaleFactor)
        else if plot.type == "colorMap"
          bounds = plot.getScaledBounds(rect.width, rect.height, scaleFactor)
          drawColorMapProgram(@glod, name, bounds)

    # Delete unused programs
    for own name, junk of @programs
      unless usedPrograms[name]
        delete @glod._programs[name]
        delete @programs[name]

  getAdditionalCode: ->
    additionalCode = ""
    vecType = util.glslVectorType(config.dimensions)
    for own id, exprString of Compiler.getAllDefinedFnExprStrings()
      additionalCode += "#{vecType} #{id}(#{vecType} inputVal) {return #{exprString};}\n"
    return additionalCode



  # ===========================================================================
  # Lifecycle
  # ===========================================================================

  handleResize: ->
    @sizeCanvas()
    @draw()

  componentDidMount: ->
    @initializeGlod()
    @sizeCanvas()
    window.addEventListener("resize", @handleResize)

  componentWillUnmount: ->
    window.removeEventListener("resize", @handleResize)

  # ===========================================================================
  # Render
  # ===========================================================================

  render: ->
    R.canvas {className: "ShaderOverlay"}






# =============================================================================
# Glod
# =============================================================================

# =============================================================================
# Utility
# =============================================================================

createProgramFromSrc = (glod, name, vertex, fragment) ->
  Glod.preprocessed[name] = {name, fragment, vertex}

  delete glod._programs[name]
  glod.createProgram(name)

setViewport = (glod, rect, clippingRect) ->
  gl = glod.gl()
  canvas = glod.canvas()

  # Scale everything by devicePixelRatio for HiDPI displays
  x = rect.left * devicePixelRatio
  y = canvas.height - rect.bottom * devicePixelRatio
  w = rect.width * devicePixelRatio
  h = rect.height * devicePixelRatio

  sx = clippingRect.left * devicePixelRatio
  sy = canvas.height - clippingRect.bottom * devicePixelRatio
  sw = clippingRect.width * devicePixelRatio
  sh = clippingRect.height * devicePixelRatio

  gl.viewport(x, y, w, h)
  gl.scissor(sx, sy, sw, sh)

  glod.viewport_ = {x, y, w, h}



# =============================================================================
# VBOs
# =============================================================================

bufferQuad = (glod) ->
  glod
    .createVBO("quad")
    .uploadCCWQuad("quad")

bufferCartesianSamples = (glod, numSamples) ->
  samplesArray = []
  for i in [0..numSamples]
    samplesArray.push(i)

  if glod.hasVBO("samples")
    glod.deleteVBO("samples")

  glod
    .createVBO("samples")
    .bufferDataStatic("samples", new Float32Array(samplesArray))


# =============================================================================
# Shader Programs
# =============================================================================

createCartesianProgram = (glod, name, glsl) ->

  vecType = util.glslVectorType(config.dimensions)
  matType = util.glslMatrixType(config.dimensions)

  vertex = """
  precision highp float;
  precision highp int;

  attribute float sample;

  uniform #{vecType} domainStart, domainStep;

  uniform #{vecType} domainCenter, rangeCenter;
  uniform #{matType} domainTransform, rangeTransform;

  uniform #{vecType} selectedDomainTranslate, selectedRangeTranslate;
  uniform #{matType} selectedDomainTransformInv, selectedRangeTransform;

  uniform vec2 pixelScale;

  #{glsl}

  void main() {
    #{vecType} inputVal, outputVal;
    inputVal = domainStart + domainStep * sample;
    outputVal = mainFn(inputVal);

    #{vecType} position = domainTransform * (inputVal - domainCenter) +
                          rangeTransform * (outputVal - rangeCenter);

    gl_Position = vec4(vec2(position.x, position.y) * pixelScale, 0., 1.);
  }
  """

  fragment = """
  precision highp float;
  precision highp int;

  uniform vec4 color;

  void main() {
    gl_FragColor = color;
  }
  """

  createProgramFromSrc(glod, name, vertex, fragment)

drawCartesianProgram = (glod, name, color, plot, width, height, scaleFactor) ->
  dimensions = plot.getDimensions()
  pixelSize  = plot.getPixelSize()

  width *= scaleFactor
  height *= scaleFactor

  # Determine domainStart, domainStep, numSamples. Note: this probably needs
  # to be generalized with more information in plot, e.g. for parametric
  # cartesian plot.
  isHorizontal = (dimensions[0][0] == 1 or dimensions[1][0] == 1)
  if isHorizontal
    domainStart = plot.toWorld({x: -width/2, y: 0})[ ... config.dimensions]
    domainEnd   = plot.toWorld({x:  width/2, y: 0})[ ... config.dimensions]
    numSamples  = (width / scaleFactor) / config.resolution
  else
    domainStart = plot.toWorld({x: 0, y: -height/2})[ ... config.dimensions]
    domainEnd   = plot.toWorld({x: 0, y:  height/2})[ ... config.dimensions]
    numSamples  = (height / scaleFactor) / config.resolution

  domainStep = numeric.div(
    numeric.sub(domainEnd, domainStart)
    numSamples
  )

  # Determine domainCenter, rangeCenter
  domainCenter = plot.center[ ... config.dimensions]
  rangeCenter  = plot.center[config.dimensions ... ]

  # Determine domainTransform, rangeTransform
  domainTransformSmall = numeric.getBlock(dimensions, [0,0], [1,config.dimensions - 1])
  rangeTransformSmall  = numeric.getBlock(dimensions, [0,config.dimensions], [1,config.dimensions*2 - 1])

  domainTransform = numeric.identity(config.dimensions)
  rangeTransform  = numeric.identity(config.dimensions)
  numeric.setBlock(domainTransform, [0,0], [1,config.dimensions - 1], domainTransformSmall)
  numeric.setBlock(rangeTransform,  [0,0], [1,config.dimensions - 1], rangeTransformSmall)

  # Determine pixelScale
  pixelScale = [
    (1 / pixelSize) * (1 / (width / 2))
    (1 / pixelSize) * (1 / (height / 2))
  ]

  glod.begin(name)

  glod.pack("samples", "sample")

  glod.valuev("color", color)

  glod.valuev("domainStart", domainStart)
  glod.valuev("domainStep", domainStep)
  glod.valuev("domainCenter", domainCenter)
  glod.valuev("rangeCenter", rangeCenter)
  glod.valuev("domainTransform", util.glslMatrixArray(domainTransform))
  glod.valuev("rangeTransform", util.glslMatrixArray(rangeTransform))
  glod.valuev("pixelScale", pixelScale)
  addSelectedChildFnUniforms(glod)

  glod.ready().lineStrip().drawArrays(0, numSamples)

  glod.end()



createColorMapProgram = (glod, name, glsl) ->

  vecType = util.glslVectorType(config.dimensions)
  matType = util.glslMatrixType(config.dimensions)

  vertex = """
  precision highp float;
  precision highp int;

  attribute vec4 position;
  varying vec2 vPosition;

  void main() {
    vPosition = position.xy;
    gl_Position = position;
  }
  """

  # TODO: Needs proper support for config.dimensions
  fragment = """
  precision highp float;
  precision highp int;

  uniform float xMin, xMax, yMin, yMax;

  uniform #{vecType} selectedDomainTranslate, selectedRangeTranslate;
  uniform #{matType} selectedDomainTransformInv, selectedRangeTransform;

  varying vec2 vPosition;

  #{glsl}

  float lerp(float x, float dMin, float dMax, float rMin, float rMax) {
    float ratio = (x - dMin) / (dMax - dMin);
    return ratio * (rMax - rMin) + rMin;
  }

  void main() {
    vec4 inputVal = vec4(
      lerp(vPosition.x, -1., 1., xMin, xMax),
      lerp(vPosition.y, -1., 1., yMin, yMax),
      0.,
      0.
    );
    vec4 outputVal = mainFn(inputVal);

    float value = outputVal.x;
    vec3 color;

    float normvalue = clamp(abs(value), 0., 1.);
    if (value > 0.) {
      color = mix(vec3(#{config.colorMapZero}), vec3(#{config.colorMapPositive}), normvalue);
    } else {
      color = mix(vec3(#{config.colorMapZero}), vec3(#{config.colorMapNegative}), normvalue);
    }

    //color = vec3(value, value, value);

    gl_FragColor = vec4(color, 1.);
  }
  """

  createProgramFromSrc(glod, name, vertex, fragment)

drawColorMapProgram = (glod, name, bounds) ->
  canvas = glod.canvas()

  glod.begin(name)

  glod.pack("quad", "position")

  glod.value("xMin", bounds.xMin)
  glod.value("xMax", bounds.xMax)
  glod.value("yMin", bounds.yMin)
  glod.value("yMax", bounds.yMax)
  addSelectedChildFnUniforms(glod)

  glod.ready().triangles().drawArrays(0, 6)

  glod.end()



addSelectedChildFnUniforms = (glod) ->
  selectedChildFn = UI.getSingleSelectedChildFn()
  return unless selectedChildFn
  domainTranslate = selectedChildFn.getDomainTranslate()
  domainTransformInv = packMatrix util.safeInv(selectedChildFn.getDomainTransform())
  rangeTranslate  = selectedChildFn.getRangeTranslate()
  rangeTransform  = packMatrix selectedChildFn.getRangeTransform()

  glod.valuev("selectedDomainTranslate", domainTranslate)
  glod.valuev("selectedDomainTransformInv", domainTransformInv)
  glod.valuev("selectedRangeTranslate", rangeTranslate)
  glod.valuev("selectedRangeTransform", rangeTransform)

packMatrix = (m) ->
  m = numeric.transpose(m)
  _.flatten(m)



