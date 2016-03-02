BEATS = {}
module.exports = BEATS

class BEATS.Interface

	constructor: (@context, audio, parameters) ->

		@keys       = []
		@modulators = []

		@input = @context.createMediaElementSource audio

		## Load source to an audio buffer
		if parameters.buffered then @loadBuffer audio.src

		## Default analyser
		@analyser = @context.createAnalyser()
		if parameters.mono then @input.channelCount = 1
		@input.connect @analyser

		@media    = @input.mediaElement
		@duration = @media.duration
		@active   = false

		## Connect the analyser to the destination
		@destination = parameters.destination
		if @destination?

			## Connect analyser to the audio context destination
			@analyser.connect @destination

			## Set the analyser as output
			@output = @analyser

		if parameters.fftSize then @analyser.fftSize = parameters.fftSize
		if parameters.smoothingTimeConstant
			@analyser.smoothingTimeConstant = parameters.smoothingTimeConstant

		## Create typed array to store data
		@analyser.frequencyData  = new Uint8Array @analyser.frequencyBinCount
		@analyser.timeDomainData = new Uint8Array @analyser.frequencyBinCount

		## Create typed array to store normalized data
		@analyser.normalizedFrequencyData  = new Float32Array @analyser.frequencyBinCount
		@analyser.normalizedTimeDomainData = new Float32Array @analyser.frequencyBinCount

		## Restrict level counts
		if parameters.levelCount? then @setLevelCount parameters.levelCount

		## Update the default analyser once on start
		@getSpectrum @analyser, true
		@getWaveform @analyser, true

	setLevelCount: (levelCount) ->

		## Create typed array to store data, with a length equal to level count
		@levelCount      = levelCount
		@levelStep       = @analyser.frequencyBinCount / @levelCount
		@analyser.levels = new Float32Array @levelCount

	stereoToMono: (audioBuffer) ->

		if audioBuffer.numberOfChannels = 2

			## Get each audio buffer's channel
			leftChannel  = audioBuffer.getChannelData 0
			rightChannel = audioBuffer.getChannelData 1

			i = audioBuffer.length
			while i--

				## Get the average
				mixedChannel = 0.5 * ( leftChannel[ i ] + rightChannel[ i ] )
				leftChannel[ i ] = rightChannel[ i ] = mixedChannel

			audioBuffer.numberOfChannels = 1

	loadBuffer: (url) ->

		request = new XMLHttpRequest()
		request.open "GET", url, true
		request.responseType = "arraybuffer"

		onSuccess = (buffer) => @buffer = buffer
		onError   = -> console.log 'Error decoding the file ' + error

		request.onload = =>

			## If the request succeed, decode audio data
			@context.decodeAudioData request.response, onSuccess, onError

		request.onerror = (error) -> console.log 'Error loading the file' + error
		request.send()

	getSpectrum: (analyser, normalized) =>

		## Get raw data
		analyser.getByteFrequencyData analyser.frequencyData
		spectrum = analyser.frequencyData

		## Compute normalized values
		if normalized

			i = analyser.frequencyData.length
			while i--
				analyser.normalizedFrequencyData[ i ] = analyser.frequencyData[ i ] / 256

			spectrum = analyser.normalizedFrequencyData

		## Compute sampled values
		if @levelCount?

			i = @levelCount
			while i--

				start = i * @levelStep
				end   = ( i + 1 ) * @levelStep - 1

				analyser.levels[ i ] = @getFrequency spectrum, start, end

			spectrum = analyser.levels

		analyser.spectrum = spectrum
		return spectrum

	getWaveform: (analyser, normalized) ->

		## Get raw data
		analyser.getByteTimeDomainData analyser.timeDomainData
		waveform = analyser.timeDomainData

		## Compute normalized values
		if normalized

			i = analyser.timeDomainData.length
			while i--
				analyser.normalizedTimeDomainData[ i ] = ( analyser.timeDomainData[ i ] - 128 ) / 128

			waveform = analyser.normalizedTimeDomainData

		analyser.waveform = waveform
		return waveform

	getFrequency: (spectrum, start, end) ->

		## Get the average frequency between start and end
		if end - start > 1

			## Sum up selected frequencies
			sum = 0
			for i in [ start..end ]
				sum += spectrum[ i ]

			## Divide by length
			return sum / ( end - start + 1 )

		else return spectrum[ start ]

	getMaxFrequency: (spectrum, start, end) ->

		max = 0
		if !end? then end = start

		for i in [ start..end ]
			if spectrum[ i ] > max then max = spectrum[ i ]

		return max

	add: (object) ->

		if object instanceof BEATS.Modulator

			if !object.name? then modulator.name = 'M' + @modulators.length

			## The context is needed to create a filter and an analyser
			object.context = @context
			object.set()

			## Create a typed array to receive normalized data
			object.analyser.levels = new Float32Array @levelCount

			## Update the modulator analyser once when added
			@getSpectrum object.analyser, true
			@getWaveform object.analyser, true

			@input.connect object.filter

			## Add modulator to the interface
			@modulators[ @modulators.length++ ] = object

		if object instanceof BEATS.Key

			if !object.name? then object.name = 'K' + @keys.length

			## Add key to the interface
			@keys[ @keys.length++ ] = object

		if object instanceof BEATS.Sequencer

			object.time     = @media.currentTime
			object.duration = @media.duration

			names = object.names
			for i in [0...names.length]

				if !names[ i ]? then names[ i ] = "S" + i

			## Add sequencer to the interface
			@sequencer = object

	remove: (object) ->

		## Find the object type
		switch object.constructor.name

			when 'Modulator' then objects = @modulators
			when 'Key' then objects = @keys
			when 'Sequencer' then objects = @sequencer
			else

				console.log 'Unknown object type'
				return

		## Find the object according to type
		i = objects.length
		while i--
			if objects[ i ] == object then objects.splice i, 1

	get: (name) ->

		## Get object by name
		if typeof name == 'string'

			## Loop through keys
			i = @keys.length
			while i--
				if @keys[ i ].name == name then return @keys[ i ]

			## Loop through modulators
			i = @modulators.length
			while i--
				if @modulators[ i ].name == name then return @modulators[ i ]

		else return

	update: =>

		if !@media? or @media.paused or !@active then return

		## Update time and progression
		@currentTime = @media.currentTime
		@progress    = @currentTime / @duration

		## Update main analyser
		@getSpectrum @analyser, true
		@getWaveform @analyser, true

		## Update modulators analyser
		i = @modulators.length
		while i--

			modulator = @modulators[ i ]
			if !modulator.active then continue

			analyser = modulator.analyser

			@getSpectrum analyser, true
			@getWaveform analyser, true

		## Update keys value
		i = @keys.length
		while i--

			key = @keys[ i ]
			modulator = null

			## Check if the key needs to be modulated
			if key.modulator? then modulator = @get key.modulator

			## Check if the modulator exists and is active
			if modulator? and modulator.active then spectrum = modulator.analyser.spectrum

			## Else use the default spectrum
			else spectrum = @analyser.spectrum

			## Get the average or the maximal frequency according to key type
			if key.type == "average"
				frequency = @getFrequency spectrum, key.start, key.end

			else if key.type == "max"
				frequency = @getMaxFrequency spectrum, key.start, key.end

			key.update frequency

		## Update sequencer with current time
		if @sequencer? then @sequencer.update @currentTime

class BEATS.Modulator

	constructor: (type, frequency, parameters) ->

		## Filter property
		@type      = type
		@frequency = frequency
		@Q         = parameters.Q
		@gain      = parameters.gain

		## Modulator property
		@name   = parameters.name
		@active = parameters.active

	set: (frequency, Q, gain) ->

		## Create necessary nodes
		@filter   = @context.createBiquadFilter()
		@analyser = @context.createAnalyser()
		@filter.connect @analyser

		## Create typed array to store data
		@analyser.frequencyData  = new Uint8Array @analyser.frequencyBinCount
		@analyser.timeDomainData = new Uint8Array @analyser.frequencyBinCount

		## Create typed array to store normalized data
		@analyser.normalizedFrequencyData  = new Float32Array @analyser.frequencyBinCount
		@analyser.normalizedTimeDomainData = new Float32Array @analyser.frequencyBinCount

		@filter.type            = @type
		@filter.frequency.value = @frequency
		if @filter.Q? and @Q? then @filter.Q.value = @Q
		if @filter.gain? and @gain? then @filter.gain.value = @gain

class BEATS.Key

	constructor: (start, end, min, max, parameters) ->

		@set start, end, min, max
		if !parameters? then parameters = {}

		@value    = 0
		@friction = parameters.friction

		@delay   = parameters.delay
		@timeout = null
		@lower   = true

		@threshold = parameters.threshold
		@currentThreshold = @threshold

		@type = parameters.type || 'average'

		@name      = parameters.name
		@modulator = parameters.modulator || null
		@active    = parameters.active

		if parameters.callback? then @callback = parameters.callback

	set: (start, end, min, max) ->

		@start = start
		@end   = end
		@min   = min
		@max   = max

	update: (frequency) =>

		if !@active
			@value = 0
			return

		## Compute value according to parameters
		value = ( frequency - @min ) / ( @max - @min )

		## Constricts value
		value = Math.min 1, Math.max 0, value

		## Smooth value
		if @friction then @value += ( value - @value ) * @friction
		else @value = value

		## Check if callback should be call
		if !@threshold then return

		if @value >= @currentThreshold and @lower

			callback = => @lower = true
			@timeout = setTimeout callback, @delay
			@lower   = false

			if @callback? then @callback()

class BEATS.Sequencer

	constructor: (parameters) ->

		sequences = parameters.sequences

		## Add a starting point at 0
		sequences.unshift [ 0 ]

		## Sequencer callbacks
		@onChange = parameters.onChange

		## Sequences positions
		@positions = []
		@names     = []

		## Sequences callbacks
		@onStartCallbacks    = []
		@onUpdateCallbacks   = []
		@onCompleteCallbacks = []

		for i in [ 0...sequences.length ]

			sequence = sequences[ i ]

			positions  = sequence[ 0 ]
			parameters = sequence[ 1 ] || {}

			@positions[ @positions.length++ ] = positions
			@names[ @names.length++ ]         = parameters.name

			@onStartCallbacks[ @onStartCallbacks.length++ ]       = parameters.onStart
			@onUpdateCallbacks[ @onUpdateCallbacks.length++ ]     = parameters.onUpdate
			@onCompleteCallbacks[ @onCompleteCallbacks.length++ ] = parameters.onComplete

		@index = 0

	update: (currentTime) ->

		if @onUpdateCallbacks[ @index ]? then @onUpdateCallbacks[ @index ]()

		if currentTime >= @positions[ @index + 1 ]

			if @onCompleteCallbacks[ @index ]? then @onCompleteCallbacks[ @index ]()

			@index++

			if @onStartCallbacks[ @index ]? then @onStartCallbacks[ @index ]()

			if @onChange? then @onChange()
