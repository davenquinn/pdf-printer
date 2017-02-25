# Headless mode for figure generation
path = require 'path'
fs = require 'fs'
min = require 'minimist'
Promise = require 'bluebird'
{BrowserWindow, app, ipcMain} = require 'electron'
shortcuts = require './shortcuts'
readline = require 'readline'

argv = min process.argv.slice(2), boolean: ['debug', 'spec-mode']
# Specify --debug to show BrowserWindow
#   and open devtools
# Specify --spec to load from a spec
debug = argv.debug
# Option just to show browser window (primarily for
# debugging taskflow of this module)
show = argv.show or debug
# Set directory to reload if not given
if debug
  argv.reload ?= process.cwd()
  r = path.resolve argv.reload
  console.log "Reloading from directory #{r}"
  require('electron-reload')(r)

args = argv._
global.args = args
global.specMode = argv['spec-mode']

global.options = {
  # Wait between rendering items
  waitForUser: show
  dpi: parseInt(argv.dpi) or 300
  debug: debug
}

if argv['spec-mode']
  # Create list of task-runner files to import
  # Each argument should be a javascript or coffeescript
  # file exporting a renderer object
  options.specs = args.map (d)->path.resolve(d)
else
  options.infile = argv._[0]
  options.outfile = argv._[1]

### Setup IPC ###

rl = readline.createInterface
  input: process.stdin,
  output: process.stdout

createWindow = ->

  console.log if debug \
         then "Creating browser window" \
         else "Creating headless renderer"

  win = new BrowserWindow {show: show}
  if debug
    url = "file://#{__dirname}/_testing/index.html"
  else
    url = "file://#{__dirname}/_headless/index.html"
  win.loadURL url
  shortcuts(win)
  ipcMain.on 'toggle-dev-tools', ->
    win.toggleDevTools()

  ipcMain.on 'wait-for-input', (event)->
    rl.question 'Press enter to continue', (ans)->
      event.sender.send('done-waiting')

  win.on 'closed', ->
    win = null

app.on 'ready', createWindow
app.on 'window-all-closed', -> app.quit()
