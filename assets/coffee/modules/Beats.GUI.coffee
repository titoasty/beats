BEATS       = require 'Beats'
dat         = require 'dat-gui'
loadBuffers = require 'loadBuffers'

BEATS.GUI = class GUI

	constructor: (@beats) ->

		@output = @beats.analyser
		@gui = new dat.GUI()

		@assets  =
			buffers: {}

		@buffers =
			music : @beats.media.src

		@controls = document.querySelector '.controls'

		@graphKeys       = document.querySelector '.graph-keys'
		@graphKeysCanvas = @graphKeys.querySelector 'canvas'
		@keysByTime      = []
		@currentKey      = @beats.keys[ 0 ]

		@graphSpectrum       = document.querySelector '.graph-spectrum'
		@graphSpectrumCanvas = @graphSpectrum.querySelector 'canvas'

		@track       = document.querySelector '.track'
		@trackCanvas = @track.querySelector 'canvas'
		@track.addEventListener 'mousedown', (event) => @moveTo event

		@progress = document.querySelector '.progress'
		@time     = @progress.querySelector '.time'

		@resize()

		## Draw grid
		grids = document.querySelectorAll '.grid'

		for i in [ 0...grids.length ]

			linesCount = ( i + 1 ) * 20

			for j in [ 0..linesCount ]

				line = document.createElement 'div'

				if j % 10 == 0
					line.className = "line blue"
					if j % 20 == 0 then line.className = "line white"
				else line.className = "line"

				line.style.top = ( 100 / linesCount ) * j + "%"
				grids[ i ].appendChild line

		## Draw track
		loadBuffers @buffers, @assets, =>
			@buffer = @assets.buffers.music
			@updateTrack()

		## Show player controls
		@media = @beats.input.mediaElement
		@media.className = 'audio'

		@initializeSequences()
		@initializeOutputs()
		@initializeKeys()

		@controls.appendChild @media

		@updateGUI()

		startTime = performance.now()
		@oldTime  = startTime

		frameRate = 30
		@interval = 1000 / frameRate

		addEventListener 'resize', @resize, true

	changeOutput: (output) ->

		@output = output
		@beats.output.disconnect()
		@output.connect @beats.destination
		@beats.output = @output

	resample: (width, audioData) ->

		# http://stackoverflow.com/questions/22073716/create-a-waveform-of-the-full-track-with-web-audio-api
		resampled = new Float64Array width * 6

		i = j = 0
		buckIndex = 0

		min   = 1e6
		max   = -1e6
		value = 0
		res   = 0

		sampleCount = audioData.length

		## First pass for mean
		i = 0
		while i < sampleCount

			## In which bucket do we fall ?
			buckIndex = 0 | width * i / sampleCount
			buckIndex *= 6

			## Positive or negative ?
			value = audioData[ i ]
			if value > 0
				resampled[ buckIndex ] += value
				resampled[ buckIndex + 1 ] += 1

			else if value < 0
				resampled[ buckIndex + 3 ] += value
				resampled[ buckIndex + 4 ] += 1

			if value < min then min = value
			if value > max then max = value

			i++

		## Compute mean now
		i = j = 0
		while i < width

			if resampled[ j + 1] != 0
				resampled[ j ] /= resampled[ j + 1 ]

			if resampled[ j + 4 ] != 0
				resampled[ j + 3 ] /= resampled[ j + 4 ]

			i++
			j += 6

		## Second pass for mean variation  ( variance is too low)
		i = 0
		while i < audioData.length

			## In which bucket do we fall ?
			buckIndex = 0 | width * i / audioData.length
			buckIndex *= 6

			## Positive or negative ?
			value = audioData[ i ]
			if value > 0
				resampled[ buckIndex + 2 ] += Math.abs resampled[ buckIndex ] - value
			else if value < 0
				resampled[ buckIndex + 5 ] += Math.abs resampled[ buckIndex + 3 ] - value

			i++

		## Compute mean variation / variance now
		i = j = 0
		while i < width

			if resampled[ j + 1 ]
				resampled[ j + 2 ] /= resampled[ j + 1 ]

			if resampled[ j + 4 ]
				resampled[ j + 5 ] /= resampled[ j + 4 ]

			i++
			j += 6

		return resampled

	initializeOutputs: ->

		## Draw output container
		@outputs    = []
		@values     = []
		@levels     = []
		@thresholds = []
		@circles    = []

		template = @controls.querySelector '.template'
		for i in [ 0...@beats.keys.length ]

			output = template.cloneNode true
			output.className = "output"

			name = output.querySelector '.name'
			name.innerText = @beats.keys[ i ].name
			@controls.appendChild output

			@outputs[ @outputs.length++ ]       = output
			@values[ @values.length++ ]         = output.querySelector '.value'
			@levels[ @levels.length++ ]         = output.querySelector '.level'
			@thresholds[ @thresholds.length++ ] = output.querySelector '.threshold'
			@circles[ @circles.length++ ]       = output.querySelector '.circle'

	initializeSequences: ->

		sequences = @track.querySelector '.sequences'
		template  = @track.querySelector '.template'
		positions = @beats.sequencer.positions

		for i in [ 0...positions.length ]

			position = positions[ i ] / @media.duration

			sequence = template.cloneNode true
			sequence.className = "sequence"
			sequence.style.transform = 'translateX(' + position * 100 + "%)"

			value = sequence.querySelector '.value'
			value.innerText = positions[ i ]

			name = sequence.querySelector '.name'
			name.innerText = @beats.sequencer.names[ i ]
			sequences.appendChild sequence

	initializeKeys: ->

		@keys = []

		template = @graphSpectrum.querySelector '.template'
		for i in [ 0...@beats.keys.length ]

			key = template.cloneNode true
			@keys[ i ] = key

			name = key.querySelector '.name'
			name.innerText = @beats.keys[ i ].name
			@graphSpectrum.appendChild key

		@updateKeys()

	moveTo: (event) ->

		progress = ( event.clientX - @track.offsetLeft ) / @track.clientWidth
		@media.currentTime = progress * @media.duration

	updateTrack: =>

		if !@buffer? then return

		width = @trackCanvas.width

		context = @trackCanvas.getContext '2d'
		resampledData = @resample width, @buffer.getChannelData 0

		context.translate 0.5, @trackCanvas.clientHeight * 0.5
		context.scale 1, 100
		i = 0

		while i < width

			j = i * 6

			# update from positiveAvg - variance to negativeAvg - variance
			context.strokeStyle = '#ffffff'
			context.beginPath()
			context.moveTo i, resampledData[ j ] - ( resampledData[ j + 2 ] )
			context.lineTo i, resampledData[ j + 3 ] + resampledData[ j + 5 ]
			context.stroke()

			# update from positiveAvg - variance to positiveAvg + variance
			context.beginPath()
			context.moveTo i, resampledData[ j ] - ( resampledData[ j + 2 ] )
			context.lineTo i, resampledData[ j ] + resampledData[ j + 2 ]
			context.stroke()

			# update from negativeAvg + variance to negativeAvg - variance
			context.beginPath()
			context.moveTo i, resampledData[ j + 3 ] + resampledData[ j + 5 ]
			context.lineTo i, resampledData[ j + 3 ] - ( resampledData[ j + 5 ] )
			context.stroke()
			i++

	updateOutputs: ->

		for i in [ 0...@beats.keys.length ]

			key = @beats.keys[ i ]

			if key.threshold?
				@thresholds[ i ].style.height = 100 * key.currentThreshold + "%"
				@thresholds[ i ].style.display = "block"
			else
				@thresholds[ i ].style.display = "none"

			if key.active

				@outputs[ i ].style.opacity = 1.0
				@levels[ i ].style.height = 100 * key.value + "%"
				@circles[ i ].style.transform = 'translateX(-25%) scale(' + key.value + ')'

			else

				@outputs[ i ].style.opacity = 0.2

			@values[ i ].innerText = key.value.toFixed 3

	updateKeys: =>

		## Draw keys
		for i in [ 0...@keys.length ]

			key = @keys[ i ]
			values = @beats.keys[ i ]

			if values.active then key.className = "key active"
			else key.className = "key"

			x = values.start * @levelSize
			y = ( 1 - values.max ) * @graphSpectrumCanvas.height

			width  = ( values.end - values.start ) * @levelSize
			height = ( values.max - values.min ) * @graphSpectrumCanvas.height

			key.style.height    = height  + 'px'
			key.style.width     = width  + 'px'
			key.style.transform = 'translate(' + x + 'px,' + y + 'px)'

	updateProgress: ->

		progress = @media.currentTime / @media.duration
		@progress.style.transform = 'translateX(' + progress * 100 + '%)'
		@time.innerText = @media.currentTime.toFixed 3

	updateGraphKeys: ->

		context = @graphKeysCanvas.getContext '2d'
		context.clearRect 0, 0, @graphSpectrumCanvas.width, @graphSpectrumCanvas.height

		context.strokeStyle = "#5AAAFF"

		if @keysByTime.length >= @waveCountKeys then @keysByTime.shift()

		if !@currentKey? then return
		@keysByTime[ @keysByTime.length++ ] = @currentKey.value

		context.beginPath()
		context.setLineDash []

		for i in [ 0...@waveCountKeys ]

			height = -@keysByTime[ i ] * @graphKeysCanvas.height + @graphKeysCanvas.height
			context.lineTo i * @waveSizeKeys, height

		context.stroke()

		if !@currentKey.threshold? then return

		## Threshold
		context.beginPath()
		context.strokeStyle = "white"

		height = -@currentKey.threshold * @graphKeysCanvas.height + @graphKeysCanvas.height
		context.setLineDash [ 5, 5 ]
		context.moveTo 0, height
		context.lineTo @graphKeysCanvas.width, height
		context.stroke()

	updateGraphSpectrum: ->

		context = @graphSpectrumCanvas.getContext '2d'
		context.clearRect 0, 0, @graphSpectrumCanvas.width, @graphSpectrumCanvas.height

		for i in [ 0...@levelCount ]

			context.fillStyle = '#5AAAFF'

			if @spectrum[ i ] > 0

				x = i * @levelSize
				height = @output.spectrum[ i ] *  @graphSpectrumCanvas.height

				offset = 0.2
				gap    = @levelSize * offset
				width  = @levelSize * ( 1 - offset )

				y = @graphSpectrumCanvas.height - height
				context.fillRect x, y, width, height


		context.beginPath()

		context.strokeStyle = "rgba(200, 200, 200, 0.95)"

		halfHeight = @graphSpectrumCanvas.height * 0.5
		for i in [ 0...@waveCount ]

			height = @output.waveform[ i ] * halfHeight + halfHeight
			context.lineTo i * @waveSize, height

		context.stroke()

	updateGUI: ->

		modulators = [ null ]
		modulatorsFolder = @gui.addFolder 'Modulators'

		for i in [ 0...@beats.modulators.length ]

			modulator = @beats.modulators[ i ]
			modulatorFolder = modulatorsFolder.addFolder modulator.name

			modulators[ modulators.length++ ] = modulator.name

			filter = modulator.filter
			modulator.output = false

			that = @

			modulatorsNeedsUpdate = (boolean) ->

				name = that.graphSpectrum.querySelector '.container-name span'

				for i in [ 0...that.beats.modulators.length ]
					if @object.name == that.beats.modulators[ i ].name

						if boolean
							name.innerText = @object.name
							that.changeOutput @object.analyser
						else
							that.changeOutput that.beats.analyser
							name.innerText = 'Main analyser'
							that.beats.modulators[ i ].output = false

			output = modulatorFolder.add( modulator, 'output' )
			output.name('output')
			output.listen().onChange( modulatorsNeedsUpdate )

			frequency = modulatorFolder.add( filter.frequency, 'value', 0, 40000 )
			frequency.name('frequency')
			frequency.listen().onChange( modulatorsNeedsUpdate )

			Q = modulatorFolder.add( filter.Q, 'value', 0, 10)
			Q.name('Q')
			Q.listen().step( 1 ).onChange( modulatorsNeedsUpdate )

			gain = modulatorFolder.add( filter.gain, 'value', 0, 10 ).name('gain')
			gain.name('gain')
			gain.listen().step( 1 ).onChange( modulatorsNeedsUpdate )


		keysFolder = @gui.addFolder 'Keys'
		for i in [ 0...@beats.keys.length ]

			key = @beats.keys[ i ]
			keyFolder = keysFolder.addFolder key.name

			keyFolder.add( key, 'active', ).listen().onChange( @updateKeys )
			keyFolder.add( key, 'start', 0, @levelCount ).listen().step( 1 ).onChange( @updateKeys )
			keyFolder.add( key, 'end'  , 0, @levelCount ).listen().step( 1 ).onChange( @updateKeys )
			keyFolder.add( key, 'min'  , 0, 1 ).listen().step( 0.01 ).onChange( @updateKeys )
			keyFolder.add( key, 'max'  , 0, 1 ).listen().step( 0.01 ).onChange( @updateKeys )
			keyFolder.add( key, 'modulator', modulators ).listen().onChange( @updateKeys )


			if !i then key.graph = true else key.graph = false

			that = @
			keyFolder.add( key, 'graph', ).listen().onChange( (value) ->

				for i in [ 0...that.beats.keys.length ]
					that.beats.keys[ i ].graph = false

				name = that.graphKeys.querySelector '.container-name span'
				if value
					that.currentKey = @object
					name.innerText = @object.name
					@object.graph = true
				else
					that.currentKey = null
					name.innerText = 'Nothing selected'
			)

	update: ->

		newTime = performance.now()
		delta   = newTime - @oldTime

		## Control draw loop frame rate
		if delta > @interval
			@oldTime = newTime - ( delta % @interval )
			@updateGraphKeys()

		@spectrum = @output.spectrum
		@waveform = @output.waveform

		if @waveform? and @spectrum? and !@beats.media.paused
			@updateGraphSpectrum()
			@updateOutputs()
			@updateProgress()

	resize: =>

		WIDTH  = window.innerWidth
		HEIGHT = window.innerHeight

		@graphSpectrumCanvas.width  = @graphSpectrum.clientWidth
		@graphSpectrumCanvas.height = @graphSpectrum.clientHeight

		@trackCanvas.width  = @track.clientWidth
		@trackCanvas.height = @track.clientHeight

		@graphKeysCanvas.width  = @graphKeysCanvas.parentNode.clientWidth
		@graphKeysCanvas.height = @graphKeysCanvas.parentNode.clientHeight

		@levelCount = @beats.levelCount || @beats.analyser.frequencyData.length
		@levelSize = Math.round @graphSpectrumCanvas.width / @levelCount

		@waveCount = @beats.analyser.timeDomainData.length
		@waveSize  = @graphSpectrumCanvas.width / @waveCount

		@waveCountKeys = 300
		@waveSizeKeys  = @graphKeysCanvas.width / @waveCountKeys

		@updateTrack()



