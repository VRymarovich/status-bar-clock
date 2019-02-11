{CompositeDisposable} = require 'atom'
class StatusBarClockView extends HTMLElement
  countdownTime = 300
  countdown = countdownTime
  activeTime = 0
  date = new Date
  timestamp = date.getTime()
  timestamps = []
  constructor:->
    console.log 'constr'

  init: ->
    console.log 'init'
    @disposables = new CompositeDisposable
    storage = localStorage['status-bar-clock.timestamps']
    if !storage
      localStorage['status-bar-clock.timestamps'] = '[]'
    timestamps = JSON.parse(localStorage['status-bar-clock.timestamps'])
    activeTime = Math.round(timestamps.map((x)->x.delta).reduce((x,y)-> x+y)/1000)
    #console.log timestamps
    @classList.add('status-bar-clock', 'inline-block', 'icon-clock')
    #@activate()

  activate: ->
    console.log 'activate'
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
    #console.log atom.project.getDirectories()

  deactivate: ->
    @disposables.dispose()
    #console.log 'deactivate'
    clearInterval @intervalId

  calculateTime: (command)->
    date = new Date
    if countdown >=0
      paths = atom.project.getDirectories().map (x)->x.path
      filePath = atom.workspace.getActiveTextEditor()?.getPath()
      project = ''
      paths.forEach (path) ->
        if filePath
          match = filePath.search path
          if match>-1
            project = path
      delta = date.getTime()-timestamp
      timestamps.push {project: project, timestamp:date.getTime(), delta: delta, path: atom.workspace.getActiveTextEditor()?.getPath()}
      timestamp = date.getTime()
      #console.log countdown, timestamps, @disposables
    else
      timestamp = date.getTime()

  getTime:(time) ->
    date = time
    seconds = time%60
    minutes = Math.floor(time/60)%60
    hour = Math.floor(time/3600)

    minutes = '0' + minutes if minutes < 10
    seconds = '0' + seconds if seconds < 10

    "#{hour}:#{minutes}:#{seconds}"

  updateClock: ->
    date = new Date
    countdown--
    if countdown > 0
      activeTime++
    if countdown==0
      @calculateTime()
    if activeTime%60
      #save to storage
      localStorage['status-bar-clock.timestamps'] = JSON.stringify(timestamps)
    @textContent = @getTime(activeTime)

module.exports = document.registerElement('status-bar-clock', prototype: StatusBarClockView.prototype, extends: 'div')
###

###
