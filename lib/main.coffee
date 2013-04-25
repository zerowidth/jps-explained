$ ->

  window.diagrams = $('.grid-diagram').map (e, el) ->
    new GridDiagram $(el), 24

  window.interactive = new InteractiveGrid $('#grid-interactive'), 24

class InteractiveGrid
  constructor: (element, size = 20) ->
    $el = $ element
    $el.html ""
    [width, height] = _.map $el.data("size").split(","), (n) -> parseInt(n)

    points = []
    for y in [0...height]
      for x in [0...width]
        points.push [x,y,'clear']

    y = Math.floor height / 2
    start = [Math.floor(width / 5) - 1, y]
    goal = [Math.floor(width * 4 / 5) + 1, y]

    @grid = new Grid $el, width, height, size
    @map = new Map @grid, points, start, goal, true
    @map.draw()

class GridDiagram
  constructor: (element, size = 20) ->
    $el = $ element
    $el.html ""

    [width, height] = _.map $el.data("size").split(","), (n) -> parseInt(n)

    @grid = new Grid $el, width, height, size

    blocked = @expandList $el.data 'blocked'

    points = []
    for y in [0...height]
      for x in [0...width]
        if _.indexOf(blocked, x + y * width) is -1
          points.push [x,y,'clear']
        else
          points.push [x,y,'blocked']

    paths = []
    if $el.data 'paths'
      paths = @pathsToPoints $el.data('paths')

    previous = []
    if $el.data 'previous'
      previous = @pathsToPoints $el.data('previous')

    open = []
    if $el.data('open')?
      open = _.map(@expandList($el.data('open')), @pointFromOffset)

    closed = []
    if $el.data('closed')?
      closed = _.map(@expandList($el.data('closed')), @pointFromOffset)

    forced = []
    if $el.data('forced')?
      forced = _.map(@expandList($el.data('forced')), @pointFromOffset)

    start = if $el.data('start')? then @pointFromOffset parseInt $el.data('start')
    goal = if $el.data('goal')? then @pointFromOffset parseInt $el.data('goal')
    current = if $el.data('current')? then @pointFromOffset parseInt $el.data('current')

    @map = new Map @grid, points, start, goal
    @annotations = new Annotations @grid, open, closed,
      paths, previous, start, goal, current, forced

    $el.show()
    @map.draw()
    @annotations.draw()

  pointFromOffset: (offset) =>
    [offset % @grid.width, Math.floor(offset / @grid.width)]

  expandList: (list) ->
    parts = _.map "#{list}".split(","), (part) ->
      [start, end] = part.split "-"
      if end
        x = _.range parseInt(start), parseInt(end) + 1
      else
        parseInt(start)
    _.flatten parts

  pathsToPoints: (list) =>
    _.map list.split(","), (pair) =>
      _.map pair.split("-"), _.compose(@pointFromOffset, (s) -> parseInt s)

class Grid
  constructor: (el, @width, @height, @size) ->
    @el = el.get 0 # need raw DOM node
    @container = d3.select @el
    @appendSVGElements()

    @mapSelection = @container.select '.map'
    @annotationSelection = @container.select '.annotations'

  offset: (x, y) =>
    x + y * @width

  appendSVGElements: =>
    # size is 2px bigger to leave room for outside lines on grid
    svg = @container.append 'svg:svg'
    svg.attr 'width', @width * @size + 2
    svg.attr 'height', @height * @size + 2

    translate = svg.append('svg:g')
      # push down by height plus 1px to leave room for lines
      .attr('transform', "translate(1,#{@height * @size + 1})")

    # flip vertically
    translate.append('svg:g')
      .attr('transform', 'scale(1,-1)')
      .attr('class', 'map')

    translate.append('svg:g')
      .attr('transform', 'scale(1,-1)')
      .attr('class', 'annotations')

class Map
  constructor: (@grid, @points, start, goal, interactive=false) ->

    @updatePoint start, 'start' if start
    @updatePoint goal, 'goal' if goal

    @edit = interactive
    @drag = null # what's being dragged, if anything

    $('body').mouseup @mouseup

  updatePoint: (point, type) =>
    [x, y] = point
    offset = @grid.offset x, y
    @points[ offset ][2] = type

  draw: =>
    squares = @grid.mapSelection.selectAll('rect')
      .data(@points, (d, i) -> [d[0], d[1]])

    squares.enter()
      .append('rect')
      .attr('x', (d, i) => @grid.size * d[0])
      .attr('y', (d, i) => @grid.size * d[1])
      .attr('width', @grid.size)
      .attr('height', @grid.size)
      .on('mousedown', @mousedown)
      .on('mouseover', @mouseover)

    squares.attr('class', (d, i) -> d[2])

  mousedown: (d, i) =>
    return unless @edit
    square = d3.select(d3.event.target)
    @drag = square.attr 'class'
    @mouseover d, i

  mouseup: =>
    return unless @edit
    switch @drag
      when 'start'
        start = @grid.mapSelection.selectAll('rect.start')
        @updateNode start, 'start'
      when 'goal'
        goal = @grid.mapSelection.selectAll('rect.goal')
        @updateNode goal, 'goal'
    @drag = null

  mouseover: (d, i) =>
    return unless @edit and @drag
    square = d3.select(d3.event.target)
    switch @drag
      when 'clear'
        if square.classed('clear')
          @updateNode square, 'blocked'
      when 'blocked'
        if square.classed('blocked')
          @updateNode square, 'clear'
      when 'start'
        if not square.classed('goal')
          before = @grid.mapSelection.selectAll('rect.start')
          before.classed('start', false)
          if before.attr('class') is ""
            @updateNode before, 'clear'
          square.classed('start', true)
      when 'goal'
        if not square.classed('start')
          before = @grid.mapSelection.selectAll('rect.goal')
          before.classed('goal', false)
          if before.attr('class') is ""
            @updateNode before, 'clear'
          square.classed('goal', true)

  updateNode: (selection, type) =>
    [x, y, _] = selection.datum()
    @updatePoint [x, y], type
    selection.attr 'class', type # skip the rendering step

class Annotations
  constructor: (@grid, open, closed, paths, previous, @start, @goal, @current, forced) ->
    @open = open or []
    @closed = closed or []
    @paths = paths or []
    @previous = previous or []
    @forced = forced or []
    @defineArrowheads()

  draw: =>
    @drawPaths @paths, 'current'
    @drawPaths @previous, 'previous'
    @drawSquares @closed, 'closed'
    @drawSquares @open, 'open'
    @drawSquares @forced, 'forced'
    @drawSquares _.compact([@current]), 'current'
    @drawSquares _.compact([@start]), 'start'
    @drawSquares _.compact([@goal]), 'goal'

  drawPaths: (pairs, kind) =>
    paths = @grid.annotationSelection.selectAll("line.#{kind}")
      .data(pairs, JSON.stringify)

    paths.enter()
      .append('line')
      .attr('x1', (d, i) => @lineSegment(d)[0]) # TODO this is calculated 4x?
      .attr('y1', (d, i) => @lineSegment(d)[1])
      .attr('x2', (d, i) => @lineSegment(d)[2])
      .attr('y2', (d, i) => @lineSegment(d)[3])
      .attr('class', kind)
      .attr('marker-end', "url(#arrowhead-#{kind})")

    paths.exit().remove()

  drawSquares: (points, kind) =>

    squares = @grid.mapSelection.selectAll("rect.#{kind}")
      .data(points, (d, i) -> [d[0], d[1]])

    squares.enter()
      .append('rect')
      .attr('x', (d, i) => @grid.size * d[0])
      .attr('y', (d, i) => @grid.size * d[1])
      .attr('width', @grid.size)
      .attr('height', @grid.size)
      .attr('class',kind)

    squares.exit().remove

  # path goes from center of node to a little before the center of the next
  # returns [ x1, y1, x2, y2 ]
  lineSegment: (d) =>
    [ [x1, y1], [x2, y2] ] = d
    dx = x2 - x1
    dy = y2 - y1
    a = Math.sqrt((dx * dx) + (dy * dy))
    x1 += 0.2 * if a is 0 then 0 else dx/a
    y1 += 0.2 * if a is 0 then 0 else dy/a
    x2 -= 0.2 * if a is 0 then 0 else dx/a
    y2 -= 0.2 * if a is 0 then 0 else dy/a

    [ x1 * @grid.size + @grid.size / 2,
      y1 * @grid.size + @grid.size / 2,
      x2 * @grid.size + @grid.size / 2,
      y2 * @grid.size + @grid.size / 2 ]

  defineArrowheads: =>
    defs = @grid.annotationSelection.append('svg:defs')
    @defineArrowhead defs, 'current'
    @defineArrowhead defs, 'previous'

  defineArrowhead: (defs, kind) =>
    defs
      .append('marker')
      .attr('id', "arrowhead-#{kind}") # TODO is this ok?
      .attr('orient', 'auto')
      .attr('viewBox', '0 0 10 10')
      .attr('refX', 6)
      .attr('refY', 5)
      .append('polyline')
      .attr('points', '0,0 10,5 0,10 1,5')

