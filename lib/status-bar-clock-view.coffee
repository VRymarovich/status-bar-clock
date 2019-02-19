{CompositeDisposable} = require 'atom'
fs = require('fs')
class StatusBarClockView extends HTMLElement
  countdownTime = 300
  countdown = countdownTime
  activeTime = 0
  date = new Date
  timestamp = date.getTime()
  timestamps = []
  logfile = ''
  timerIdle = 10

  constructor:->

  init: ->
    logfile = atom.config.get('status-bar-time-tracker.logfile')
    timerIdle = atom.config.get('status-bar-time-tracker.timerIdle')
    console.log 'init', logfile, timerIdle
    @disposables = new CompositeDisposable
    @classList.add('status-bar-clock', 'inline-block', 'icon-clock')
    #@activate()

  activate: ->
    console.log 'activate'
    countdownTime = timerIdle*60
    countTime = []
    console.log logfile
    fs.readFile(logfile,'utf-8', (err, data)->
      if err
        throw err
      lines = data.split('\n')
      lines.forEach((line) ->
        line = line.split(', ')
        countTime.push {
          project: line[0],
          timestamp: parseInt(line[1]),
          delta: parseInt(line[2]),
          path: line[3]
        }
      )
      activeTime = Math.round countTime.filter((x)->!isNaN(x.delta)).map((x) ->
        x.delta
      ).reduce(((x, y) ->
        x + y
      ), 0) / 1000
    )
    timestamps = []
    that = @
    @intervalId = setInterval @updateClock.bind(@), 1000
    @disposables = new CompositeDisposable
    atom.workspace.observeTextEditors (editor) ->
      that.disposables.add editor.onDidSave ->
        that.calculateTime()
        countdown = countdownTime
      that.disposables.add editor.onDidStopChanging ->
        that.calculateTime()
        countdown = countdownTime
        #editor.onDidChangeCursorPosition ->
          #  countdown = 300
          #  that.calculateTime()
    atom.config.onDidChange 'status-bar-time-tracker.timerIdle', ({newValue, oldValue}) ->
      #console.log 'My configuration changed:', newValue, oldValue
      timerIdle = newValue
    atom.config.onDidChange 'status-bar-time-tracker.logfile', ({newValue, oldValue}) ->
      #console.log 'My configuration changed:', newValue, oldValue
      logfile = newValue
    #console.log atom.project.getDirectories()

  deactivate: ->
    @disposables.dispose()
    console.log 'deactivate'
    clearInterval @intervalId
    timestamps = []
    countdown = countdownTime
    activeTime = 0
    date = new Date
    timestamp = date.getTime()

  calculateTime: ()->
    date = new Date
    if countdown<0
      timestamp = date.getTime()
    paths = atom.project.getDirectories().map (x)->x.path
    filePath = atom.workspace.getActiveTextEditor()?.getPath()
    project = ''
    paths.forEach (path) ->
      if filePath
        match = filePath.search path
        if match>-1
          project = path
    delta = date.getTime()-timestamp
    timestamps.push {
      project: project,
      timestamp:date.getTime(),
      delta: delta,
      path: atom.workspace.getActiveTextEditor()?.getPath(),
    }
    timestamp = date.getTime()

  getTime:(time) ->
    date = time
    seconds = time%60
    minutes = Math.floor(time/60)%60
    hours = Math.floor(time/3600)%24
    days = Math.floor(time/86400)

    minutes = '0' + minutes if minutes < 10
    seconds = '0' + seconds if seconds < 10
    hours = '0' + hours if hours < 10

    out = "#{hours}:#{minutes}:#{seconds}"

    if days>0
      out = "#{days}d " + out

    out
  updateClock: ->
    date = new Date
    countdown--
    if countdown > 0
      activeTime++
    if countdown==0
      @calculateTime()
    if activeTime%60==0
      #save to storage
      #localStorage['status-bar-clock.timestamps'] = JSON.stringify(timestamps)
      if !fs.existsSync(logfile)
        timestamps.unshift(['project', 'timestamp', 'delta', 'file'])
      data = @json_to_csv(timestamps)
      fs.appendFileSync(logfile, data)
      #console.log home
      timestamps = []
    @textContent = @getTime(activeTime)

  json_to_csv: (json)->
    line = ''
    timestamps.forEach (timestamp) ->
      row = Object.values(timestamp).join(', ')
      line = line + row + '\n'
    return line
module.exports = document.registerElement('status-bar-clock', prototype: StatusBarClockView.prototype, extends: 'div')
###

###
