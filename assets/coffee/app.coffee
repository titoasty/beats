path    = require 'path'
express = require 'express'
morgan  = require 'morgan'
http    = require 'http'
socket  = require 'socket.io'

MobileDetect = require 'mobile-detect'

# Initialize app with Express
app    = express()
server = http.Server app
io     = socket server
port   = process.env.PORT || 8080

# --- CONFIGURATION

# Set the static files location
app.use express.static path.join __dirname, './assets'

# Log every requests to the console
app.use morgan 'dev'

# --- ROUTES

# Serve html
app.get '/', (request, response, next) ->

	mobileDetect = new MobileDetect request.headers['user-agent']

	if mobileDetect.mobile()
		response.sendFile path.join __dirname, 'assets/views/desktop/index.html'
	else
		response.sendFile path.join __dirname, 'assets/views/desktop/index.html'


# Make the http server listen on port
server.listen port, ->

	console.log 'Express server listening on port ' + port
