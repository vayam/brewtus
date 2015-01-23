
require('coffee-script/register');
var bodyParser = require('body-parser');

var port = process.env.PORT || 1080;

var app = require('express')();
app.use(bodyParser.json());

require('./index').initApp(app)

app.listen(port, function() {
  console.log('gandalf does magic on ' + port);
});
