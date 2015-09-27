fs = require 'fs'
url = require 'url'
path = require 'path'
spawn = require('child_process').spawn

request = require 'request'
cheerio = require 'cheerio'
async = require 'async'

rankingURL = 'http://www.pixiv.net/ranking.php?mode=daily&content=illust'
maxRank = 50
maxPagePerManga = 5
currentDate = null
files = []

async.waterfall [
	(done) ->
		console.log "Getting #{rankingURL}..."
		request rankingURL, done

	(response, body, done) ->
		return done(new Error 'Status not OK') if response.statusCode isnt 200

		console.log 'Extracting URLs...'
		$ = cheerio.load body
		$ranks = $('.ranking-item').filter -> parseInt($(@).data('rank')) <= maxRank
		currentDate = $('.sibling-items').eq(0).find('.current').text()

		$ranks.each ->
			$rank = $ this
			rank = parseInt $rank.data 'rank'
			thumbnail = url.parse $rank.find('._thumbnail').data 'src'
			isManga = $rank.find('.work').hasClass 'multiple'

			###
			Parse pathname into parameters

			Example:
			URL: http://i3.pixiv.net/c/240x480/img-master/img/2015/07/16/00/15/45/51435066_p0_master1200.jpg

			mark: c
			size: 240x480
			region: img-master
			type: img
			year: 2015
			month: 07
			day: 16
			hour: 00
			minute: 15
			second: 45
			filename: 51435066_p0_master1200.jpg
			###
			[_, mark, size, region, type, year, month, day, hour, minute, second, filename] =
				thumbnail.pathname.split '/'

			###
			Parse filename into parametes

			Example:
			filename: 51435066_p0_master1200.jpg

			id: 51435066
			page: p0
			type: master1200
			extension: jpg
			###
			[id, page, imagetype, extension] = filename.split /[_\.]/

			# Rebuild filename (without extension and page)
			filename = "#{id}"

			# Rebuild pathname (without extension and page)
			region = 'img-original'
			pathname = ['', region,  type, year, month, day, hour, minute, second, filename].join '/'
			thumbnail.pathname = pathname

			# Rebuild URL
			originalURL = url.format thumbnail

			files.push
				filename: filename
				url: originalURL
				id: id
				page: page
				isManga: isManga

		done null

	(done) ->
		fs.exists path.join(__dirname, "images/#{currentDate}"), (exists) ->
			if exists
				done null
			else
				fs.mkdir path.join(__dirname, "images/#{currentDate}"), done

	(done) ->
		fs.readdir path.join(__dirname, "images/#{currentDate}"), done

	(dirfiles, done) ->
		files = files.filter (file) -> not dirfiles.some (dirfile) -> dirfile[...file.filename.length] is file.filename

		async.eachLimit files, 5, (file, done) ->
			console.log "Getting #{file.id}..."

			if file.isManga
				pages = [0...maxPagePerManga]
			else
				pages = [0]

			async.detectSeries pages, (page, resultIn) ->
				async.detectSeries ['jpg', 'png', 'gif', 'jpeg'], (extension, resultIn) ->
					URL = "#{file.url}_p#{page}.#{extension}"
					console.log "Trying #{URL}..."

					request
						url: URL
						encoding: null
						headers:
							Cookie: 'pixiv_embed=pix'
					, (error, response, body) ->
						return done(error) if error
						return resultIn(false) if response.statusCode isnt 200

						fs.writeFile path.join(__dirname, "images/#{currentDate}/#{file.filename}_p#{page}.#{extension}"), body, (error) ->
							if error
								done error
							else
								console.log "Saved #{file.filename}_p#{page}.#{extension}"
								resultIn true
				, (result) ->
					if result is false and page is 0
						console.error new Error "Suitable extension for #{file.filename} not found..."

					resultIn not result
			, (result) ->
				done null
		, done

	(done) ->
		fs.readdir path.join(__dirname, "images/#{currentDate}"), done

	(dirfiles, done) ->
		fullpaths = dirfiles.map (dirfile) -> path.join __dirname, "images/#{currentDate}", dirfile

		pixivwall = spawn path.join(__dirname, 'pixivwall'), fullpaths
		pixivwall.stdout.on 'data', (data) ->
			data.toString().split('\n').forEach (line) ->
				console.log "pixivwall: #{line}"
		pixivwall.on 'close', (code) ->
			if code isnt 0
				done new Error "pixivwall exit with code #{code}"
			else
				done null
], (error) ->
	if error
		throw error
	else
		console.log 'Operation successfull'
