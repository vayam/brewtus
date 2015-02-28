
uuid = require "node-uuid"
sanitize = require "sanitize-filename"


# creates name of the created file
exports.getFileId = (req) ->
  if req.query.filename
    parts = req.query.filename.split('/')
    for p in parts
      p = sanitize(p)
    return parts.join('/')
  else
    return uuid.v1()


# validate if the chunk is correct
exports.validateChunk = (req, info) ->
  return null  # no checks: assume tcp transport is reliable
