socket = require('socket.io-client').connect 'http://192.168.1.34:8000'
cordell = require 'cordell'
fs = require 'fs'
fileobj = {}
cfileobj = {}
_ = require 'underscore'
sha1 = require 'sha1'
hashFile = require 'hash_file'
pather = require 'path'


socket.on 'client', (fn)->
	fn fileobj.hash(), fileobj.path()

socket.emit 'server', (hash, path)->
	cfileobj = FileObj hash, path
	ev.compare socket

socket.on 'get', (path, func)->
	fs.readFile path, 'base64', (err, data)->
		func data

FileObj = (hashobj, pathobj)->
	instance = 
		add: (hash, path, prop)->
			@hashobj[hash] ?= {}
			@hashobj[hash][path] = prop
			@pathobj[path] ?= {}
			@pathobj[path] = prop
			@pathobj[path].hash = hash
		rem: (path) ->
			hash = @pathobj[path].hash
			delete @pathobj[path]
			delete @hashobj[hash][path]
			if _.size(@hashobj[hash]) == 0 then delete @hashobj[hash]
		hash: (hash) ->
			if hash?	
				return @hashobj[hash]
			else 
				return @hashobj
		path: (path) ->
			if path?
				return @pathobj[path]
			else
				return @pathobj
		hashobj: hashobj
		pathobj: pathobj

	return instance

fileobj = FileObj {}, {}

ev =
	compare: (socket)->
		_(cfileobj.path()).each (file, path) ->
			if fileobj.path(path)?
				if cfileobj.path(path).hash != fileobj.path(path).hash
					if cfileobj.path(path).time > fileobj.path(path).time
						socket.emit 'get', path, (d)->
							fs.writeFile path, d, 'base64'
			else 
				socket.emit 'get', path, (d)->
							fs.writeFile path, d, 'base64'

	add: (path, stats, func) ->
		path = pather.relative(__dirname, path)
		#<path to file>, <file node statistics>, <callbackfunction for end od hashing>
		hashFile path, 'sha1', (err, hash) ->
			fileobj.add hash, path, {				
				time: stats.mtime.getTime()
				type: if stats.isFile() then 'file' else 'dir'
			}
			if typeof func == 'function' then func(hash)
	rem: (path) ->
		path = pather.relative(__dirname, path)
		fileobj.rem(path)
	end: (files)->
		console.log(fileobj)

(()->
	walker = cordell.walk __dirname, {}
	pos = 0
	length = -1

	walker.on 'file', (path, stats)->
		ev.add path, stats, ()->
			pos++
			if(pos == length)
				#the hashing has a delay that walker.on'end' doesn‘t know about 
				ev.end fileobj
	walker.on 'dir', ev.add
	walker.on 'error', console.log
	walker.on 'end', (files)->
		length = files.length
		if(pos == length)
			ev.end fileobj
)()

(()->
	watcher = cordell.watch __dirname, {}
	watcher.on 'add', (path, file)->
		path = pather.relative(__dirname, path)
		ev.add path, file, (hash)->
			console.log("ADDED:", path, hash)
	watcher.on 'rem', (path)->
		path = pather.relative(__dirname, path)
		ev.rem path
		console.log('DELETED:', path)
	watcher.on 'change', (path, stat) ->
		path = pather.relative(__dirname, path)
		ev.rem path
		ev.add path, stat, (hash)->
			console.log('CHANGED: ', path, hash)
)()