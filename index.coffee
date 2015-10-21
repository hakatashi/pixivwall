fs = require 'fs'
url = require 'url'
path = require 'path'
spawn = require('child_process').spawn

request = require 'request'
cheerio = require 'cheerio'
async = require 'async'
imageSize = require 'image-size'

rankingURL = 'http://www.pixiv.net/ranking.php?mode=daily&content=illust'
maxRank = 50
maxPagePerManga = 5
currentDate = null
files = []
imageSizes = {}

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

						filename = path.join __dirname, "images/#{currentDate}/#{file.filename}_p#{page}.#{extension}"

						fs.writeFile filename, body, (error) ->
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

	(done) -> fs.readdir path.join(__dirname, "images/#{currentDate}"), done

	(dirfiles, done) ->
		# Filter images
		dirfiles = dirfiles.filter (file) ->
			['.jpg', '.png', '.gif', '.jpeg'].some (extension) ->
				file[-extension.length...] is extension

		dirfiles = dirfiles.map (file) -> path.join __dirname, "images/#{currentDate}", file

		async.map dirfiles, imageSize, (error, imageSizeList) ->
			if error then return done error
			imageSizes = imageSizeList.reduce (previous, current, index) ->
				previous[dirfiles[index]] = current
				return previous
			, imageSizes
			done null

	(done) ->
		i = 0
		async.whilst(
			-> i < 1
			(done) ->
				i++
				async.waterfall [
					(done) ->
						fs.readdir path.join(__dirname, "images/#{currentDate}"), done

					(dirfiles, done) ->
						# Search for largest size file for each ids
						largeImages = {}
						for dirfile in dirfiles
							if match = dirfile.match /(\d+)_p(\d+)(_crop)?_(\d+)x\..+/
								[_, id, page, crop, size] = match
								[id, page, size] = [id, page, size].map (n) -> parseInt n, 10

								if not largeImages[id]? or
								largeImages[id].size < size or
								(largeImages[id].size <= size and not largeImages[id].crop and crop)
									largeImages[id] =
										id: id
										page: page
										crop: Boolean crop
										size: size
										file: dirfile

						# Exclude images of which larger-scaled version exists
						for image of largeImages
							prefix = "#{image.id}_p#{image.page}"
							dirfiles = dirfiles.filter (file) ->
								if file[0...prefix.length] is prefix and file isnt image.file
									return false
								else
									return true

						# Convert to full paths
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
				]
		)

], (error) ->
	if error
		throw error
	else
		console.log 'Operation successfull'
