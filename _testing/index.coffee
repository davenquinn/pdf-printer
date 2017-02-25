{remote, ipcRenderer} = require 'electron'
path = require 'path'
Promise = require 'bluebird'
d3 = require 'd3-selection'

{Printer} = require("../index.coffee")
window.Printer = Printer

options = remote.getGlobal 'options'

try
  require '../_helpers/stylus-css-modules'
catch e
  console.log "Couldn't import helper for stylus css modules,
               stylus and css-modules-require-hook should be installed"

createMainPage = null
isMainPage = null

body = d3.select 'body'
main = d3.select '#main'
title = d3.select '#controls>h1'
d3.select '#toggle-dev-tools'
  .on 'click', ->
    ipcRenderer.send 'toggle-dev-tools'

setZoom = (zoom)->
  main
    .datum zoom: zoom
    .style 'zoom', (d)->d.zoom
ipcRenderer.on 'zoom', (event, zoom)->
  setZoom zoom

sharedStart = (array) ->
  # From
  # http://stackoverflow.com/questions/1916218/find-the-longest-common-starting-substring-in-a-set-of-strings
  A = array.concat().sort()
  a1 = A[0]
  a2 = A[A.length - 1]
  L = a1.length
  i = 0
  while i < L and a1.charAt(i) == a2.charAt(i)
    i++
  a1.substring 0, i

itemSelected = (d)->
  location.hash = "##{d.hash}"
  body.attr 'class','figure'

  title
    .html ""
    .append 'a'
    .attr 'href','#'
    .text '◀︎ Back to list'
    .on 'click', loadEntryPoint(createMainPage)

  main.html ""
  d.function main.node(), ->

renderSpecList = (d)->
  # Render spec list from runner
  el = d3.select @

  # Find shared starting substring
  arr = d.tasks.map (d)->d.outfile
  arr.push d.name

  prefix = sharedStart(arr)

  el.append 'h5'
    .text prefix

  el.append 'h2'
    .text d.name.slice(prefix.length)

  sel = el
    .append 'ul'
    .selectAll 'li'
    .data d.tasks

  sel.enter()
    .append 'li'
    .append 'a'
      .attr 'href',(d)->"##{d.hash}"
      .text (d)->d.outfile.slice(prefix.length)
      .on 'click', itemSelected

createMainPage = (runners)->
  # Create a list of tasks
  body.attr 'class','task-list'

  title
    .html ""
    .text 'Figure index'

  main.html ""
  sel = main.selectAll 'div'
        .data runners

  sel.enter()
    .append 'div'
    .attr 'class', 'runner'
    .each renderSpecList

runBasedOnHash = (runners)->
  z = remote.getGlobal('zoom')
  setZoom z

  # We've only got one possibility,
  # so we don't need hashes!
  if runners.length == 1
    itemSelected runners[0]
    return

  if location.hash.length > 1
    console.log "Attempting to navigate to #{location.hash}"
    # Check if we can grab a dataset
    _ = runners.map (d)->d.tasks
    tasks = Array::concat.apply [], _
    for item in tasks
      if item.hash == location.hash.slice(1)
        itemSelected item
        return

  # If no hash then create main page
  createMainPage(runners)

getSpecs = (d)->
  res = require(d)
  Promise.resolve res
    .then (v)->
      v.name = d
      v

loadEntryPoint = (fn)-> ->
  # If we are in spec mode
  if options.specs?
    Promise.map options.specs, getSpecs
      .then fn
  else
    task =
      function: require options.infile
      hash: "#hash"
    location.hash = "#hash"
    fn([task])

fn = loadEntryPoint(runBasedOnHash)
fn()

