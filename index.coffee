Promise = require 'bluebird'
fs = require 'fs'
{remote} = require 'electron'
{createHash} = require 'crypto'
path = require 'path'

runTask = (task)->
  ###
  Run a single printing task from a task spec
  ###
  runFunction = new Promise (resolve, reject)->
    el = document.body
    el.innerHTML = ""
    el.style.margin = 0
    task.function el, resolve
  printDataset = new Promise (resolve, reject)->
    # Could add error handling with reject
    el = document.querySelector 'body>*'
    print el, task.outfile, ->
      console.log "Finished task"
      resolve()

  runFunction
    .then printDataset

print = (el, fn, callback)->
  ###
  Print the webview to the callback
  ###
  c = remote.getCurrentWebContents()
  console.log "Printing to #{fn}"
  v = el.getBoundingClientRect()

  opts =
    printBackground: true
    marginsType: 1
    pageSize:
      width: v.right/72
      height: v.bottom/72
  opts.landscape = opts.pageSize.width > opts.pageSize.height

  printToPDF = Promise.promisify c.printToPDF
  writeFile = Promise.promisify fs.writeFile

  printToPDF opts
    .tap ->
      dir = path.dirname fn
      if !fs.existsSync(dir)
        fs.mkdirSync dir
    .then (d)->
      writeFile fn, d
    .then callback

# Initialize renderer
class Printer
  constructor: ->
    ###
    Setup a rendering object
    ###
    console.log "Started renderer"
    @tasks = []

  task: (fn, func)->
    ###
    Add a task
    ###
    h = createHash('md5')
          .update(fn)
          .digest('hex')

    @tasks.push
      outfile: fn
      function: func
      hash: h
    return @

  run: ->
    # Progress through list of figures, print
    # each one to file
    Promise
      .map @tasks, runTask, concurrency: 1

module.exports =
  Printer: Printer
  print: print
