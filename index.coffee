
fs = require 'fs'
path = require 'path'
cors = require 'cors'

controllers = require "./lib/controllers"


corsOpts =
  methods: ["HEAD", "PATCH", "POST", "OPTIONS", "GET"]
  allowedHeaders: [
    "Origin", "X-Requested-With", "Content-Type", "Accept",
    "Final-Length", "Offset", "Authorization"
  ]
  exposedHeaders: ["Location", "Offset"]


exports.initApp = (app) ->

  filesDir = process.env.FILESDIR || path.join(__dirname, 'files')
  if not fs.existsSync(filesDir)
    fs.mkdirSync(filesDir)
  serverString = process.env.SERVERSTRING || 'BrewTUS/0.1'

  app.use (req, res, next) ->
    res.setHeader("Server", serverString)
    res.locals.FILESDIR = filesDir
    next()

  app.use cors(corsOpts)

  app.get("/:id", controllers.getFile)
  app.post("/files", controllers.createFile)
  app.head("/files/:id", controllers.headFile)
  app.patch("/files/:id", controllers.patchFile)


exports.serveTest = (app) ->
  app.get("up.html", controllers.testUploadPage)
