$ ->

  window.diagrams = $('.grid-diagram').map (e, el) ->
    new GridDiagram $(el), 30

class GridDiagram
  constructor: (element, size = 20) ->
    $el = $ element
    $el.html ""

    [width, height] = _.map $el.data("size").split(","), (n) -> parseInt(n)

    @grid = new Grid $el, width, height, size

    blocked = @expandList $el.data("blocked")

    points = []
    for y in [0...height]
      for x in [0...width]
        if _.indexOf(blocked, x + y * width) is -1
          points.push [x,y,'clear']
        else
          points.push [x,y,'blocked']

    start = if $el.data('start') then @pointFromOffset parseInt $el.data('start')
    dest = if $el.data('dest') then @pointFromOffset parseInt $el.data('dest')

    @map = new Map @grid, points, start, dest

    $el.show()
    @map.draw()

  pointFromOffset: (offset) =>
    [offset % @grid.width, Math.floor(offset / @grid.width)]

  expandList: (list) ->
    parts = _.map list.split(","), (part) ->
      [start, end] = part.split "-"
      if end
        x = _.range parseInt(start), parseInt(end) + 1
      else
        parseInt(start)
    _.flatten parts

class Grid
  constructor: (el, @width, @height, @size) ->
    @el = el.get 0 # need raw DOM node
    @container = d3.select @el
    @appendSVGElements()

  offset: (x, y) =>
    x + y * @width

  mapSelection: =>
   @container.select('.map').selectAll('rect')

  appendSVGElements: =>
    svg = @container.append 'svg:svg'
    svg.attr 'width', @width * @size
    svg.attr 'height', @height * @size

    translate = svg.append('svg:g')
      # push down by height
      .attr('transform', "translate(0,#{@height * @size})")

    # flip vertically
    translate.append('svg:g')
      .attr('transform', 'scale(1,-1)')
      .attr('class', 'map')

    # svg.append('svg:g')
    #   .attr('transform', 'translate(1,1)')
    #   .attr('class', 'node_vis')
    #   .attr('style', 'display:none')
    # svg.append('svg:g')
    #   .attr('transform', 'translate(1,1)')
    #   .attr('class', 'paths')
    #   .attr('style', 'display:none')

class Map
  constructor: (@grid, @points, start, dest) ->
    @updatePoint start, 'start' if start
    @updatePoint dest, 'dest' if dest

  blockNode: (x, y) ->
  clearNode: (x, y) ->

  updateOffset: (offset, type) =>

  updatePoint: (point, type) =>
    [x, y] = point
    offset = @grid.offset x, y
    @points[ offset ][2] = type

    @updateOffset offset, type

  draw: =>
    squares = @grid.mapSelection().data(@points, (d, i) -> [d[0], d[1]])

    squares.enter()
      .append('rect')
      .attr('x', (d, i) => @grid.size * d[0])
      .attr('y', (d, i) => @grid.size * d[1])
      .attr('width', @grid.size)
      .attr('height', @grid.size)
      # .on('mousedown', @mousedown)
      # .on('mouseover', @mouseover)

    squares.attr('class', (d, i) -> d[2])

# class Annotations

