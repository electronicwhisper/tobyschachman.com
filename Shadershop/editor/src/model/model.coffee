
class C.Variable
  constructor: (@valueString = "0") ->
    @valueString = @valueString.toString()
    @_lastValueString = null
    @_lastWorkingValue = null
    @getValue() # to initialize @_lastWorkingValue

  getValue: ->
    if @valueString == @_lastValueString
      return @_lastWorkingValue

    value = @_lastWorkingValue
    try
      if /^[-+]?[0-9]*\.?[0-9]+$/.test(@valueString)
        value = parseFloat(@valueString)
      else
        value = util.evaluate(@valueString)
    value = @_lastWorkingValue unless _.isFinite(value)

    @_lastWorkingValue = value
    @_lastValueString = @valueString
    return value

  duplicate: ->
    return new C.Variable(@valueString)



class C.Fn
  constructor: ->
  evaluate: (x) -> throw "Not implemented"


class C.BuiltInFn extends C.Fn
  constructor: (@fnName, @label) ->

  evaluate: (x) ->
    return builtIn.fnEvaluators[@fnName](x)

  duplicate: ->
    return this


class C.CompoundFn extends C.Fn
  constructor: ->
    @combiner = "sum"
    @childFns = []

  evaluate: (x) ->
    if @combiner == "last"
      if @childFns.length > 0
        return _.last(@childFns).evaluate(x)
      else
        return util.constructVector(config.dimensions, 0)

    if @combiner == "composition"
      for childFn in @childFns
        x = childFn.evaluate(x)
      return x

    if @combiner == "sum"
      reducer = (result, childFn) ->
        numeric.add(result, childFn.evaluate(x))
      return _.reduce(@childFns, reducer, util.constructVector(config.dimensions, 0))

    if @combiner == "product"
      reducer = (result, childFn) ->
        numeric.mul(result, childFn.evaluate(x))
      return _.reduce(@childFns, reducer, util.constructVector(config.dimensions, 1))

    if @combiner == "min"
      if @childFns.length == 0
        return util.constructVector(config.dimensions, 0)
      else
        values = _.map @childFns, (childFn) -> childFn.evaluate(x)
        return numeric.min(values...)

    if @combiner == "max"
      if @childFns.length == 0
        return util.constructVector(config.dimensions, 0)
      else
        values = _.map @childFns, (childFn) -> childFn.evaluate(x)
        return numeric.max(values...)

  duplicate: ->
    compoundFn = new C.CompoundFn()
    compoundFn.combiner = @combiner
    compoundFn.childFns = @childFns.map (childFn) -> childFn.duplicate()
    return compoundFn


class C.DefinedFn extends C.CompoundFn
  constructor: ->
    super()
    @combiner = "last"
    @plotLayout = new C.PlotLayout()

  duplicate: ->
    return this


class C.ChildFn extends C.Fn
  constructor: (@fn) ->
    @visible = true
    @domainTranslate = util.constructVector(config.dimensions, 0).map (v) ->
      new C.Variable(v)
    @domainTransform = numeric.identity(config.dimensions).map (row) ->
      row.map (v) ->
        new C.Variable(v)

    @rangeTranslate = util.constructVector(config.dimensions, 0).map (v) ->
      new C.Variable(v)
    @rangeTransform = numeric.identity(config.dimensions).map (row) ->
      row.map (v) ->
        new C.Variable(v)

  getDomainTranslate: ->
    @domainTranslate.map (v) -> v.getValue()

  getDomainTransform: ->
    @domainTransform.map (row) ->
      row.map (v) ->
        v.getValue()

  getRangeTranslate: ->
    @rangeTranslate.map (v) -> v.getValue()

  getRangeTransform: ->
    @rangeTransform.map (row) ->
      row.map (v) ->
        v.getValue()

  getBasisVector: (space, coord) ->
    matrix = (if space == "domain" then @domainTransform else @rangeTransform)
    vector = []
    for row in [0...config.dimensions]
      vector.push matrix[row][coord].getValue()
    return vector

  setBasisVector: (space, coord, valueStrings) ->
    matrix = (if space == "domain" then @domainTransform else @rangeTransform)
    for row in [0...config.dimensions]
      matrix[row][coord].valueString = valueStrings[row]

  evaluate: (x) ->
    domainTranslate    = @getDomainTranslate()
    domainTransformInv = util.safeInv(@getDomainTransform())
    rangeTranslate     = @getRangeTranslate()
    rangeTransform     = @getRangeTransform()

    x = numeric.dot(domainTransformInv, numeric.sub(x, domainTranslate))
    x = @fn.evaluate(x)
    x = numeric.add(numeric.dot(rangeTransform, x), rangeTranslate)
    return x

  duplicate: ->
    childFn = new C.ChildFn(@fn.duplicate())
    childFn.visible = @visible
    childFn.domainTranslate = @domainTranslate.map (variable) -> variable.duplicate()
    childFn.domainTransform = @domainTransform.map (row) ->
      row.map (variable) ->
        variable.duplicate()
    childFn.rangeTranslate = @rangeTranslate.map (variable) -> variable.duplicate()
    childFn.rangeTransform = @rangeTransform.map (row) ->
      row.map (variable) ->
        variable.duplicate()
    return childFn







class C.PlotLayout
  constructor: ->
    # TODO: All this hardcoded stuff needs to change...
    @plots = [new C.Plot(), new C.Plot(), new C.Plot()]
    @display2d = false

  getMainPlot: ->
    return @plots[0]

  getPlotLocations: ->
    # returns [{plot, x, y, w, h}] dimensions as fractions
    if @display2d
      return [
        {
          plot: @plots[0]
          x: 0
          y: 0.3
          w: 0.7
          h: 0.7
        }
        {
          plot: @plots[1]
          x: 0
          y: 0
          w: 0.7
          h: 0.3
        }
        {
          plot: @plots[2]
          x: 0.7
          y: 0.3
          w: 0.3
          h: 0.7
        }
      ]
    else
      return [
        {
          plot: @plots[0]
          x: 0
          y: 0
          w: 1
          h: 1
        }
      ]





class C.Plot
  constructor: ->
    # The center, in world coordinates, of the plot
    @center = util.constructVector(config.dimensions*2, 0)

    # This is the projection that's used for any coordinates not defined on
    # the plot.
    @focus = util.constructVector(config.dimensions*2, 0)

    @pixelSize = .01

    @type = "cartesian"


  # TODO: These are both old, should be removed.
  getDimensionsOld: ->
    if @type == "cartesian"
      return [
        {space: "domain", coord: 0}
        {space: "range",  coord: 0}
      ]
    else if @type == "cartesian2"
      return [
        {space: "range",  coord: 0}
        {space: "domain", coord: 1}
      ]
    else if @type == "colorMap"
      return [
        {space: "domain", coord: 0}
        {space: "domain", coord: 1}
      ]

  getScaledBounds: (width, height, scaleFactor) ->
    pixelSize = @pixelSize
    center = {
      domain: @center[ ... @center.length/2]
      range:  @center[@center.length/2 ... ]
    }
    dimensions = @getDimensionsOld()

    xPixelCenter = center[dimensions[0].space][dimensions[0].coord]
    yPixelCenter = center[dimensions[1].space][dimensions[1].coord]

    return {
      xMin: xPixelCenter - pixelSize * (width/2)  * scaleFactor
      xMax: xPixelCenter + pixelSize * (width/2)  * scaleFactor
      yMin: yPixelCenter - pixelSize * (height/2) * scaleFactor
      yMax: yPixelCenter + pixelSize * (height/2) * scaleFactor
    }



  getPixelSize: ->
    return @pixelSize

  getDimensions: ->
    if @type == "cartesian"
      return [
        [1,0,0,0 , 0,0,0,0]
        [0,0,0,0 , 1,0,0,0]
      ]
    else if @type == "cartesian2"
      return [
        [0,0,0,0 , 1,0,0,0]
        [0,1,0,0 , 0,0,0,0]
      ]
    else if @type == "colorMap"
      return [
        [1,0,0,0 , 0,0,0,0]
        [0,1,0,0 , 0,0,0,0]
      ]

  getMask: ->
    # Returns a vector mask in world coordinates where very world coordinate
    # that's represented in the plot is a 1 and 0 otherwise.
    dimensions = @getDimensions()
    mask = util.constructVector(config.dimensions*2, 0)
    for dimension in dimensions
      mask = numeric.add(dimension, mask)
    return mask

  getCombinedCenter: ->
    # This is the same as @center except any world coordinates which aren't
    # represented in the plot are replaced with @focus
    return util.vectorMask(@center, @focus, @getMask())

  # The Pixel frame ({x, y}) has 0,0 at the center of the canvas and y
  # positive going up.

  toWorld: ({x, y}) ->
    pixelSize = @getPixelSize()

    offset = numeric.dot(
      numeric.mul([x, y], pixelSize)
      @getDimensions()
    )

    return numeric.add(
      offset,
      @getCombinedCenter()
    )

  toPixel: (worldPoint) ->
    pixelSize = @getPixelSize()

    offset = numeric.sub(worldPoint, @getCombinedCenter())
    xyPoint = numeric.div(
      numeric.dot(
        @getDimensions()
        offset
      )
      pixelSize
    )

    return {x: xyPoint[0], y: xyPoint[1]}















class C.AppRoot
  constructor: ->
    @fns = [
      new C.DefinedFn()
    ]



window.builtIn = builtIn = {}

builtIn.fns = [
  new C.BuiltInFn("identity", "Line")
  new C.BuiltInFn("abs", "Abs")
  new C.BuiltInFn("fract", "Fract")
  new C.BuiltInFn("floor", "Floor")
  new C.BuiltInFn("sin", "Sine")
]

builtIn.fnEvaluators = {
  identity: (x) -> x
  abs: numeric.abs
  fract: (x) -> numeric.sub(x, numeric.floor(x))
  floor: numeric.floor
  sin: numeric.sin
}

builtIn.defaultPlotLayout = new C.PlotLayout()
