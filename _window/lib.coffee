Promise = require 'bluebird'
fs = require 'fs'
{remote, ipcRenderer} = require 'electron'
{createHash} = require 'crypto'
path = require 'path'
d3 = require 'd3-selection'
colors = require 'colors/safe'

options = remote.getGlobal 'options' or {}
options.dpi ?= 96
options.log = false

waitForUserInput = (data)->
  new Promise (resolve, reject)->
    ipcRenderer.once 'done-waiting', ->resolve(data)
    ipcRenderer.send 'wait-for-input'

sleep = (data)->
  new Promise (resolve, reject)->
    fn = ->resolve(data)
    setTimeout fn, 1000

generateFigure = (task)->
  main = d3.select "#pdf-printer-ui-controls"
  main.html ""
  ## Set up a webview
  webview = main.append "webview"
    .attr "nodeintegration", true
    .attr "src", "file://"+require.resolve("../_runner/index.html")
    .node()

  new Promise (resolve, reject)->
    webview.addEventListener 'dom-ready', (e)->
      webview.send "run-task", {
        code: task.code
        helpers: task.helpers
      }
    webview.addEventListener 'ipc-message', (e)->
      if event.channel == 'finished'
        resolve(task)

pixelsToMicrons = (px)->
  Math.ceil(px/96.0*25400)

printToPDF = (webview, size)->
  new Promise (resolve, reject)->
    ###
    Print the webview to the callback
    ###
    opts =
      printBackground: true
      marginsType: 1
      pageSize:
        height: pixelsToMicrons(size.height)+10
        width: pixelsToMicrons(size.width)+10

    webview.printToPDF opts, (e,data)=>
      reject(e) if e?
      resolve(data)

printToImage = (webview, opts)->
  new Promise (resolve, reject)->
    ###
    Print the webview to the callback
    ###
    opts.format ?= 'png'
    opts.scaleFactor ?= 2
    opts.quality ?= 90
    {width,height} = opts
    width*=2
    height*=2
    rect = {x:0,y:0,width,height}
    webview.capturePage rect, (image)->
      reject(e) if e?
      if ['jpeg','jpg'].includes(opts.format)
        d = image.toJPEG(rect, opts.quality)
      else
        d = image.toPNG(opts.scaleFactor)
      resolve(d)

printFigureArea = (task)->
  ###
  # Function to print webpage
  ###
  opts = task.opts or {}
  el = document.querySelector('#pdf-printer-figure-container>*:first-child')

  {width, height} = el.getBoundingClientRect()
  opts = {width, height}

  {outfile} = task
  dir = path.dirname outfile
  if not fs.existsSync(dir)
    fs.mkdirSync dir
  console.log "Printing to #{outfile}"

  ext = path.extname(outfile)

  {webContents} = require('electron')
  console.log webContents

  if ['.jpg','.jpeg','.png'].includes(ext)
    opts.format = ext.slice(1)
    buf = await printToImage(webContents, opts)
  else
    buf = await printToPDF(webContents, opts)

  fs.writeFileSync outfile, buf
  console.log "Finished task"

# Initialize renderer
class Printer
  constructor: (@options={})->
    ###
    Setup a rendering object
    ###
    @cliOptions = {}
    console.log "Started renderer"

    @options.buildDir ?= ''
    @tasks = []

    @options.helpers ?= ['css','stylus']

  task: (fn, funcOrString, opts={})->
    ###
    Add a task
    ###
    opts.dpi ?= 300

    # Check if we've got a function or string
    if typeof funcOrString == 'function'
      throw "We only support strings now, because we run things in a webview"
      func = funcOrString
    else
      # Require relative to parent module,
      # but do it later so errors can be accurately
      # traced
      if not path.isAbsolute(funcOrString)
        func = path.join process.cwd(), funcOrString
      else
        func = funcOrString
      #f = require fn
      #f(el, cb)

    # Apply build directory
    if fn?
      if not path.isAbsolute(fn)
        fn = path.join(@options.buildDir,fn)
    else
      fn = ""

    h = createHash('md5')
          .update(fn)
          .digest('hex')

    @tasks.push
      outfile: fn
      code: func
      helpers: @options.helpers
      hash: h
      opts: opts
    return @

  run: ->
    # Progress through list of figures, print
    # each one to file
    __runTask = (t)->
      console.log "#{t.code} ⇒ #{t.outfile}"
      p = generateFigure(t)

      if options.waitForUser
        p = p.then waitForUserInput

      p.then printFigureArea
        .catch (e)->console.log('Error: '+e)

    Promise
      .map @tasks, __runTask, concurrency: 1

module.exports = {
  Printer
  printFigureArea
  generateFigure
}
