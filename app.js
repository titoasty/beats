var MobileDetect, app, express, http, io, morgan, path, port, server, socket;

path = require('path');

express = require('express');

morgan = require('morgan');

http = require('http');

socket = require('socket.io');

MobileDetect = require('mobile-detect');

app = express();

server = http.Server(app);

io = socket(server);

port = process.env.PORT || 8080;

app.use(express["static"](path.join(__dirname, './assets')));

app.use(morgan('dev'));

app.get('/', function(request, response, next) {
  var mobileDetect;
  mobileDetect = new MobileDetect(request.headers['user-agent']);
  if (mobileDetect.mobile()) {
    return response.sendFile(path.join(__dirname, 'assets/views/desktop/index.html'));
  } else {
    return response.sendFile(path.join(__dirname, 'assets/views/desktop/index.html'));
  }
});

server.listen(port, function() {
  return console.log('Express server listening on port ' + port);
});
