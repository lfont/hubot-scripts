# Description:
#   gets timetable for departure
#
# Dependencies:
#   "request":     "2.35.0"
#   "cheerio":     "0.16.0"
#   "easy-table":  "0.3.0"
#   "fuzzyset.js": "0.0.1"
#
# Commands:
#   hubot transport <departure> - Show timetable for <departure>
#
# Author:
#   Loïc Fontaine
#

request  = require 'request'
cheerio  = require 'cheerio'
Table    = require 'easy-table'
FuzzySet = require 'fuzzyset.js'

transilien = (departure, callback) ->
  request "http://www.transilien.com/gare/pagegare/chargerGare?nomGare=#{departure}", (err, res, body) ->
    table = new Table
    $     = cheerio.load body

    if $('#trouver_gare_bis_gare').html()
      $('#trouver_gare_bis_gare option:enabled').each () ->
        table.cell 'Transilien Best Matches', $(this).text()
        table.newRow()
    else if $('.etat_trafic').html()
      $('.etat_trafic > tr').each () ->
          $tr = $(this)
          table.cell 'Line',        $tr.find('.ligne img').attr('alt') + ' ' + $tr.find('.ligne a img').attr('alt')
          table.cell 'Time',        $tr.find('td:nth-child(3)').text().trim()
          table.cell 'Destination', $tr.find('td:nth-child(4)').text().trim()
          table.newRow()
    else
      table.cell 'Transilien No Match', 'Sorry no station match your query'
      table.newRow()

    callback table

ratpJsToJson = (js) ->
  json = js.replace   'var liste_stations_metro_domaine_reel =', ''
  json = json.replace ';', ''
  json = json.replace /,\s+\]/, ']'
  json = json.replace /'/g, '"'
  json = json.replace /(key):/g, (match, p1) -> '"' + p1 + '":'
  json = json.replace /(value):/g, (match, p1) -> '"' + p1 + '":'
  json

ratpStationsAutoComplete = (callback) ->
  fuzzyset = FuzzySet()

  request 'http://www.ratp.fr/horaires/js/liste-stations-metro-domaine-reel.js', (err, res, body) ->
    json = ratpJsToJson body
    stations = JSON.parse json
    stations.forEach (station) ->
      fuzzyset.add station.key

  fuzzyset

ratpStations = ratpStationsAutoComplete()

ratpMetroTimetable = (departure, line, callback) ->
  request "http://www.ratp.fr/horaires/fr/ratp/metro/prochains_passages/PP/#{departure}/#{line}/A", (err, res, body) ->
    table = new Table
    $     = cheerio.load body

    $('#prochains_passages table tbody tr').each () ->
      $tr = $(this)

      table.cell 'Line',        'Metro ' + line
      table.cell 'Time',        $tr.find('td').eq(1).text()
      table.cell 'Destination', $tr.find('td').eq(0).text()
      table.newRow()

    callback table

ratpMetroLines = (departure, callback) ->
  request.post(
    'http://www.ratp.fr/horaires/fr/ratp/metro',
    {
      form: {
        'metroServiceStationForm[service]': 'PP',
        'metroServiceStationForm[station]': departure
      }
    },
    (err, res, body) ->
      $ = cheerio.load body
      $('.radio_list li input').each () ->
        ratpMetroTimetable departure, ( $(this).attr 'value' ), callback)

ratp = (departure, callback) ->
  stations = ratpStations.get departure
  if stations.length == 0
    table = new Table
    table.cell 'RATP No Match', 'Sorry not station match your query'
    table.newRow()
    callback table
  else if stations.length > 1
    table = new Table
    stations.forEach (station) ->
      table.cell 'RATP Best Matches', station[1]
      table.newRow()
    callback table
  else
    ratpMetroLines stations[0][1], callback

module.exports = (robot) ->

  robot.respond /transport\s+([\S ]+)/i, (msg) ->
    departure = msg.match[1]

    transilien departure, (timetable) ->
      msg.reply '\n' + timetable.toString()

    ratp departure, (timetable) ->
      msg.reply '\n' + timetable.toString()
