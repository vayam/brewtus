fs = require "fs"
mkdirp = require "mkdirp"
winston = require "winston"
path = require "path"
util = require "util"

#Stores File Info in json
class Upload
  constructor: (config, fileId) ->
    @fileId = fileId
    @filePath = path.join config.files, fileId
    _folder = path.dirname(@filePath)
    mkdirp.sync _folder unless fs.existsSync _folder
    @infoPath = path.resolve "#{@filePath}.json"
    @info = null

  create: (finalLength) ->
    try
      fs.closeSync(fs.openSync(@filePath, 'w'))
    catch error
      winston.error util.inspect error
      return {error: [500, "Create Failed"]}

    try
      info =
        finalLength: finalLength
        state: "created"
        createdOn: Date.now()
        offset: 0
      fs.writeFileSync @infoPath, JSON.stringify info
      @info = info
    catch error
      winston.error util.inspect error
      return {error: [500, "Create Failed - Metadata"]}
    return {info: @info}

  save: ->
    try
      fs.writeFileSync @infoPath, JSON.stringify @info
    catch error
      winston.error util.inspect error
      return {error: [500, "Save Failed - Metadata"]}
    return {info: @info}

  load: ->
    return {error: [404, "File Not Found"]} unless fs.existsSync @filePath

    try
      @info = JSON.parse(fs.readFileSync @infoPath)
    catch error
      winston.error util.inspect error
      return {error: [404, "Not Found - Metadata"]}

    #Force Update offset
    try
      stat = fs.statSync @filePath
      @info.offset = stat.size
    catch e
      winston.error "file error #{fileId} #{util.inspect e}"
      return {error: [500, "File Load Error"]}

    return {info: @info}

  stream: ->
    return fs.createReadStream @filePath


exports.Upload = (config, fileId) -> new Upload config, fileId

exports.getFileUrl = (fileId, req) ->
  reqpath = req.originalUrl.split('?')[0]
  if reqpath[reqpath.length-1] == '/'
    return "#{req.protocol}://#{req.headers.host}#{reqpath}#{fileId}"
  else
    return "#{req.protocol}://#{req.headers.host}#{reqpath}/#{fileId}"
