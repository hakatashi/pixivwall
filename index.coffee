fs = require 'fs-extra'
url = require 'url'
path = require 'path'
spawn = require('child_process').spawn

request = require 'request'
cheerio = require 'cheerio'
async = require 'async'
imageSize = require 'image-size'
LineWrapper = require 'stream-line-wrapper'

batteryStatus = require './battery-status'

rankingURL = 'http://www.pixiv.net/ranking.php?mode=daily&content=illust'
maxRank = 50
maxPagePerManga = 5
currentDate = null
files = []
imageSizes = {}

threshold = 580

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
			pathname = ['', region, type, year, month, day, hour, minute, second, filename].join '/'
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
				path.extname(file) is extension
		.filter (file) -> path.basename(file).indexOf('-') is -1

		dirfiles = dirfiles.map (file) -> path.join __dirname, "images/#{currentDate}", file

		async.map dirfiles, (file, done) ->
			# Catch errors while detecting imagesizes... They just aren't needed actually
			try
				imageSize file, done
			catch error
				# Assume to be big enough not to need to resize it
				done null,
					width: Infinity
					height: Infinity
		, (error, imageSizeList) ->
			if error then return done error
			imageSizes = imageSizeList.reduce (previous, current, index) ->
				previous[dirfiles[index]] = current
				return previous
			, imageSizes
			done null

	(done) ->
		async.waterfall [
			(done) ->
				fs.readdir path.join(__dirname, "images/#{currentDate}"), done

			(dirfiles, done) ->
				# Convert to full paths
				fullpaths = dirfiles
				.filter (file) -> file.match /^\d+_p\d+\.\w+$/
				.map (dirfile) -> path.join __dirname, "images/#{currentDate}", dirfile

				pixivwall = spawn path.join(__dirname, 'pixivwall'), fullpaths

				prefixer = new LineWrapper prefix: 'pixivwall: '
				pixivwall.stdout.pipe(prefixer).pipe(process.stdout)

				pixivwall.on 'close', (code) ->
					if code isnt 0
						done new Error "pixivwall exit with code #{code}"
					else
						console.log 'Wallpaper successfully set!'
						done null
		], done

	# We successfully set wallpaper with normal quality of image. Now improve quality of image using waifu2x!

	# Crop Image with 16:9 by Imagemagick
	(done) ->
		# Skip if battery is not charging
		if batteryStatus() isnt 1
			console.log 'Battery is not charging. Skip scaling...'
			return done null

		async.forEachOfLimit imageSizes, 1, (size, image, done) ->
			return done null if size.width is Infinity

			imageFile = path.parse image
			imageFile.base = "#{imageFile.name}-crop.png"
			croppedImage = path.format imageFile

			imageFile.base = "#{imageFile.name}-2x.png"
			scaledImage = path.format imageFile

			newSize =
				width: Math.min size.width, Math.ceil size.height * (16 / 9)
				height: Math.min size.height, Math.ceil size.width / (16 / 9)

			# Skip if the image is big enough not to scale
			return done null if newSize.width > threshold

			offsetX = Math.floor (size.width - newSize.width) / 2
			offsetY = Math.floor (size.height - newSize.height) / 2

			# http://www.imagemagick.org/script/command-line-processing.php#geometry
			geometry = "#{newSize.width}x#{newSize.height}+#{offsetX}+#{offsetY}"

			async.waterfall [
				(done) -> fs.access croppedImage, (error) -> done null, not error

				(exists, done) ->
					if exists
						console.log "Skip cropping because #{path.basename croppedImage} already exists"
						return done null

					# Skip scaling if target dimension is totally the same with the original
					if newSize.width is size.width and newSize.height is size.height
						console.log "Copying #{path.basename image} to #{path.basename croppedImage}"
						return fs.copy image, croppedImage, done

					console.log "Cropping #{path.basename image} to #{path.basename croppedImage} with #{geometry}"

					# "convert" is namespace collision with the Windows system tool "convert.exe".
					# To avoid unexpected behavior with this, please create bat file named "im-convert.bat"
					# that refers and symlinks to your imagemagick directory.
					convert = spawn 'cmd', [
						'/c', 'im-convert'
						'-crop', geometry
						image
						croppedImage
					]

					prefixer = new LineWrapper prefix: 'convert: '
					convert.stdout.pipe(prefixer).pipe(process.stdout)

					convert.on 'close', (code) ->
						if code isnt 0
							done new Error "Imagemagick exit with code #{code}"
						else
							done null

				(done) -> fs.access scaledImage, (error) -> done null, not error

				(exists, done) ->
					if exists
						console.log "Skip scaling because #{path.basename scaledImage} already exists"
						return done null

					console.log "Scaling #{path.basename croppedImage} to #{path.basename scaledImage}"

					if imageFile.ext is 'jpg' or imageFile.ext is 'jpeg'
						mode = 'noise_scale'
					else
						mode = 'scale'

					waifu2x = spawn 'waifu2x-converter', [
						'--jobs', '1'
						'--model_dir', 'C:\\Program Files\\waifu2x-converter\\models'
						'--mode', mode
						'--input_file', croppedImage
						'--output_file', scaledImage
					]

					prefixer = new LineWrapper prefix: 'waifu2x: '
					waifu2x.stdout.pipe(prefixer).pipe(process.stdout)

					waifu2x.on 'close', (code) ->
						if code isnt 0
							done new Error "waifu2x-converter exit with code #{code}"
						else
							done null

			], done

		, done

	# Now, set wallpaper again to usefully use scaled images
	(done) ->
		async.waterfall [
			(done) ->
				fs.readdir path.join(__dirname, "images/#{currentDate}"), done

			(dirfiles, done) ->
				# Create rainbow table to store the images whose quality is the highest in the directory
				imageTable = Object.create null

				for file in dirfiles
					if match = file.match /^(\d+_p\d+)(:?-(\d+)x)?\.(\w+)$/
						[_, id, _, scale, ext] = match
						scale = parseInt(scale, 10) or 1

						if not imageTable[id] or
						imageTable[id].scale < scale or
						(ext is 'png' and imageTable[id].ext isnt 'png')
							imageTable[id] =
								file: file
								scale: scale
								ext: ext

				# Convert to full paths
				fullpaths = Object.keys imageTable
				.map (id) -> path.join __dirname, "images/#{currentDate}", imageTable[id].file

				pixivwall = spawn path.join(__dirname, 'pixivwall'), fullpaths
				pixivwall.stdout.on 'data', (data) ->
					data.toString().split('\n').forEach (line) ->
						console.log "pixivwall: #{line}"
				pixivwall.on 'close', (code) ->
					if code isnt 0
						done new Error "pixivwall exit with code #{code}"
					else
						console.log 'Wallpaper successfully set!'
						done null
		], done

], (error) ->
	if error
		throw error
	else
		console.log 'Operation successfull'
