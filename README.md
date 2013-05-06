# brewtus

TUS Server Protocol 0.2 Implementation
http://www.tus.io/protocols/resumable-upload.html

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

## License
[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).
