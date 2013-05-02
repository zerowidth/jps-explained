$ ->

  window.diagrams = $('.grid-diagram').map (e, el) ->
    new GridDiagram $(el), 24

    # fixme id only for single instance, or make it a loop over all elems
  window.interactive = new InteractiveGrid $('.interactive-container'), 24

class InteractiveGrid
  constructor: (element, size = 20) ->
    $el = $ element

    $grid = $el.find('.grid-interactive')
    $grid.html ""

    [width, height] = _.map $grid.data("size").split(","), (n) -> parseInt(n)

    points = []
    for y in [0...height]
      for x in [0...width]
        points.push [x,y,'clear']

    y = Math.floor height / 2
    start = [Math.floor(width / 5) - 1, y]
    goal = [Math.floor(width * 4 / 5) + 1, y]

    @grid = new Grid $el, width, height, size
    @map = new Map @grid, points, start, goal, true
    window.map = @map
    @annotations = new Annotations @grid
    @map.draw()

    $el.find('button.start').click =>
      $el.find('button.start').hide()
      $el.find('button.stop').show()
      $el.find('button.reset').hide()
      @anim = new AnimatedSearch @map, @annotations, 100
      @anim.run ->
        $el.find('button.stop').hide()
        $el.find('button.start').show()
        $el.find('button.reset').show()

    $el.find('button.stop').click =>
      $el.find('button.stop').hide()
      $el.find('button.start').show()
      $el.find('button.reset').show()
      @anim.finished = true if @anim

    $el.find('button.reset').click =>
      @annotations.reset()
      @map.edit = true

  update: (state) =>
    open = state.open
    closed = state.closed
    paths = []
    previous = []
    start = @map.start()
    goal = @map.goal()
    current = state.current
    @annotations.update open, closed, paths, previous, start, goal, current

class AnimatedSearch
  constructor: (@map, @annotations, @delay=200) ->
    @finished = false
    @path = new PathFinder @map

  run: (@callback) =>
    @map.edit = false
    @annotations.reset()
    setTimeout @tick, @delay

  tick: =>
    if @finished
      @callback() if @callback?
      return

    @finished = @path.step()
    state = @path.state()
    @annotations.update(
      state.open,
      state.closed,
      state.paths,
      state.previous,
      @map.start(),
      @map.goal(),
      state.current
    )

    setTimeout @tick, @delay

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
      open = _.map(@expandList($el.data('open')), @grid.fromOffset)

    closed = []
    if $el.data('closed')?
      closed = _.map(@expandList($el.data('closed')), @grid.fromOffset)

    forced = []
    if $el.data('forced')?
      forced = _.map(@expandList($el.data('forced')), @grid.fromOffset)

    start = if $el.data('start')? then @grid.fromOffset parseInt $el.data('start')
    goal = if $el.data('goal')? then @grid.fromOffset parseInt $el.data('goal')
    current = if $el.data('current')? then @grid.fromOffset parseInt $el.data('current')

    @map = new Map @grid, points, start, goal
    @annotations = new Annotations @grid

    $el.show()
    @map.draw()
    @annotations.update open, closed, paths, previous, start, goal, current,
      forced

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
      _.map pair.split("-"), _.compose(@grid.fromOffset, (s) -> parseInt s)

class Grid
  constructor: (el, @width, @height, @size) ->
    @el = el.get 0 # need raw DOM node
    @container = d3.select @el
    @appendSVGElements()

    @mapSelection = @container.select '.map'
    @annotationSelection = @container.select '.annotations'

  offset: (x, y) =>
    if x >= 0 and x < @width and y >= 0 and y < @height
      x + y * @width

  fromOffset: (offset) =>
    [offset % @width, Math.floor(offset / @width)]

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

  reachable: (from, to) =>
    [x1, y1] = from
    [x2, y2] = to
    dx = x2 - x1
    dy = y2 - y1

    @isClear(to) and (
      (dx is 0 or dy is 0) or
      (@isClear([x1, y2]) or @isClear([x2, y1]))
    )

  isClear: ([x, y]) =>
    offset = @grid.offset x, y
    if offset? # don't leave out 0!
      @points[offset][2] isnt 'blocked'

  start: =>
    for [x, y, kind] in @points
      return [x, y] if kind is 'start'

  goal: =>
    for [x, y, kind] in @points
      return [x, y] if kind is 'goal'

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
    @draw()

class Annotations
  constructor: (@grid) ->
    @defineArrowheads()

  update: (open, closed, paths, previous, @start, @goal, @current, forced) =>
    @open = open or []
    @closed = closed or []
    @paths = paths or []
    @previous = previous or []
    @forced = forced or []
    @draw()

  reset: =>
    @open = @closed = @paths = @previous = @forced = []
    @start = @goal = @current = null
    @draw()

  draw: =>
    @drawSquares()
    @drawPaths()

  drawPaths: =>
    data = []
    data.push [pair, 'current'] for pair in @paths
    data.push [pair, 'previous'] for pair in @previous

    paths = @grid.annotationSelection.selectAll("line")
      .data(data, (d, i) -> JSON.stringify d[0])

    paths.enter()
      .append('line')
      .attr('x1', (d, i) => @lineSegment(d)[0]) # TODO this is calculated 4x?
      .attr('y1', (d, i) => @lineSegment(d)[1])
      .attr('x2', (d, i) => @lineSegment(d)[2])
      .attr('y2', (d, i) => @lineSegment(d)[3])
    paths
      .attr('class', (d, i) -> d[1])
      .attr('marker-end', (d, i) -> "url(#arrowhead-#{d[1]})")
    paths.exit().remove()

  drawSquares: =>
    points = [] # first one wins if there's a duplicate
    points.push [@current[0], @current[1], 'current'] if @current
    points.push [@start[0], @start[1], 'start'] if @start
    points.push [@goal[0], @goal[1], 'goal'] if @goal
    points.push [x,y,'forced'] for [x, y] in @forced
    points.push [x,y,'open'] for [x, y] in @open
    points.push [x,y,'closed'] for [x, y] in @closed

    squares = @grid.annotationSelection.selectAll("rect")
      .data(points, (d, i) -> JSON.stringify [d[0],d[1]])
    squares.enter()
      .append('rect')
      .attr('x', (d, i) => @grid.size * d[0])
      .attr('y', (d, i) => @grid.size * d[1])
      .attr('width', @grid.size)
      .attr('height', @grid.size)
    squares.attr('class', (d, i) -> d[2])
    squares.exit().remove()

  # path goes from center of node to a little before the center of the next
  # returns [ x1, y1, x2, y2 ]
  lineSegment: (d) =>
    [ [x1, y1], [x2, y2] ] = d[0]
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

class ImmediateNeighbors
  constructor: (@map) ->

  # return immediate neighbors of [x, y] on the map
  successors: ([x,y]) =>
    ns = []
    for dx in [-1..1]
      for dy in [-1..1]
        continue if dx is 0 and dy is 0
        p = [x + dx, y + dy]
        if @map.reachable [x,y], p
          ns.push new Node p
    ns

  of: (pos) => @successors pos

class Node
  constructor: (@pos, @cost, @parent = null) ->
    @key = JSON.stringify @pos

  eq: (other) =>
    @key is other.key

class PathFinder
  constructor: (map, neighborStrategy=ImmediateNeighbors) ->
    @open = {}
    @closed = {}
    @path = null

    @successors = new neighborStrategy map
    start = map.start()
    @start = new Node map.start()
    @goal = new Node map.goal()

    @start.f = 0 # FIXME for A*
    @open[@start.key] = @start

  distance: (from, to) ->
    [x1, y1] = from.pos
    [x2, y2] = to.pos
    Math.sqrt( (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1) )

  # returns the current state for visualization
  state: =>
    nodes = _.flatten([_.values(@open), _.values(@closed)])
    withParents = _.select nodes, (e) -> e.parent?
    paths = _.map withParents, (e) -> [e.parent.pos, e.pos]

    finalPath = []
    if @path
      _.each @path, (e, i, l) =>
        if next = l[i+1]
          finalPath.push [e, next]

    {
      open: _.pluck _.values(@open), "pos"
      closed: _.pluck _.values(@closed), "pos"
      current: !@path and @current and @current.pos
      paths: finalPath
      previous: paths
    }

  # returns true if algorithm is complete
  step: =>
    return true if @path
    @current = node = _.first _.sortBy _.values(@open), (n) -> n.f
    return true unless node

    if node.eq @goal
      path = [@goal.pos]
      while node.parent?
        node = node.parent
        path.unshift node.pos
      @path = path
      return true

    delete @open[node.key]
    @closed[node.key] = node

    for neighbor in @successors.of node.pos
      newCost = node.f + @distance node, neighbor

      if existing = neighbor.key of @closed or existing = neighbor.key of @open
        continue if newCost >= existing.f
        existing.parent = node
        existing.f = newCost
      else
        neighbor.parent = node
        neighbor.f = newCost
        @open[neighbor.key] = neighbor

    null # not done yet
