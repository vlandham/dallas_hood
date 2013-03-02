
root = exports ? this

# TODO: most of this really shouldn't have to wait till the page
# is loaded to execute.
# Pull out
$ ->

  # ---
  # These are constants we would like availible anywhere in the visualization
  # ---
  width = 340
  height = 175
  key_h = 20
  key_w = 390
  key_margin_left = 0
  [key_pt, key_pr, key_pb, key_pl] = [10, 10, 10, 15]
  [pt, pr, pb, pl] = [10, 22, 25, 33]

  previous_id = null

  # ---
  # default options
  #
  # the options hash is modified in the UI and then update_options is called
  # to refresh the visualization with the new options.
  # 
  # TODO:
  # Could be easily extended to save the state of the visualization in the url
  # so people could link to specific sorts/filters
  #
  # ---
  # root.options = {top: 50, bottom: 0, genres: null, year: "all", stories: null, sort:"overall", show:"schools_index"}
  #
  #

  root.options = {}

  update_hash = () =>
    encoded = rison.encode(root.options)
    document.location.hash = encoded


  update_options = () =>
    loaded_options = {}
    if document.location.hash
      loaded_options = rison.decode(document.location.hash.replace(/^#/,""))
    else
      loaded_options = {}
    root.options = {}
    root.options['id'] = loaded_options['id'] or "Kansas City"
    root.options['show'] = loaded_options['show'] or "schools_index"
    # root.options = {id:"Kansas City", show:"schools_index"}

  ranges = {
    overall_score: [-1.7, 0.7]
    schools_index: [-3.0, 3.7]
    safety_index:  [-3.2, 0.9]
    appreciation_index: [-2.30, 3.10]
    affordability_index: [-1.8, 3.10]
    parks_index: [-1.1, 3.5]
    commute_index: [-3.1, 2.3]
    pet_index: [-2.0, 1.5]
    walkability_index: [-1.0, 3.1]
    landscaping_index: [-1.6, 3.0]
    quiet_index: [-1.6, 2.4]
    go_do_index: [-1.5, 3.1]
  }

  # ---
  # used to map between UI and underlying data columns
  # ---
  sort_key = {
    overall: "overall_score",
    schools: "schools_index",
    population: "population"
    distance: 'distance'
  }

  # ---
  # These are variables we would like availible anywhere in the visualization
  # ---
  data = null
  all_data = null
  data_by_id = {}
  base_vis = null
  vis = null
  body = null
  vis_g = null
  zero_line = null
  middle_line = null

  # !!!
  # here is the text used for the labels on the main chart
  # !!!
  y_label = ""
  x_label = ""

  # !!!
  # functions to acess values of data used for scales
  # they correspond to columns in our csv data.
  # To use another column for this property simply change
  # the name here.
  # !!!
  id = (d) -> d["name"]
  x = (d) -> d["overall_score"]
  y = (d) -> d[root.options.show]

  # r = (d) -> d["population"]
  r = (d) -> d
  color = (d) -> d["county"]


  # the domain of these scales will be set based
  # on the data below
  x_scale = d3.scale.linear().range([0, width])
  y_scale = d3.scale.linear().range([0, height])
  y_scale_reverse = d3.scale.linear().range([0, height])

  # !!!
  # set domain manually for r scale
  # will need to be changed
  # !!!
  # r_scale = d3.scale.sqrt().range([0, 29]).domain([0,310])
  r_scale = (d) -> if id(d) == root.options.id then 18 else 10

  xAxis = d3.svg.axis().scale(x_scale).tickSize(5).tickSubdivide(true)
  yAxis = d3.svg.axis().scale(y_scale_reverse).ticks(5).orient("left")


  # !!!
  # set range manually for color
  # if we have more/less colors we can change them here 
  # !!!
  color_scale = d3.scale.category10()
  color_scale = d3.scale.ordinal().range(["#1f77b4", "#2ca02c", "#d62728", "#9467bd", "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf", "#078B78", "#5C1509", "#CECECE", "#FFEA0A"])

  get_color = (d) =>
    if id(d) == root.options.id
      "#ff7f0e"
    else
      color_scale(color(d))


  # ---
  # Function used to ensure our raw data is in the correct format for the rest
  # of the visualization.
  # Right now, it ensures the columns listed in sort_key are floats
  # ---
  prepare_data = (data) ->
    scales = {}
    d3.entries(ranges).forEach (entry) ->
      scale = d3.scale.linear().range([0,100])
      scale.domain(entry.value)
      console.log(scale.domain())
      scales[entry.key] = scale

    data.forEach (d) ->
      d3.entries(scales).forEach (entry) ->
        d[entry.key] = entry.value(parseFloat(d[entry.key]))
    data

  prepare_data_by_id = (data) ->
    data_by_id = {}
    data.forEach (d) ->
      data_by_id[id(d)] = d

  # ---
  # Sorts underlying data based on input sort_key key
  # ---
  sort_data = (sort_type) =>
    data = data.sort (a,b) ->
      b1 = parseFloat(a[sort_key[sort_type]]) ? 0
      b2 = parseFloat(b[sort_key[sort_type]]) ? 0
      b1 - b2

  # ---
  # Various filters
  #
  # not sure if the => is necessary...
  # ---
  filter_year = (year) ->
    data = data.filter (d) -> if year == "all" then true else d.year == year

  filter_genres = (genres) =>
    if genres
      data = data.filter (d) -> $.inArray(d["Genre"], genres) != -1

  filter_stories = (stories) =>
    if stories
      data = data.filter (d) -> $.inArray(d["Story"], stories) != -1

  filter_number = (top, bottom) ->
    bottom_start_index = data.length - bottom
    bottom_start_index = 0 if bottom_start_index < 0


    # if top >= bottom_start_index
    #   data = data
    # else
    #   top_data = data[0...top]
    #   bottom_data = data[bottom_start_index..-1]
    #   data = d3.merge([top_data, bottom_data])
    
  filter_count = (count) ->
    data = data[0...count]
    console.log(data[0])

  distance_between = (n1, n2) ->
    xs = n1.x - n2.x
    ys = n1.y - n2.y
    Math.sqrt((xs * xs) + (ys * ys))


  update_distances = (new_id) =>
    if new_id != previous_id
      previous_id = new_id
      centered_on = data_by_id[new_id]
      if centered_on
        data.forEach (d) ->
          d.distance = distance_between(centered_on, d)
          if d.name == centered_on.name
            console.log(d.distance)
      else
        console.log("no index for #{new_id}")


  set_display = (show) ->
    y  = (d) -> d[show]

  # ---
  # updates x and y scales to conform to newly 
  # filtered dataset
  # ---
  update_scales = () =>
    min_y_padding = 20
    min_x_padding = 10

    [min_x, max_x] = d3.extent data, (d) -> parseFloat(x(d))
    # console.log('x: ' + min_x + ' - ' + max_x)
    # min_x = if min_x > 0 then 0 else min_x

    [min_y, max_y] = d3.extent data, (d) -> parseFloat(y(d))
    # console.log('y: ' + min_y + ' - ' + max_y)
    y_padding = parseInt(Math.abs(max_y - min_y) / 5)
    y_padding = if y_padding > min_y_padding then y_padding else min_y_padding

    [min_r, max_r] = d3.extent data, (d) -> parseFloat(r(d))

    min_y = min_y - y_padding
    min_y = if min_y < 0 then 0 else min_y
    max_y = max_y + y_padding
    max_y = if max_y > 100 then 100 else max_y
    
    x_padding = parseInt(Math.abs(max_x - min_x) / 12)
    x_padding = if x_padding > min_x_padding then x_padding else min_x_padding

    min_x = min_x - x_padding
    min_x = if min_x < 0 then 0 else min_x
    max_x = max_x + x_padding
    max_x = if max_x > 100 then 100 else max_x

    x_scale.domain([min_x, max_x])
    y_scale.domain([min_y, max_y])
    y_scale_reverse.domain([max_y, min_y])
    # r_scale.domain([0, max_r])

  # ---
  # Resets data, executes current filters, and then
  # updates scales
  # ---
  update_data = () =>
    data = all_data
    set_display(root.options.show)
    update_distances(root.options.id)
    # filter_year(root.options.year)
    # filter_genres(root.options.genres)
    # filter_stories(root.options.stories)
    # sort_data(root.options.sort)
    sort_data('distance')
    filter_count(20)
    # filter_number(root.options.top, root.options.bottom)
    update_scales()

  # ---
  # creates / updates / deletes bubbles
  # ---
  draw_bubbles = () ->
    bubbles = vis_g.selectAll(".bubble")
      .data(data, (d) -> id(d))

    bubbles.enter()
      .append("circle")
      .attr("class", "bubble")
      .on("mouseover", (d, i) -> show_details(d,i,this))
      .on("mouseout", hide_details)
      .on("click", reselect)
      .attr("opacity", 0.85)
      .attr("fill", (d) -> get_color(d))
      .attr("stroke", (d) -> d3.hsl(get_color(d)).darker())
      .attr("stroke-width", 2)
      .attr("r", 0)
      
    bubbles.transition()
      .duration(1000)
      .attr("transform", (d) -> "translate(#{x_scale(x(d))},#{y_scale(y(d))})")
      .attr("r", (d) -> r_scale(r(d)))
      .attr("fill", (d) -> get_color(d))
      .attr("stroke", (d) -> d3.hsl(get_color(d)).darker())

    base_vis.transition()
      .duration(1000)
      .select(".x_axis").call(xAxis)

    zero_line.transition()
      .duration(1000)
      .attr("x1", x_scale(0))
      .attr("x2", x_scale(0))

    middle_line.transition()
      .duration(1000)
      .attr("y1", y_scale(50.0))
      .attr("y2", y_scale(50.0))

    base_vis.transition()
      .duration(1000)
      .select(".y_axis").call(yAxis)

    bubbles.exit().transition()
      .duration(1000)
      .attr("transform", (d) -> "translate(#{0},#{0})")
    .remove()

    bubbles.exit().selectAll("circle").transition()
      .duration(1000)
      .attr("r", 0)

  # ---
  # helper function to create 
  # the detail listings for movies
  # ---
  # draw_movie_details = (detail_div) ->
  #   detail_div.enter().append("div")
  #     .attr("class", "bubble-detail")
  #     .attr("id", (d) -> "bubble-detail-#{id(d)}")
  #   .append("h3")
  #     .text((d) -> d["Film"])
  #   .append("span")
  #     .attr("class", "detail-rating")
  #     .text((d) -> " #{d["Rotten Tomatoes"]}%")

  #   detail_div.exit().remove()

  # ---
  # updates the lower 'details' section
  # ---
  draw_details = () ->
    # if root.options.top == 0
    #   $("#detail-love").hide()
    # else
    #   $("#detail-love").show()

    if root.options.bottom == 0
      $("#detail-hate").hide()
    else
      $("#detail-hate").show()

    # top_data = data[0...root.options.top]

    detail_top = d3.select("#detail-love").selectAll(".bubble-detail")
      .data(top_data, (d) -> id(d))

    # draw_movie_details(detail_top)

    bottom_data = data[root.options.top..-1].reverse()

    detail_bottom = d3.select("#detail-hate").selectAll(".bubble-detail")
      .data(bottom_data, (d) -> id(d))

    # draw_movie_details(detail_bottom)

  # ---
  # creates the key used to show colors
  # ---
  draw_key = () ->
    display_keys = {}
    all_data.forEach (d) -> display_keys[d["county"]] = 1
    key_r = 10

    key = d3.select("#legend")
      .append("svg")
      .attr("id", "legend-svg")
      .attr("width", key_w + key_margin_left )
      .attr("height", key_h + key_pb + key_pt)

    key = key.append("g")
      .attr("transform", "translate(#{key_margin_left},0)")

    key.append("rect")
      .attr("width", key_w)
      .attr("height", key_h + key_pb + key_pt)
      .attr("fill", "#fff")

    key = key.append("g")
      .attr("transform", "translate(#{key_pl},#{key_pt})")

    key_group = key.selectAll(".key-group")
      .data(d3.keys(display_keys))
      .enter().append("g")
        .attr("class", "key-group")
        .attr("transform", (d,i) -> "translate(#{i * 75},#{0})")

    key_group.append("circle")
        .attr("r", key_r)
        .attr("fill", (d) -> color_scale(d))
        .attr("transform", (d) -> "translate(#{key_r}, #{key_r})")

    key_group.append("text")
        .attr("class", "key-text")
        .attr("dy", 15)
        .attr("dx", key_r * 2 + 6)
        .text((d) -> d.replace(" County", ""))

    # key_demo_group = key.append("g")
    #   .attr("transform", "translate(#{0},0)")

    # example_x = 280
    # example_r = 20
    # example_y = key_h / 2 - example_r

    # key_demo_group.append("circle")
    #   .attr("r", example_r)
    #   .attr("fill", color_scale(d3.keys(display_keys)[0]))
    #   .attr("transform", (d) -> "translate(#{example_r}, #{example_r})")
    #   .attr("cx", example_x)
    #   .attr("cy", example_y)

    # key_demo_group.append("line")
    #   .attr("x1", example_x)
    #   .attr("x2", example_x + example_r * 2)
    #   .attr("y1", example_y + example_r)
    #   .attr("y2", example_y + example_r)
    #   .attr("stroke", "#333")
    #   .attr("stroke-dasharray", "3")
    #   .attr("stroke-width", 2)

    # key_demo_group.append("text")
    #   .attr("dx", example_x + (example_r * 2) + 4 )
    #   .attr("dy", example_y + example_r - 8)
    #   .text("Film's")

    # key_demo_group.append("text")
    #   .attr("dx", example_x + (example_r * 2) + 4 )
    #   .attr("dy", example_y + example_r + 6)
    #   .text("Budget")

  # ---
  # Creates initial framework for visualization
  # ---
  render_vis = (csv) ->
    update_options()
    all_data = prepare_data(csv)
    prepare_data_by_id(all_data)
    update_data()

    base_vis = d3.select("#vis")
      .append("svg")
      .attr("width", width + (pl + pr) )
      .attr("height", height + (pt + pb) )
      .attr("id", "vis-svg")

    base_vis.append("g")
      .attr("class", "x_axis")
      .attr("transform", "translate(#{pl},#{height + pt})")
      .call(xAxis)

    base_vis.append("text")
      .attr("x", width / 2)
      .attr("y", height + (pt + pb) - 10)
      .attr("text-anchor", "middle")
      .attr("class", "axisTitle")
      .attr("transform", "translate(#{pl},0)")
      .text(x_label)

    base_vis.append("g")
      .attr("class", "y_axis")
      .attr("transform", "translate(#{pl},#{pt})")
      .call(yAxis)

    vis = base_vis.append("g")
      .attr("transform", "translate(#{0},#{height + (pt + pb)})scale(1,-1)")

    vis.append("text")
      .attr("x", height/2)
      .attr("y", 20)
      .attr("text-anchor", "middle")
      .attr("class", "axisTitle")
      .attr("transform", "rotate(270)scale(-1,1)translate(#{pb},#{0})")
      .text(y_label)
   
    body = vis.append("g")
      .attr("transform", "translate(#{pl},#{pb})")
      .attr("id", "vis-body")

    zero_line = body.append("line")
      .attr("x1", x_scale(0))
      .attr("x2", x_scale(0))
      .attr("y1", 0 + 5)
      .attr("y2", height - 5)
      .attr("stroke", "#aaa")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", "2")

    middle_line = body.append("line")
      .attr("x1", 0 + 5)
      .attr("x2", width + 5)
      .attr("y1", y_scale(50.0))
      .attr("y2", y_scale(50.0))
      .attr("stroke", "#aaa")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", "2")
 
    vis_g = body.append("g")
      .attr("id", "bubbles")

    # draw_bubbles()
    # draw_details()
    draw_key()

  reselect = (data, index) ->
    root.options.id = id(data)
    hide_details()
    update_hash()


  # ---
  # function that is called when a bubble is 
  # hovered over
  # ---
  show_details = (bubble_data, index, element) ->
    bubbles = body.selectAll(".bubble")

    bBox = element.getBBox()
    box = { "height": Math.round(bBox.height), "width": Math.round(bBox.width), "x": width + bBox.x, "y" : height + bBox.y}
    box.x = Math.round(x_scale(x(bubble_data)))  - (pr+109) + r_scale(r(bubble_data))
    box.y = Math.round(y_scale_reverse(y(bubble_data))) - (r_scale(r(bubble_data)) + pt + 20)

    tooltipWidth = parseInt(d3.select('#tooltip').style('width').split('px').join(''))

    msg = '<p class="title">' + bubble_data["name"] + '</p>'
    msg += '<table>'
    msg += '<tr><td>Overall Score:</td><td>' +  bubble_data["overall_score"] + '</td></tr>'
    msg += '<tr><td>Population:</td><td>' +  bubble_data["population"] + '</td></tr>'
    msg += '<tr><td>Distance:</td><td>' +  bubble_data["distance"] + '</td></tr>'
    msg += '<tr><td>Profit:</td><td>' +  bubble_data["Profit"] + ' mil' + '</td></tr>'
    msg += '<tr><td>Story:</td><td>' +  bubble_data["Story"] + '</td></tr>'
    msg += '</table>'

    d3.select('#tooltip').classed('hidden', false)
    d3.select('#tooltip .content').html(msg)
    d3.select('#tooltip')
      .style('left', "#{(box.x + (tooltipWidth / 2)) - box.width / 2}px")
      .style('top', "#{(box.y) }px")


    selected_bubble = d3.select(element)
    selected_bubble.attr("opacity", 1.0)

    unselected_movies = bubbles.filter( (d) -> id(d) != id(bubble_data))
    .selectAll("circle")
      .attr("opacity",  0.3)

    crosshairs_g = body.insert("g", "#bubbles")
      .attr("id", "crosshairs")

    crosshairs_g.append("line")
      .attr("class", "crosshair")
      .attr("x1", 0 + 3)
      .attr("x2", x_scale(x(bubble_data)) - r_scale(r(bubble_data)))
      .attr("y1", y_scale(y(bubble_data)))
      .attr("y2", y_scale(y(bubble_data)))
      .attr("stroke-width", 1)

    crosshairs_g.append("line")
      .attr("class", "crosshair")
      .attr("x1", x_scale(x(bubble_data)))
      .attr("x2", x_scale(x(bubble_data)))
      .attr("y1", 0 + 3)
      .attr("y2", y_scale(y(bubble_data)) - r_scale(r(bubble_data)))
      .attr("stroke-width", 1)

  # ---
  # function that is called when
  # mouse leaves a bubble
  # ---
  hide_details = (bubble_data) ->
    d3.select('#tooltip').classed('hidden', true)

    bubbles = body.selectAll(".bubble").selectAll("circle")
      .attr("opacity", 0.85)

    body.select("#crosshairs").remove()

  update_content = () =>
    current_selection = data_by_id[root.options.id]
    if !current_selection
      current_selection = all_data[0]
    d3.select('#name-section')
      .html("<h3>#{current_selection.name}</h3>")

    d3.keys(ranges).forEach (k) ->
      score = current_selection[k]
      detail = d3.select("#detail_#{k}")
      detail.select(".score").html(toFixed(score, 0) + "%")
    
# ---
# MAIN
# ---
     

  # ---
  # Entry point for updating the visualization
  # called by update_options
  # ---
  update = () =>
    update_options()
    console.log(root.options)
    update_data()
    draw_bubbles()
    update_content()
    # draw_details()
    #
  hashchange = () ->
    console.log('update')
    update()

  d3.select(window)
    .on("hashchange", hashchange)

  d3.selectAll("#selectors a").on "click", (e) ->
    found_id = d3.select(this).attr("id")
    show = "#{found_id}_index"
    root.options.show = show
    update_hash()
    d3.event.preventDefault()

  setup_vis = (error, data) ->
    if error
      console.log(error)
    render_vis(data)
    update()
    # names = d3.keys(data_by_id)
    # $('input.name-search').change () ->
    #   console.log($(this).text)
    # $('.name-search').typeahead({
    #   name: 'names'
    #   local: names
    #   limit: 10
    # })

  

  # load the data then call 
  d3.csv "data/web_data_fakenames_utf.csv", setup_vis


  # ---
  # UI accessible update function
  # ---
  # root.update_options = (new_options) =>
  #   root.options = $.extend({}, root.options, new_options)
  #   update()

