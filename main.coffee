fs = require 'fs'
path = require 'path'
Deferred = require 'when'

module.exports = (scssDir, tmplDir) ->
	regSelector = new RegExp '(\\.|#)([\\w\\s-_]*?)({|\\s|,)', 'ig'
	selectorsUsed = {}

	readRecursiveDir = (dir, done) ->
		results = []
		fs.readdir dir, (err, list) ->
			pending = null

			if err
				return done(err)

			pending = list.length

			if !pending
				return done null, results

			list.forEach (file) ->
				file = "#{dir}/#{file}"
				fs.stat file, (err, stat) ->
					if stat && stat.isDirectory()
						readRecursiveDir file, (err, res) ->
							results = results.concat res
							if !--pending
								done null, results
					else
						results.push file
						if !--pending
							done null, results

	readTmplDir = (dirList, callback) ->
		result = []
		promises = []

		if !Array.isArray dirList
			dirList = [dirList]

		dirList.forEach (dir) ->
			dfd = Deferred.defer()
			promises.push dfd.promise

			readRecursiveDir dir, (err, files) ->
				if err
					callback err
				else
					result = result.concat files
					dfd.resolve()

		Deferred.all(promises).then ->
			callback null, result


	readRecursiveDir scssDir, (err, files) ->
		promises = []
		files.forEach (file) ->
			filePath = path.resolve scssDir, file
			if !fs.lstatSync(filePath).isDirectory()
				dfd = Deferred.defer()
				promises.push dfd.promise
				fs.readFile filePath, (err, content) ->
					scss = content.toString()
					selectors = scss.match regSelector

					if Array.isArray selectors
						selectors.forEach (selector) ->
							selector = selector.replace(/\.|#|,|{/ig, '').trim()
							if selector && isNaN(parseInt selector) && (!selector.match(/^[\w\d]*$/) || selector.length != 6)
								selectorsUsed[selector] = 
									file: filePath
									usedCount: 0
					dfd.resolve()

		Deferred.all(promises).then ->
			promises = []
			readTmplDir tmplDir, (err, files) ->
				files.forEach (file) ->
					dfd = Deferred.defer()
					promises.push dfd.promise
					fs.readFile file, (err, content) ->
						tmpl = content.toString()
						for selector, selectorItem of selectorsUsed
							if tmpl.indexOf(selector) != -1
								selectorItem.usedCount++
						dfd.resolve()

				Deferred.all(promises).then ->
					for selector, selectorItem of selectorsUsed
						if selectorItem.usedCount == 0
							console.log "#{selector}\n#{selectorItem.file}\n======================"


