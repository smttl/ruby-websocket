require 'faye/websocket'
require 'thread'
require 'redis'
require 'json'
require 'erb'

module ChatDemo
  class ChatBackend
    KEEPALIVE_TIME = 15 # in seconds
    CHANNEL        = "chat-demo"

    def initialize(app)
      @app     = app
      @clients = []
    end

    def call(env)
      if Faye::WebSocket.websocket?(env)
        #The options hash accepts a ping option which sends a ping to each active connection every X number of seconds. Heroku will terminate the connection if it is idle for 55 seconds.
        ws = Faye::WebSocket.new(env, nil, {ping: KEEPALIVE_TIME })
        #open gets invoked when a new connection to the server happens
        ws.on :open do |event|
          p [:open, ws.object_id]
          @clients << ws
        end

        #message gets invoked when a WebSockets message is received by the server
        ws.on :message do |event|
          p [:message, event.data]
          # @clients.each {|client| client.send(sanitize(event.data)) }
          @clients.each {|client| client.send(event.data) }
        end

        #close gets invoked when the client closes the connection
        ws.on :close do |event|
          p [:close, ws.object_id, event.code, event.reason]
          @clients.delete(ws)
          ws = nil
        end

        # Return async Rack response
        ws.rack_response

      else
        @app.call(env)
      end
    end

    private
    def sanitize(message)
      json = JSON.parse(message)
      json.each {|key, value| json[key] = ERB::Util.html_escape(value) }
      JSON.generate(json)
    end
  end
end
