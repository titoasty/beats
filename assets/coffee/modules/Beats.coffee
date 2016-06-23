BEATS = {}
module.exports = BEATS


class BEATS.Interface

	constructor: ( @context, audio, parameters ) ->

		@keys       = []
		@modulators = []
		@phases     = []

		## Add a default first phase
		@phases[ 0 ] = new BEATS.Phase( 0 )

		## Initialize sequencer position
		@position = 0

		## Create audio source node
		@input = @context.createMediaElementSource( audio )

		## Load source to an audio buffer
		@loadBuffer( audio.src )

		## Default analyser
		@analyser = @context.createAnalyser()
		# @input.channelCount = 1 if parameters.mono
		@input.connect( @analyser )

		@media    = @input.mediaElement
		@duration = @media.duration
		@active   = true

		## Connect the analyser to the destination
		@destination = parameters.destination
		if @destination?

			## Connect analyser to the audio context destination
			@analyser.connect( @destination )

			## Set the analyser as output
			@output = @analyser

		@analyser.fftSize = parameters.fftSize if parameters.fftSize

		if parameters.smoothingTimeConstant
			@analyser.smoothingTimeConstant = parameters.smoothingTimeConstant

		## Create typed array to store data
		@analyser.frequencyData  = new Uint8Array( @analyser.frequencyBinCount )
		@analyser.timeDomainData = new Uint8Array( @analyser.frequencyBinCount )

		## Create typed array to store normalized data
		@analyser.normalizedFrequencyData  = new Float32Array( @analyser.frequencyBinCount )
		@analyser.normalizedTimeDomainData = new Float32Array( @analyser.frequencyBinCount )

		## Restrict level counts
		@setLevelCount( parameters.levelCount ) if parameters.levelCount?

		## Update the default analyser once on start
		@getSpectrum( @analyser, true )
		@getWaveform( @analyser, true )

		@onLoading    = parameters.onLoading
		@onProcessEnd = parameters.onProcessEnd

	setLevelCount: ( levelCount ) ->

		## Create typed array to store data, with a length equal to level count
		@levelCount      = levelCount
		@levelStep       = @analyser.frequencyBinCount / @levelCount
		@analyser.levels = new Float32Array( @levelCount )

	loadBuffer: ( url ) ->

		request = new XMLHttpRequest()
		request.open( "GET", url, true )
		request.responseType = "arraybuffer"

		onSuccess = ( buffer ) =>

			@buffer = buffer

			# Get the bpm when the array buffer is decoded
			@computeBPM()

		onError = ->

			throw new Error( "Error decoding the file " + error )
			return

		request.onload = =>

			## If the request succeed then decode audio data
			@context.decodeAudioData( request.response, onSuccess, onError )

		request.onprogress = ( event ) =>

			@onLoading?( event.loaded / event.total )

		request.onerror = ( error ) ->

			throw new Error( "Error loading the file" + error )
			return

		request.send()

	getSpectrum: ( analyser, normalized ) =>

		## Get raw data
		analyser.getByteFrequencyData( analyser.frequencyData )
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

				analyser.levels[ i ] = @getFrequency( spectrum, start, end )

			spectrum = analyser.levels

		analyser.spectrum = spectrum
		return spectrum

	getWaveform: ( analyser, normalized ) ->

		## Get raw data
		analyser.getByteTimeDomainData( analyser.timeDomainData )
		waveform = analyser.timeDomainData

		## Compute normalized values
		if normalized

			i = analyser.timeDomainData.length
			while i--
				analyser.normalizedTimeDomainData[ i ] = ( analyser.timeDomainData[ i ] - 128 ) / 128

			waveform = analyser.normalizedTimeDomainData

		analyser.waveform = waveform
		return waveform

	getFrequency: ( spectrum, start, end ) ->

		## Get the average frequency between start and end
		if end - start > 1

			## Sum up selected frequencies
			sum = 0
			for i in [ start..end ]
				sum += spectrum[ i ]

			## Divide by length
			return sum / ( end - start + 1 )

		else return spectrum[ start ]

	getMaxFrequency: ( spectrum, start, end ) ->

		max = 0
		end = start if !end?

		for i in [ start..end ]
			max = spectrum[ i ] if spectrum[ i ] > max

		return max

	computeBPM: =>

		@BPMProcessor = new BEATS.BPMProcessor( @buffer )
		@BPMProcessor.onProcessEnd = ( result ) =>

			@bpm = result
			@onProcessEnd()?

		@BPMProcessor.start()

	add: ( object ) ->

		if object instanceof BEATS.Modulator

			modulator.name = 'M|' + @modulators.length if !object.name?

			## The context is needed to create a filter and an analyser
			object.context = @context
			object.set()

			## Create a typed array to receive normalized data
			object.analyser.levels = new Float32Array( @levelCount )

			## Update the modulator analyser once when added
			@getSpectrum( object.analyser, true )
			@getWaveform( object.analyser, true )

			@input.connect( object.filter )

			## Add modulator to the interface
			@modulators[ @modulators.length++ ] = object

		if object instanceof BEATS.Key

			object.name  = 'K|' + @keys.length if !object.name?
			object.index = @keys.length

			## Add key to the interface
			@keys[ @keys.length++ ] = object

		if object instanceof BEATS.Phase

			## Add phase to the interface
			@phases[ @phases.length++ ] = object

			## Sort phases according to their time
			@phases.sort ( a, b ) =>

				return 1 if a.time > b.time
				return -1 if a.time < b.time

				return 0

			object.keys       = @keys
			object.modulators = @modulators
			object.phases     = @phases

			i = @phases.length
			@phases[ i ].index = i while i--

		## Set the first phase which contains the original values of the keys and modulators
		@phases[ 0 ].keys       = @keys
		@phases[ 0 ].modulators = @modulators
		@phases[ 0 ].phases     = @phases

		i = @keys.length
		while i--

			key    = @keys[ i ]
			values = @phases[ 0 ].values[ key.name ] = {}

			for name, value of key
				values[ name ] = value if typeof value != "function"

		i = @modulators.length
		while i--

			modulator = @modulators[ i ]
			values    = @phases[ 0 ].values[ modulator.name ] = {}

			values.active = modulator.active

			for name, parameter of modulator.filter

				if name == 'frequency' or name == 'Q' or name == 'gain'
					values[ name ] = parameter.value

	remove: ( object ) ->

		## Find the object type
		switch object.constructor.name

			when 'Modulator' then objects = @modulators
			when 'Key'       then objects = @keys
			when 'Sequencer' then objects = @sequencer
			else

				throw new Error(  'Unknown object type' )
				return

		## Find the object according to type
		i = objects.length
		while i--
			objects.splice( i, 1 ) if objects[ i ] == object

	get: ( name ) ->

		## Get object by name
		if typeof name == 'string'

			## Loop through keys
			i = @keys.length
			while i--
				return @keys[ i ] if @keys[ i ].name == name

			## Loop through modulators
			i = @modulators.length
			while i--
				return @modulators[ i ] if @modulators[ i ].name == name

		else

			throw new Error( "Can't find object named : " + name )
			return

	update: =>

		return if !@media? or @media.paused or !@active

		## Update time and progression
		@currentTime = @media.currentTime
		@progress    = @currentTime / @duration

		## Update main analyser
		@getSpectrum( @analyser, true )
		@getWaveform( @analyser, true )

		## Update modulators analyser
		i = @modulators.length
		while i--

			modulator = @modulators[ i ]
			continue if !modulator.active

			analyser = modulator.analyser

			@getSpectrum( analyser, true )
			@getWaveform( analyser, true )

		## Update keys value
		i = @keys.length
		while i--

			key = @keys[ i ]
			modulator = null

			## Check if the key needs to be modulated
			modulator = @get( key.modulator ) if key.modulator?

			## Check if the modulator exists and is active
			if modulator? and modulator.active
				spectrum = modulator.analyser.spectrum

			## Else use the default spectrum
			else spectrum = @analyser.spectrum

			## Get the average or the maximal frequency according to key type
			if key.type == "average"

				frequency = @getFrequency( spectrum, key.start, key.end )

			else if key.type == "max"

				frequency = @getMaxFrequency( spectrum, key.start, key.end )

			key.update( frequency )

		## Update sequencer
		if @phases.length > 0

			## Call current phase update callback
			@phases[ @position ].onUpdate?()

			next = @phases[ @position + 1 ]
			return if !next?

			if @currentTime >= next.time

				## Call current phase end callback
				@phases[ @position ].onComplete?()

				## Update position to switch to next phase
				@position++

				## Set keys and modulators values for the new phase
				@phases[ @position ].initialize()

				## Call new phase start callback
				@phases[ @position ].onStart?()

				## Call interface on phase change event
				@onPhaseChange?()


class BEATS.Modulator

	constructor: ( type, frequency, parameters ) ->

		## Filter property
		@type      = type
		@frequency = frequency
		@Q         = parameters.Q
		@gain      = parameters.gain

		## Modulator property
		@name   = parameters.name
		@active = parameters.active

	set: ( frequency, Q, gain ) ->

		## Create filter and analyser
		@filter   = @context.createBiquadFilter()
		@analyser = @context.createAnalyser()
		@filter.connect( @analyser )

		## Create typed array to store data
		@analyser.frequencyData  = new Uint8Array( @analyser.frequencyBinCount )
		@analyser.timeDomainData = new Uint8Array( @analyser.frequencyBinCount )

		## Create typed array to store normalized data
		@analyser.normalizedFrequencyData  = new Float32Array( @analyser.frequencyBinCount )
		@analyser.normalizedTimeDomainData = new Float32Array( @analyser.frequencyBinCount )

		@filter.type            = @type
		@filter.frequency.value = @frequency

		@filter.Q.value    = @Q if @filter.Q? and @Q?
		@filter.gain.value = @gain if @filter.gain? and @gain?


class BEATS.Key

	constructor: ( start, end, min, max, parameters ) ->

		parameters = {} if !parameters?

		@set( start, end, min, max )

		@value = 0

		@smoothness = parameters.smoothness || 1

		@delay   = parameters.delay
		@timeout = null
		@lower   = true

		@threshold = parameters.threshold
		@currentThreshold = @threshold

		@type = parameters.type || 'average'

		@name      = parameters.name
		@modulator = parameters.modulator || null
		@active    = parameters.active

		@callback = parameters.callback || null

	set: ( start, end, min, max, threshold ) ->

		@start = start if start?
		@end   = end   if end?
		@min   = min   if min?
		@max   = max   if max?

	update: ( frequency ) =>

		if !@active
			@value = 0
			return

		## Compute value according to parameters
		value = ( frequency - @min ) / ( @max - @min )

		## Constricts value
		value = Math.min( 1, Math.max( 0, value ) )

		if @smoothness <= 1 then @value = value
		else @value += ( value - @value ) * ( 1 / @smoothness )

		## Check if a callback sould be called
		return if !@threshold

		if @value >= @currentThreshold and @lower

			callback = => @lower = true
			@timeout = setTimeout( callback, @delay )
			@lower   = false

			@callback() if @callback?


class BEATS.Phase

	constructor: ( @time, @values, parameters ) ->

		@values    = {} if !@values?
		parameters = {} if !parameters?

		@name = parameters.name

		@onStart    = parameters.onStart
		@onUpdate   = parameters.onUpdate
		@onComplete = parameters.onComplete

	initialize: =>

		i = 0
		while i <= @index

			for name, values of @phases[ i ].values

				j = @keys.length
				while j--

					if @keys[ j ].name == name

						key = @keys[ j ]

						for parameter, value of values
							key[ parameter ] = value

				j = @modulators.length
				while j--

					if @modulators[ j ].name == name

						modulator = @modulators[ j ]

						for parameter, value of values

							if parameter == 'active' then modulator.active = value
							else modulator.filter[ parameter ].value = value

			i++


class BEATS.BPMProcessor

	constructor: ( buffer ) ->

		@minThreshold = 0.3
		@minPeaks     = 15

		@offlineContext = new OfflineAudioContext( 1, buffer.length, buffer.sampleRate )

		@source = @offlineContext.createBufferSource()
		@source.buffer = buffer

		## Pipe the buffer into the filter
		filter = @offlineContext.createBiquadFilter()
		filter.type = 'lowpass'
		@source.connect( filter )

		## And the filter into the offline context
		filter.connect( @offlineContext.destination )

		## Process the data when the context finish rendering
		@offlineContext.addEventListener( 'complete', @process )

	start: =>

		@source.start( 0 )
		@offlineContext.startRendering()

	process: ( event ) =>

		buffer = event.renderedBuffer

		## Get a Float32Array containing the PCM data
		data = buffer.getChannelData( 0 )

		peaks = []

		## Track a threshold volume level
		min = BEATS.Utils.getArrayMin( data )
		max = BEATS.Utils.getArrayMax( data )

		threshold = min + ( max - min )

		while peaks.length < @minPeaks and threshold >= @minThreshold
      		peaks = @getPeaksAtThreshold( data, threshold )
      		threshold -= 0.02

		if peaks.length < @minPeaks
        	throw new Error( 'Could not find enough samples for a reliable detection' )
        	return

		## Count intervals between peaks
		intervals = @identifyIntervals( peaks )
		tempos    = @groupByTempo( intervals )

		tempos.sort( ( a, b ) -> b.count - a.count )
		@onProcessEnd?( tempos[ 0 ].tempo )

	getPeaksAtThreshold: ( data, threshold ) ->

		result = []

		i = 0
		while i < data.length

			if data[ i ] > threshold
				result[ result.length++ ] = i
				i += 10000

			i++

		return result

	identifyIntervals: ( peaks ) =>

		counts = []

		peaks.forEach ( peak, index ) ->

			i = 0
			while i < 10

				interval = peaks[ index + i ] - peak

				result = counts.some ( counts ) ->
					if counts.interval == interval
						return counts.count++
					return

				if !isNaN( interval ) and interval != 0 and !result
					counts[ counts.length++ ] = interval: interval, count: 1

				i++

		return counts

	groupByTempo: ( counts ) =>

		results = []

		counts.forEach ( count ) ->

			return if count.interval == 0

			## Convert an interval to tempo
			theoreticalTempo = 60 / ( count.interval / 44100 )

			## Adjust the tempo to fit within the 90-180 BPM range
			while theoreticalTempo < 90  then theoreticalTempo *= 2
			while theoreticalTempo > 180 then theoreticalTempo /= 2

			## Round to legible integer
			theoreticalTempo = Math.round( theoreticalTempo )

			foundTempo = results.some ( result ) ->
				if result.tempo == theoreticalTempo
					return result.count += count.count

			if !foundTempo

				results[ results.length++ ] =
					tempo : theoreticalTempo
					count : count.count

		return results


BEATS.Utils =

	getArrayMin: ( data ) ->

		min = Infinity

		i = data.length
		while i--
			min = data[ i ] if data[ i ] < min

		return min

	getArrayMax: ( data ) ->

		max = -Infinity

		i = data.length
		while i--
			max = data[ i ] if data[ i ] > max

		return max

	stereoToMono: ( audioBuffer ) ->

		buffer = audioBuffer
		if buffer.numberOfChannels = 2

			## Get each audio buffer's channel
			leftChannel  = buffer.getChannelData( 0 )
			rightChannel = buffer.getChannelData( 1 )

			i = buffer.length
			while i--

				## Get the average
				mixedChannel = 0.5 * ( leftChannel[ i ] + rightChannel[ i ] )
				leftChannel[ i ] = rightChannel[ i ] = mixedChannel

			buffer.numberOfChannels = 1

		return buffer
