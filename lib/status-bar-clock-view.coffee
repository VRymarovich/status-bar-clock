class StatusBarClockView extends HTMLElement
  countdown = 300
  activeTime = 0

  init: ->
    @classList.add('status-bar-clock', 'inline-block', 'icon-clock')
    #@activate()

  activate: ->
    @intervalId = setInterval @updateClock.bind(@), 1000
    atom.workspace.observeTextEditors (editor) ->
      editor.onDidSave ->
        countdown = 300
      editor.onDidStopChanging ->
        countdown = 300

  deactivate: ->
    clearInterval @intervalId

  getTime:(time) ->
    date = time
    seconds = time%60
    minutes = Math.floor(time/60)
    hour = Math.floor(time/3600)

    minutes = '0' + minutes if minutes < 10
    seconds = '0' + seconds if seconds < 10

    "#{hour}:#{minutes}:#{seconds}"

  updateClock: ->
    date = new Date
    countdown--
    if countdown > 0
      activeTime++
    @textContent = @getTime(activeTime)

module.exports = document.registerElement('status-bar-clock', prototype: StatusBarClockView.prototype, extends: 'div')
###

###
