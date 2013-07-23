# brewtus

[TUS Protocol 0.2.1](http://www.tus.io/protocols/resumable-upload.html) Server Implementation


## Configuration
edit brewtus.json
```js
{
	"host": "192.168.1.117",
	"port": 8080, 
	"server": "BrewTUS/0.1",
	"files": "files",
	"logDir": "logs",
	"logRotateSize": 10485760,
	"logLevel": "info"
}
```
- Allowed [log levels](https://github.com/flatiron/winston#using-logging-levels): debug, info, warn, error
- LogRotateSize: 10MB default

## Install
```
npm install
```

## Run

```
coffee -c *.coffee
node brewtus.js
```

## Test/Try out

Browser (Tested with Chrome 27/Firefox 21/IE 10/Safari 6)
```
http://127.0.0.1:8080/
```

or

Command line 
Get [tuspy](https://github.com/vayam/tuspy) client
```
python tuspy.py -f <file>
```

## License
[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).
