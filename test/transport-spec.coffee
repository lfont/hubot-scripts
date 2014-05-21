should    = require('chai').should()
transport = require '../transport'

describe 'transport', ->

  describe 'the regexp', ->

    it 'should match a well formatted message', ->
      robot =
        respond: (regexp, callback) ->
          (regexp.test 'transport bastille ').should.be.true

      transport robot

    it 'should not match an unknown message', ->
      robot =
        respond: (regexp, callback) ->
          (regexp.test 'trans basti ').should.be.false

      transport robot

  describe 'the response', ->

    searchTransport = (station, done) ->
      responses = []

      robot =
        respond: (regexp, call) ->
          msg =
            match: [ '', station ]
            reply: (message) -> responses.push message

          # The module needs some time to initialize.
          setTimeout ( -> call msg ), 3000

      # We should wait for all services responses.
      setTimeout ( -> done responses.join '\n' ), 5000

      transport robot

    describe 'given a query for the RATP station: Bastille', ->
      response = ''

      before (done) ->
        searchTransport 'bastille', (res) ->
          response = res
          done()

      it 'should contain the Metro 1\'s timetable', ->
        response.should.have.string 'Metro 1'

      it 'should contain the Metro 5\'s timetable', ->
        response.should.have.string 'Metro 5'

      it 'should contain the Metro 8\'s timetable', ->
        response.should.have.string 'Metro 8'

      it 'should not contain a Transilien timetable', ->
        response.should.have.string 'Transilien No Match'

    describe 'given a query for the Transilien station: Pont De L\'Alma', ->
      response = ''

      before (done) ->
        searchTransport 'pont de l\'alma', (res) ->
          response = res
          done()

      it 'should contain the RER C\'s timetable', ->
        response.should.have.string 'RER C'
