
fs = require "fs"
path = require "path"
uuid = require "node-uuid"

upload = require "./upload"


exports.testUploadPage = (req, res, next) ->
  fs.readFile path.join(__dirname , "/up.html"), "utf8", (err, data) ->
    res.set
      'Content-Type': 'text/html'
      'Content-Length': data.length
    res.send(data)


#GET MUST return Content-Length == Final-Length
exports.getFile = (req, res, next) ->
  return res.status(404).send("Not Found") unless req.params.id?

  u = upload.Upload({files: res.locals.FILESDIR}, req.params.id)
  status = u.load()
  if status.error?
    return res.status(status.error[0]).send(status.error[1])

  res.setHeader "Content-Length", status.info.finalLength
  u.stream().pipe(res)


#Implements 6.1. File Creation
exports.createFile = (req, res, next) ->

  #6.1.3.1. POST
  #The request MUST include a Final-Length header
  unless req.headers["final-length"]?
    return res.status(400).send("Final-Length Required")

  finalLength = parseInt req.headers["final-length"]

  #The value MUST be a non-negative integer.
  if isNaN finalLength || finalLength < 0
    return res.status(400).send("Final-Length Must be Non-Negative")

  #generate fileId
  fileId =  uuid.v1()
  status = upload.
    Upload({files: res.locals.FILESDIR}, fileId).create(finalLength)

  if status.error?
    return res.status(status.error[0]).send(status.error[1])

  loc = "#{req.protocol}://#{req.headers.host}/files/#{fileId}"
  res.setHeader "Location", loc
  res.status(201).send("Created")


#Implements 5.3.1. HEAD
exports.headFile = (req, res, next) ->
  return res.status(404).send("Not Found") unless req.params.id

  status = upload.Upload({files: res.locals.FILESDIR}, req.params.id).load()
  if status.error?
    return res.status(status.error[0]).send(status.error[1])
  info = status.info

  res.setHeader "Offset", info.offset
  res.setHeader "Connection", "close"
  res.send("Ok")


#Implements 5.3.2. PATCH
exports.patchFile = (req, res, next) ->
  return res.status(404).send("file id not provided") unless req.params.id

  filePath = path.join res.locals.FILESDIR, req.params.id
  return res.status(404).send("Not Found") unless fs.existsSync filePath

  #All PATCH requests MUST use Content-Type: application/offset+octet-stream.
  unless req.headers["content-type"]?
    return res.status(400).send("Content-Type Required")

  unless req.headers["content-type"] is "application/offset+octet-stream"
    return res.status(400).send("Content-Type Invalid")

  #5.2.1. Offset
  return res.status(400).send("Offset Required") unless req.headers["offset"]?

  #The value MUST be an integer that is 0 or larger
  offsetIn = parseInt req.headers["offset"]
  if isNaN offsetIn or offsetIn < 0
    return res.status(400).send("Offset Invalid")

  unless req.headers["content-length"]?
    return res.status(400).send("Content-Length Required")

  contentLength = parseInt req.headers["content-length"]
  if isNaN contentLength or contentLength < 1
    return res.status(400).send("Invalid Content-Length")

  u = upload.Upload({files: res.locals.FILESDIR}, req.params.id)
  status = u.load()
  if status.error?
    return res.status(status.error[0]).send(status.error[1])
  info = status.info

  return res.status(400).send("Invalid Offset") if offsetIn > info.offset

  #Open file for writing
  ws = fs.createWriteStream filePath, {flags: "r+", start: offsetIn}

  unless ws?
    return res.status(500).send("unable to create file #{filePath}")

  info.offset = offsetIn
  info.state = "patched"
  info.patchedOn = Date.now()
  info.bytesReceived = 0

  req.pipe ws

  req.on "data", (buffer) ->
    info.bytesReceived += buffer.length
    info.offset +=  buffer.length
    if info.offset > info.finalLength
      return res.status(500).send("Exceeded Final-Length")
    if info.received > contentLength
      return res.status(500).send("Exceeded Content-Length")

  req.on "end", ->
    res.send("Ok") unless res.headersSent
    u.save(info)

  req.on "close", ->
    ws.end()

  ws.on "error", (e) ->
    #Send response
    res.status(500).send("File Error")
