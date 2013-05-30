# brewtus

[TUS Protocol 0.2.1](http://www.tus.io/protocols/resumable-upload.html) Server Implementation


## Configuration
edit brewtus.json
```js
{
 "host":"127.0.0.1",
 "port":8080, 
 "server": "BrewTUS/0.1",
 "files":"files"
 }
```

## Install
```
npm install
```

## Run

```
coffee -c brewtus.coffee
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
