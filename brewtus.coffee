http = require "http"
url = require "url"
fs = require "fs"
path = require "path"
util = require "util"
events = require "events"

uuid = require "node-uuid"
winston = require "winston"


upload = require "./upload"


setup = new events.EventEmitter()
config = {}


#testUploadPage
testUploadPage = (res) ->
    fs.readFile path.join(__dirname , "/up.html"), "utf8", (err, data) ->
        res.setHeader "Content-Type", "text/html"
        return httpStatus res, 200, "Ok", data  unless err
        
        winston.error util.inspect err
        httpStatus res, 405, "Not Allowed"

#Required for Browser Uploads
optionsFile = (req, res, query, matches) ->
    httpStatus res, 200, "Ok"
 
#GET MUST return Content-Length == Final-Length
getFile = (req, res, query, matches) ->
    fileId = matches[2]
    return httpStatus res, 404, "Not Found" unless fileId?

    u = upload.Upload(config, fileId)
    status = u.load()
    if status.error?
        return httpStatus res, status.error[0],  status.error[1]

    res.setHeader "Content-Length", status.info.finalLength
    u.stream().pipe(res)


#Implements 6.1. File Creation
createFile = (req, res, query, matches) ->
    fileId = matches[2]

    return httpStatus res, 400, "Invalid Request" if fileId?

    #6.1.3.1. POST
    #The request MUST include a Final-Length header
    return httpStatus res, 400, "Final-Length Required" unless req.headers["final-length"]?

    finalLength = parseInt req.headers["final-length"]

    #The value MUST be a non-negative integer.
    return httpStatus res, 400, "Final-Length Must be Non-Negative" if isNaN finalLength || finalLength < 0

    #generate fileId
    fileId =  uuid.v1()
    status = upload.Upload(config, fileId).create(finalLength)

    if status.error?
        return httpStatus res, status.error[0],  status.error[1]

    res.setHeader "Location", "http://#{config.host}:#{config.port}/files/#{fileId}"
    httpStatus res, 201, "Created"

#Implements 5.3.1. HEAD
headFile = (req, res, query, matches) ->
    fileId = matches[2]
    return httpStatus res, 404, "Not Found" unless fileId?

    status = upload.Upload(config, fileId).load()
    if status.error?
        return httpStatus res, status.error[0],  status.error[1]
    info = status.info

    res.setHeader "Offset", info.offset
    res.setHeader "Connection", "close"
    httpStatus res, 200, "Ok"

#Implements 5.3.2. PATCH
patchFile = (req, res, query, matches) ->
    fileId = matches[2]
    return httpStatus res, 404, "Not Found" unless fileId?

    filePath = path.join config.files, fileId
    return httpStatus res, 404, "Not Found" unless fs.existsSync filePath

    #All PATCH requests MUST use Content-Type: application/offset+octet-stream.
    return httpStatus res, 400, "Content-Type Required" unless req.headers["content-type"]?
 
    return httpStatus res, 400, "Content-Type Invalid" unless req.headers["content-type"] is "application/offset+octet-stream"


    #5.2.1. Offset
    return httpStatus res, 400, "Offset Required" unless req.headers["offset"]?

    #The value MUST be an integer that is 0 or larger
    offsetIn = parseInt req.headers["offset"]
    return httpStatus res, 400, "Offset Invalid" if isNaN offsetIn or offsetIn < 0

    return httpStatus res, 400, "Content-Length Required" unless req.headers["content-length"]?

    contentLength = parseInt req.headers["content-length"]
    return httpStatus res, 400, "Invalid Content-Length" if isNaN contentLength or contentLength < 1


    u = upload.Upload(config, fileId)
    status = u.load()
    if status.error?
        return httpStatus res, status.error[0],  status.error[1]
    info = status.info

    return httpStatus res, 400, "Invalid Offset" if offsetIn > info.offset

    #Open file for writing
    ws = fs.createWriteStream filePath, {flags: "r+", start: offsetIn}

    unless ws?
        winston.error "unable to create file #{filePath}"
        return httpStatus res, 500, "File Error"

    info.offset = offsetIn
    info.state = "patched"
    info.patchedOn = Date.now()
    info.bytesReceived = 0 

    req.pipe ws

    req.on "data", (buffer) ->
        winston.debug "old Offset #{info.offset}"
        info.bytesReceived += buffer.length
        info.offset +=  buffer.length
        winston.debug "new Offset #{info.offset}"
        return httpStatus res, 500, "Exceeded Final-Length" if info.offset > info.finalLength
        return httpStatus res, 500, "Exceeded Content-Length" if info.received > contentLength   

    req.on "end", ->
        httpStatus res, 200, "Ok" unless res.headersSent
        u.save(info)

    ws.on "close", ->
        winston.info "closed the file stream #{fileId}"
        winston.debug util.inspect res


    ws.on "error", (e) ->
        winston.error "closed the file stream #{fileId} #{util.inspect e}"
        #Send response
        return httpStatus res, 500, "File Error"

httpStatus = (res, statusCode, reason, body='') ->
    res.writeHead statusCode, reason
    res.end(body)

ALLOWED_METHODS = ["HEAD", "PATCH", "POST", "OPTIONS", "GET"]
ALLOWED_METHODS_STR = ALLOWED_METHODS.join ","
PATTERNS = [
    {match:/files(\/(.+))*/, HEAD:headFile, PATCH:patchFile, POST:createFile, OPTIONS:optionsFile, GET:getFile}
]
route = (req, res) ->
    winston.debug util.inspect req
    return httpStatus res, 405, "Not Allowed" unless req.method in ALLOWED_METHODS

    #Get request param handling
    parsed = url.parse req.url, true
    urlPath = parsed.pathname

    winston.info "URLPATH: #{urlPath}"
    #Add Test Route
    if urlPath is "/" 
        return httpStatus res, 405, "Not Allowed"  unless req.method is "GET"
        return testUploadPage res

    return httpStatus res, 405, "Not Allowed" unless urlPath.length > 1

    query = parsed.query
    for pattern in PATTERNS
        matches = urlPath.match pattern.match
        winston.debug "#{util.inspect matches}"
        if matches?
             return pattern[req.method](req, res, query, matches)
    return httpStatus res, 405, "Not Allowed"

commonHeaders = (res) ->
    res.setHeader "Server", config.server
    res.setHeader "Access-Control-Allow-Origin", "*"
    res.setHeader "Access-Control-Allow-Methods", ALLOWED_METHODS_STR
    res.setHeader "Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Final-Length, Offset"
    res.setHeader "Access-Control-Expose-Headers", "Location"
 
tusHandler = (req, res) ->
    commonHeaders(res)
    route req, res

setupLogger = (logDir, logFileName, logRotateSize) ->

    #setup logger
    try
        fs.mkdirSync logDir
    catch error
        if error? and error.code isnt "EEXIST"
            winston.error util.inspect error
            process.exit 1

    #Rotate Log
    opts = {flags: 'a', encoding: 'utf8', bufferSize: 0}
    logfw = fs.createWriteStream logFileName, opts
    logfw.once "open", (logfd) ->
        fs.watchFile logFileName, (cur, prev) ->
            if cur.size > logRotateSize
                fs.truncate(logfd, 0)
                winston.warn "Rotated logfile"

    process.on 'uncaughtException', (err) ->
        winston.error "uncaught exception #{util.inspect err}"
        logfw.once "drain", -> process.exit 1

    winston.add winston.transports.File, {stream: logfw, level: config.logLevel, json: false, timestamp: true}
    winston.remove winston.transports.Console

#load config, create files folder
initApp = (args) ->

    fileNamePrefix = path.basename __filename, path.extname __filename

    #my configuration -> scriptname.json
    configFileName = path.join __dirname, "#{fileNamePrefix}.json"
    winston.debug "Reading #{configFileName}"
    try
        config = require configFileName
    catch error
        winston.error "Failed to load #{configFileName}"
    winston.debug util.inspect config

    #setup logging
    logDir = config.logDir or path.join __dirname, "logs"
    logFileName = path.join logDir, "#{fileNamePrefix}.log"
    setupLogger logDir, logFileName, config.logRotateSize

    #Create files directory
    try
        fs.mkdirSync config.files
    catch error
        if error? and error.code isnt "EEXIST"
            winston.error util.inspect error
            process.exit 1

    setup.emit "setupComplete"

startup = (args) ->
    setup.once "setupComplete", -> 
        server = http.createServer tusHandler
        server.timeout = 30000 #servers SHOULD use a 30 second timeout
        server.listen config.port
        winston.info "Server running at http://#{config.host}:#{config.port}/" 

    initApp args

startup process.argv
