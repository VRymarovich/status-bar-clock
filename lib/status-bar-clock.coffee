{CompositeDisposable} = require 'atom'
StatusBarClockView = require './status-bar-clock-view'
PanelPackageView = require './panel-package-view'
StatsView  = require './stats-view'

module.exports = StatusBarClock =
  config:
    activateOnStart:
      type: 'string'
      default: 'Remember last setting'
      enum: ['Remember last setting', 'Show on start', 'Don\'t show on start']
    timerIdle:
      description: 'Set inactive time in minutes. When user idles more than this time, the counter stops.'
      type: 'integer'
      minimum: 5
      default: 10

  active: false

  activate: (state) ->
    @state = state
    #console.log 'activated'
    @subscriptions = new CompositeDisposable
    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'status-bar-clock:toggle': => @toggle()
    atom.workspace.addOpener (uri) ->
        #if uri == 'atom://panel-package-info'
        #  new PanelPackageView()
        if uri == 'atom://stats-info-panel'
          console.log('press')
          new StatsView
    @statusBarClockView = new StatusBarClockView
    @statusBarClockView.init()

  deactivate: ->
    console.log 'Clock was deactivated'
    @subscriptions.dispose()
    @statusBarClockView.destroy()
    @statusBarTile?.destroy()

  serialize: ->
    {
      activateOnStart: atom.config.get('status-bar-time-tracker.activateOnStart'),
      timerIdle: atom.config.get('status-bar-time-tracker.timerIdle'),
      active: @active
    }

  toggle: (active = undefined) ->
    active = ! !!@active if !active?

    if active
      console.log 'Clock was toggled on'
      @statusBarClockView.activate()
      @statusBarTile = @statusBar.addRightTile
        item: @statusBarClockView, priority: -1
    else
      @statusBarTile?.destroy()
      @statusBarClockView?.deactivate()

    @active = active

  consumeStatusBar: (statusBar) ->
    @statusBar = statusBar
    # auto activate as soon as status bar activates based on configuration
    @activateOnStart(@state)

  activateOnStart: (state) ->
    switch state.activateOnStart
      when 'Remember last setting' then @toggle state.active
      when 'Show on start' then @toggle true
      else @toggle false
