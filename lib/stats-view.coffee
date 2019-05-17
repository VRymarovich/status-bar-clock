#ct-chartLineProject_ = require 'underscore-plus'
{$, ScrollView} = require 'atom-space-pen-views'
Chartist = require './chartist.js'
{CompositeDisposable} = require 'atom'
moment = require 'moment'

fs = require 'fs'
logfile = __dirname + '/../timetracker.log'

log = []
projectLog = []


lineChart = null

lineChartData = {}
lineChartOptions = {
  stackBars: true,
  height: 100,
  low:0,
  axisX: {
      type: Chartist.FixedScaleAxis,
      divisor: 5,
      labelInterpolationFnc: (value) ->
        return moment(value).format('MMM D')
    }
}

pieChart = null
pieChartData = {}
pieChartOptions = {
  #donut: true,
  #donutWidth: 60,
  #startAngle: 0,
  #total: 100,
  #showLabel: false,
  height: 150,
  labelInterpolationFnc: (value) ->
    sum = pieChartData.series.reduce (a, b)->
      return a+b
    ,0
    percent = Math.round(value / sum * 100)
    if percent>1
      return percent + '%'
    else
      return ''
}

fileLog = []
projectLog = []

timestamp = new Date
today = new Date(timestamp.getFullYear(), timestamp.getMonth(), timestamp.getDate()).getTime()
tomorrow = new Date(timestamp.getFullYear(), timestamp.getMonth(), timestamp.getDate()+1).getTime()
yesterday = new Date(timestamp.getFullYear(), timestamp.getMonth(), timestamp.getDate()-1).getTime()
lastWeek = new Date(timestamp.getFullYear(), timestamp.getMonth(), timestamp.getDate()-7).getTime()
lastMonth = new Date(timestamp.getFullYear(), timestamp.getMonth()-1, timestamp.getDate()).getTime()

convertMsToTime = (ms)->
  seconds = Math.floor(ms/1000)%60
  minutes = Math.floor(ms/1000/60)%60
  hours = Math.floor(ms/1000/60/60)%24
  days = Math.floor(ms/1000/86400)

  minutes = '0' + minutes if minutes < 10
  seconds = '0' + seconds if seconds < 10
  hours = '0' + hours if hours < 10

  out = "#{hours}:#{minutes}:#{seconds}"

  if days>0
    out = "#{days}d " + out
  out

module.exports =
class StatsView extends ScrollView
  @activate: ->
    new StatsView
  @content: ->
    @div class: 'stats-wrapper m-3', tabindex: -1, =>
      @div class: 'row', =>
        @div class: 'col-sm-4', =>
          @h5 class: 'fileName', id: 'fileName'
          @table =>
            @tr =>
              @td =>
                @b 'Total File Time: '
              @td id: 'totalFileTime'
            @tr =>
              @td =>
                @b 'Today File Time: '
              @td id: 'todayFileTime'
            @tr =>
              @td =>
                @b 'Yesterday File Time: '
              @td id: 'yesterdayFileTime'
            @tr =>
              @td =>
                @b 'Last Week File Time: '
              @td id: 'lastWeekFileTime'
            @tr =>
              @td =>
                @b 'Last Month File Time: '
              @td id: 'lastMonthFileTime'
            @tr =>
              @td =>
                @b 'Total Project Time:'
              @td id: 'totalProjectTime'
            @tr =>
              @td =>
                @b 'Today Project Time: '
              @td id: 'todayProjectTime'
            @tr =>
              @td =>
                @b 'Yesterday Project Time: '
              @td id: 'yesterdayProjectTime'
            @tr =>
              @td =>
                @b 'Last Week Project Time: '
              @td id: 'lastWeekProjectTime'
            @tr =>
              @td =>
                @b 'Last Month Project Time: '
              @td id: 'lastMonthProjectTime'
          @div class: 'row m-1', =>
            @div class: 'col-sm-4', =>
              @div class: 'ct-chartPie ct-perfect-fourth', id: 'chartPie'
            @div class: 'col-sm-8', =>
              @b id: 'fileDetailsTitle', 'Time By Files:'
              @div =>
                @div id: 'fileDetailsData'
        @div class: 'col-sm-8', =>
          @div id:'trackerButtons', =>
            @div class: 'btn-group center', =>
              @button outlet: 'totalFileTimeBut', class: 'btn', click: 'showTotalFileTimeChart', 'Total File Time'
              @button outlet: 'todayFileTimeBut', class: 'btn', click: 'showTodayFileTimeChart', 'Today File Time'
              @button outlet: 'yesterdayFileTimeBut', class: 'btn', click: 'showYesterdayFileTimeChart', 'Yesterday File Time'
              @button outlet: 'lastWeekFileTimeBut', class: 'btn', click: 'showLastWeekFileTimeChart', 'Last Week File Time'
              @button outlet: 'lastMonthFileTimeBut', class: 'btn', click: 'showLastMonthFileTimeChart', 'Last Month File Time'
            @div class: 'btn-group center', =>
              @button outlet: 'totalProjectTimeBut', class: 'btn', click: 'showTotalProjectTimeChart', 'Total Project Time'
              @button outlet: 'todayProjectTimeBut', class: 'btn', click: 'showTodayProjectTimeChart', 'Today Project Time'
              @button outlet: 'yesterdayProjectTimeBut', class: 'btn', click: 'showYesterdayProjectTimeChart', 'Yesterday Project Time'
              @button outlet: 'lastWeekProjectTimeBut', class: 'btn', click: 'showLastWeekProjectTimeChart', 'Last Week Project Time'
              @button outlet: 'lastMonthProjectTimeBut', class: 'btn', click: 'showLastMonthProjectTimeChart', 'Last Month Project Time'
            @h6 id:'detailsTitle', 'Title'
          @div id: 'timeByDays'
          @div class: 'ct-chartLine ct-perfect-fourth', id: 'chartLine'

  initialize: ->
    super
    console.log 'initialize'
    @disposables = new CompositeDisposable
    that = @

    pane = atom.workspace.getBottomDock().getActivePane()

    @disposables.add pane.onDidChangeActiveItem ->
      console.log 'onDidChangeActiveItem'

    @disposables.add pane.onDidActivate ->
      console.log 'onDidActivate'
      that.update()

    atom.workspace.getCenter().observeActivePaneItem (item) ->
      if !atom.workspace.isTextEditor(item)
        return
      setTimeout ->
        that.loadLogFile item
        $('#detailsTitle').text 'Total Project Time'
        $('#fileDetailsTitle').text 'Total Project Time By Files'
        that.drawChart projectLog, 'days'
      , 100

  loadLogFile: (item) ->
    $('#fileName').text item.getFileName()
    paths = atom.project.getDirectories().map (x)-> x.path
    project = ''
    filePath = item.getPath()
    paths.forEach (path) ->
      if filePath
        match = filePath.search(path)
        if match>-1
          project = path
    fileData = fs.readFileSync logfile, 'utf-8'
    lines = fileData.split '\n'
    log = []

    lines.forEach (row)->
      row = row.split ', '
      line = {project: row[0], timestamp: parseInt(row[1]), delta: parseInt(row[2]), path: row[3]}
      log.push line
    log = log.filter (x)->
      x.delta<1000000

    timestamp = new Date
    today = new Date(timestamp.getFullYear(), timestamp.getMonth(), timestamp.getDate()).getTime()
    tomorrow = new Date(timestamp.getFullYear(), timestamp.getMonth(), timestamp.getDate()+1).getTime()
    yesterday = new Date(timestamp.getFullYear(), timestamp.getMonth(), timestamp.getDate()-1).getTime()
    lastWeek = new Date(timestamp.getFullYear(), timestamp.getMonth(), timestamp.getDate()-7).getTime()
    lastMonth = new Date(timestamp.getFullYear(), timestamp.getMonth()-1, timestamp.getDate()).getTime()

    fileLog = log.filter (x)-> x.path==filePath

    totalFileTime =  fileLog.map (x)-> x.delta
    .reduce (acc,cur)->
      acc+cur
    , 0

    $('#totalFileTime').text convertMsToTime totalFileTime
    todayFileTime = fileLog.filter (x)-> x.timestamp<tomorrow && x.timestamp>=today
    .map (x)-> x.delta
    .reduce (acc,cur)->
      acc+cur
    , 0

    $('#todayFileTime').text convertMsToTime todayFileTime

    yesterdayFileTime = fileLog.filter (x)-> x.timestamp<today && x.timestamp>=yesterday
    .map (x)-> x.delta
    .reduce (acc,cur)->
      acc+cur
    , 0

    $('#yesterdayFileTime').text convertMsToTime yesterdayFileTime

    lastWeekFileTime = fileLog.filter (x)-> x.timestamp<today && x.timestamp>=lastWeek
    .map (x)-> x.delta
    .reduce (acc,cur)->
      acc+cur
    , 0

    $('#lastWeekFileTime').text convertMsToTime lastWeekFileTime

    lastMonthFileTime = fileLog.filter (x)-> x.timestamp<today && x.timestamp>=lastMonth
    .map (x)-> x.delta
    .reduce (acc,cur)->
      acc+cur
    , 0

    $('#lastMonthFileTime').text convertMsToTime lastMonthFileTime

    projectLog = log.filter (x)-> x.project==project

    totalProjectTime = projectLog.map (x)-> x.delta
    .reduce (acc,cur)->
      acc+cur
    , 0

    $('#totalProjectTime').text convertMsToTime totalProjectTime

    todayProjectTime = projectLog.filter (x)-> x.timestamp<tomorrow && x.timestamp>=today
    .map (x)-> x.delta
    .reduce (acc,cur)->
      acc+cur
    , 0

    $('#todayProjectTime').text convertMsToTime todayProjectTime

    yesterdayProjectTime = projectLog.filter (x)-> x.timestamp<today && x.timestamp>=yesterday
    .map (x)-> x.delta
    .reduce (acc,cur)->
      acc+cur
    , 0

    $('#yesterdayProjectTime').text convertMsToTime yesterdayProjectTime

    lastWeekProjectTime = projectLog.filter (x)-> x.timestamp<today && x.timestamp>=lastWeek
    .map (x)-> x.delta
    .reduce (acc,cur)->
      acc+cur
    , 0

    $('#lastWeekProjectTime').text convertMsToTime lastWeekProjectTime

    lastMonthProjectTime = projectLog.filter (x)-> x.timestamp<today && x.timestamp>=lastMonth
    .map (x)-> x.delta
    .reduce (acc,cur)->
      acc+cur
    , 0

    $('#lastMonthProjectTime').text convertMsToTime lastMonthProjectTime

    projectFilesTotalTime = projectLog.reduce (accumulator, currentValue, index, array)->
      path = currentValue.path.replace currentValue.project+'/', ''
      if accumulator[path]==undefined
        accumulator[path]=currentValue.delta
      else
        accumulator[path]=currentValue.delta+accumulator[path]
      return accumulator
    , {}

  update: ->
    pane = atom.workspace.getBottomDock().getActivePane()
    height = pane.parent.element.clientHeight-$('#timeByDays').height()-$('#trackerButtons').height()-30
    lineChartOptions.height = height
    if lineChart
      lineChart.update lineChartData, lineChartOptions
    else
      lineChartData = {
        labels: [],
        series: [
          []
        ]
      }
      lineChart = new Chartist.Line '.ct-chartLine', lineChartData, lineChartOptions
    if pieChart
      pieChart.update pieChartData, pieChartOptions
    else
      pieChartData = {
        series: [20, 10, 30, 40]
      }
      pieChart = new Chartist.Pie '.ct-chartPie', pieChartData, pieChartOptions
  drawChart: (data, bins)->
    timeByBins = data.reduce (accumulator, currentValue, index, array)->
      date = new Date(currentValue.timestamp)
      day = date.getDate()
      month = date.getMonth()
      year = date.getFullYear()
      hour = date.getHours();
      if bins=='hours'
        key = new Date(year, month, day, hour).getTime()
      if bins=='days'
        key = new Date(year, month, day).getTime()
      if accumulator[key]==undefined
        accumulator[key]=currentValue.delta
      else
        accumulator[key]=currentValue.delta+accumulator[key]
      return accumulator
    ,{}
    timeByBins = Object.keys(timeByBins).map (key) ->
        return {'x': key, 'y': timeByBins[key]}

    timeByBinsText = timeByBins.map (x)->
      date = new Date(parseInt(x.x))
      if bins=='hours'
        bin = moment(date).format('MMM D HH')
      if bins=='days'
        bin = moment(date).format('MMM D')
      return bin + ': '+convertMsToTime x.y
    .join ', '

    $('#timeByDays').text timeByBinsText

    #values = timeByBins.map (x)->x.value
    #labels = timeByBins.map (x)->x.date

    lineChartData = {
      series: [
        data: timeByBins.map (value)-> return {'x': value.x, 'y': value.y/1000/60}
      ]
    }

    timeByFiles = data.reduce (accumulator, currentValue, index, array)->
      key=currentValue.path.replace currentValue.project+'/', ''
      if accumulator[key]==undefined
        accumulator[key]=currentValue.delta
      else
        accumulator[key]=currentValue.delta+accumulator[key]
      return accumulator
    ,{}
    timeByFiles = Object.keys(timeByFiles).map (key) ->
        return {value: timeByFiles[key], key: key}
    timeByFilesSum = timeByFiles.reduce (acc, cur)->
      return acc+cur.value
    ,0
    timeByFiles = timeByFiles.filter (element, index, array)->
      percent = Math.round(element.value / timeByFilesSum * 100)
      if percent>1
        return true
      else
        return false
    timeByFilesText = timeByFiles.map (x)->
      return x.key+': '+convertMsToTime x.value
    .join ', \n'
    $('#fileDetailsData').html timeByFilesText
    pieChartData = {series:timeByFiles.map (key)->key.value}

    @update()

  showTotalProjectTimeChart: ->
    #console.log('pressed showTotalProjectTimeChart')
    $('#detailsTitle').text 'Total Project Time'
    $('#fileDetailsTitle').text 'Total Project Time By Files'
    @drawChart projectLog, 'days'

  showTodayProjectTimeChart: ->
    $('#detailsTitle').text 'Today Project Time'
    $('#fileDetailsTitle').text 'Today Project Time By Files'
    log = projectLog.filter (x)-> x.timestamp<tomorrow && x.timestamp>=today
    @drawChart log, 'hours'

  showYesterdayProjectTimeChart: ->
    $('#detailsTitle').text 'Yesterday Project Time'
    $('#fileDetailsTitle').text 'Yesterday Project Time By Files'
    log = projectLog.filter (x)-> x.timestamp<today && x.timestamp>=yesterday
    @drawChart log, 'hours'

  showLastWeekProjectTimeChart: ->
    $('#detailsTitle').text 'Last Week Project Time'
    $('#fileDetailsTitle').text 'Last Week Project Time By Files'
    log = projectLog.filter (x)-> x.timestamp<today && x.timestamp>=lastWeek
    @drawChart log, 'days'

  showLastMonthProjectTimeChart: ->
    $('#detailsTitle').text 'Last Month Project Time'
    $('#fileDetailsTitle').text 'Last Month Project Time By Files'
    log = projectLog.filter (x)-> x.timestamp<today && x.timestamp>=lastMonth
    @drawChart log, 'days'

  showTotalFileTimeChart: ->
    $('#detailsTitle').text 'Total File Time'
    $('#fileDetailsTitle').text ''
    @drawChart fileLog, 'days'

  showTodayFileTimeChart: ->
    $('#detailsTitle').text 'Today File Time'
    $('#fileDetailsTitle').text ''
    log = fileLog.filter (x)-> x.timestamp<tomorrow && x.timestamp>=today
    @drawChart log, 'hours'

  showYesterdayFileTimeChart: ->
    $('#detailsTitle').text 'Yesterday File Time'
    $('#fileDetailsTitle').text ''
    log = fileLog.filter (x)-> x.timestamp<today && x.timestamp>=yesterday
    @drawChart log, 'hours'

  showLastWeekFileTimeChart: ->
    $('#detailsTitle').text 'Last Week File Time'
    $('#fileDetailsTitle').text ''
    log = fileLog.filter (x)-> x.timestamp<today && x.timestamp>=lastWeek
    @drawChart log, 'days'

  showLastMonthFileTimeChart: ->
    $('#detailsTitle').text 'Last Month File Time'
    $('#fileDetailsTitle').text ''
    log = fileLog.filter (x)-> x.timestamp<today && x.timestamp>=lastMonth
    @drawChart log, 'days'

  getTitle: ->
     return 'Time tracker info'

  getURI: ->
    return 'atom://stats-info-panel'

  getDefaultLocation: ->
    return 'bottom'

  getAllowedLocations: ->
    return ['left', 'right', 'bottom']
