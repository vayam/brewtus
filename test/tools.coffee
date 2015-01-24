
request = require('request').defaults({timeout: 5000})


###
Util for sending reqs with JSON content type.
###
exports.makeReq = (method, url, headers, body, cb) ->
  rheaders = headers
  if method in ["GET", "DELETE", "HEAD"]
    return request {url: url, method: method, headers: rheaders}, body

  sBody = JSON.stringify(body)
  rheaders['Content-Type'] = 'application/json'
  rheaders['Content-Length'] = sBody.length

  options =
    url: url
    method: method,
    headers: headers
  req = request options, cb
  req.write sBody
  req.end
