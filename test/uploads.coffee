
should = require('should')
fs = require('fs')
request = require('request').defaults({timeout: 5000})


module.exports = (db, addr) ->

  hoy = {}
  location = null
  samplefile = [1 .. 1000].join(',')

  it "must not create a new file without final-length header", (done) ->
    options =
      url: "#{addr}/"
      method: 'POST',
      headers:
        'Content-Type': 'application/json'
        'Content-Length': 2

    req = request options, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 400
      should.not.exist res.headers['location']
      done()

    req.write '{}'
    req.end


  it "shall create a new file with custom filename", (done) ->
    options =
      url: "#{addr}/?filename=testfile1.txt"
      method: 'POST',
      headers:
        'Content-Type': 'application/json'
        'final-length': 123

    req = request options, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 201
      should.exist res.headers['location']
      done()
    req.end


  it "shall create a new file with custom filename in subfolder", (done) ->
    options =
      url: "#{addr}/?filename=sub1/sub2/testfile1.txt"
      method: 'POST',
      headers:
        'Content-Type': 'application/json'
        'final-length': 123

    req = request options, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 201
      should.exist res.headers['location']
      done()
    req.end


  it "mustnot create a new file out of upload folder (usage ../..)", (done) ->
    options =
      url: "#{addr}/?filename=../../testfile1.txt"
      method: 'POST',
      headers:
        'Content-Type': 'application/json'
        'final-length': 123

    req = request options, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 400
      should.not.exist res.headers['location']
      done()
    req.end


  it "shall create a new file", (done) ->
    options =
      url: "#{addr}/"
      method: 'POST',
      headers:
        'Content-Type': 'application/json'
        'final-length': samplefile.length

    req = request options, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 201
      should.exist res.headers['location']
      location = res.headers['location']
      done()
    req.end


  it "shall upload first 512 bytes of sample file", (done) ->

    chunksize = 128

    _send = (curr) ->
      options =
        url: location
        method: 'PATCH',
        headers:
          'Content-Type': 'application/offset+octet-stream'
          'Content-Length': chunksize
          'Offset': curr
      req = request options, (err, res, body) ->
        return done(err) if err

        res.statusCode.should.eql 200
        if curr + chunksize >= 512
          done()
        else
          _send(curr+chunksize)

      req.write samplefile[curr..curr+chunksize-1]
      req.end

    _send(0)


  it "shall return current offset of the partial uploaded file", (done) ->
    request.head location, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 200
      should.exist res.headers['offset']
      res.headers['offset'].should.eql '512'
      done()


  it "must not PATCH when wrong content-type", (done) ->
    options =
      url: location
      method: 'PATCH',
      headers:
        'Content-Type': 'application/json'
        'Content-Length': samplefile.length - 512
        'Offset': 512
    req = request options, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 400
      done()

    req.write samplefile[512..]
    req.end


  it "must not PATCH when offset missing", (done) ->
    options =
      url: location
      method: 'PATCH',
      headers:
        'Content-Type': 'application/json'
        'Content-Length': samplefile.length - 512
    req = request options, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 400
      done()

    req.write samplefile[512..]
    req.end


  it "must not upload the rest of da file when offset wrong", (done) ->
    options =
      url: location
      method: 'PATCH',
      headers:
        'Content-Type': 'application/json'
        'Content-Length': samplefile.length - 512
        'Offset': 'wrongoffset'
    req = request options, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 400
      done()

    req.write samplefile[512..]
    req.end


  it "must not PATCH when offset bigger then current", (done) ->
    options =
      url: location
      method: 'PATCH',
      headers:
        'Content-Type': 'application/json'
        'Content-Length': samplefile.length - 512
        'Offset': 612
    req = request options, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 400
      done()

    req.write samplefile[512..]
    req.end


  it "shall upload the rest of da file", (done) ->
    options =
      url: location
      method: 'PATCH',
      headers:
        'Content-Type': 'application/offset+octet-stream'
        'Content-Length': samplefile.length - 512
        'Offset': 512
    req = request options, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 200
      done()

    req.write samplefile[512..]
    req.end


  it "shall return offset equal to file size", (done) ->
    request.head location, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 200
      should.exist res.headers['offset']
      res.headers['offset'].should.eql samplefile.length.toString()
      filename = /https?:\/\/127.0.0.1:[0-9]*\/(.*)/g.exec(location)[1]
      filename = "#{process.env.FILESDIR}/#{filename}"
      fs.readFileSync(filename).toString().should.eql samplefile
      done()


  it "shall return actual file", (done) ->
    request.get location, (err, res, body) ->
      return done(err) if err

      res.statusCode.should.eql 200
      # res.headers['content-type'].should.eql 'plain/text'
      body.should.eql samplefile
      done()
