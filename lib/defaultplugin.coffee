
uuid = require "node-uuid"
sanitize = require "sanitize-filename"


# creates name of the created file
exports.getFileId = (req) ->
  if req.params.filename
    return sanitize(req.params.filename)
  else
    return uuid.v1()


# validate if the chunk is correct
exports.validateChunk = (req, info) ->
  return null  # no checks: assume tcp transport is reliable
