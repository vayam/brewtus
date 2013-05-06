# brewtus

[TUS Protocol 0.2](http://www.tus.io/protocols/resumable-upload.html) Server Implementation


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

## Run

```
coffee -c brewtus.coffee
node brewtus.js
```

## Test
Get [tuspy](https://github.com/vayam/tuspy) client
```
python tuspy.py -f <file>
```

## License
[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).
