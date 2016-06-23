Phase = require 'gui/Phase'

module.exports = class Track

	constructor: ( @beats ) ->

		@container = document.querySelector( '.track' )
		@name      = @container.querySelector( '.container-name' )
		@progress  = document.querySelector( '.progress' )
		@time      = @progress.querySelector( '.time' )

		@nodes  = []
		@values = []

		## if scale = 1 then canvas width = container width
		@scale = 3

		@canvas  = @container.querySelector( 'canvas' )
		@context = @canvas.getContext( '2d' )

		@container.addEventListener( 'mousedown', @addListener )

		@sequences = @container.querySelector( '.sequences' )
		template  = @container.querySelector( '.template' )

		## Draw Phase
		@phases = []
		for i in [ 0...@beats.phases.length ]

			@phases[ i ] = new Phase( @beats.phases[ i ], @beats.media.duration, @, template )
			@sequences.appendChild( @phases[ i ].element )

		@sequences.addEventListener( 'scroll', @onScroll )
		@onScroll()

	set: =>

	resample: ( width, audioData ) ->

		# http://stackoverflow.com/questions/22073716/create-a-waveform-of-the-full-track-with-web-audio-api
		resampled = new Float64Array( width * 6 )

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
				resampled[ buckIndex + 2 ] += Math.abs( resampled[ buckIndex ] - value )
			else if value < 0
				resampled[ buckIndex + 5 ] += Math.abs( resampled[ buckIndex + 3 ] - value )

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

	draw: =>

		# @context.clearRect( 0, 0, @width, @height )

		if !@beats.buffer? or @done then return
		@done = true

		# Draw beat
		# offset = @width / ( @beats.bpm * ( @beats.duration / 60 ) )
		# x = 0
		# while x < @canvasWidth

		# 	x += offset * 8

		# 	beat = document.createElement( 'div' )
		# 	beat.classList.add( 'beat' )
		# 	beat.style.left = x + 'px'
		# 	@sequences.appendChild( beat )

		span = @container.querySelector( '.container-name span' )
		span.innerText = ''

		resampledData = @resample( @width * @scale, @beats.buffer.getChannelData( 0 ) )

		@context.translate( 0.5, @height * 0.5 )
		@context.scale( 1, 100 )

		i = 0
		while i < @width * @scale

			j = i * 6

			# Update from positiveAvg - variance to negativeAvg - variance
			@context.strokeStyle = '#ffffff'
			@context.beginPath()
			@context.moveTo( i, resampledData[ j ] - ( resampledData[ j + 2 ] ) )
			@context.lineTo( i, resampledData[ j + 3 ] + resampledData[ j + 5 ] )
			@context.stroke()

			# Update from positiveAvg - variance to positiveAvg + variance
			@context.beginPath()
			@context.moveTo( i, resampledData[ j ] - ( resampledData[ j + 2 ] ) )
			@context.lineTo( i, resampledData[ j ] + resampledData[ j + 2 ] )
			@context.stroke()

			# Update from negativeAvg + variance to negativeAvg - variance
			@context.beginPath()
			@context.moveTo( i, resampledData[ j + 3 ] + resampledData[ j + 5 ] )
			@context.lineTo( i, resampledData[ j + 3 ] - ( resampledData[ j + 5 ] ) )
			@context.stroke()
			i++

	onScroll: =>

		if @sequences.scrollLeft <= 10
			@container.classList.add( 'hide-left' )
		else @container.classList.remove( 'hide-left' )

		if @sequences.scrollLeft >= @sequences.scrollWidth - 10
			@container.classList.add( 'hide-right' )
		else @container.classList.remove( 'hide-right' )

	addListener: ( event ) =>

		return if @dragged

		@moveTo( event )

		@container.addEventListener( 'mousemove', @moveTo )
		@container.addEventListener( 'mouseup', @removeListener )

	removeListener: =>

		@container.removeEventListener( 'mousemove', @moveTo )
		@container.removeEventListener( 'mouseup', @removeListener )

	moveTo: ( event ) =>

		progress = ( event.clientX + @sequences.scrollLeft - @container.offsetLeft ) / @canvas.clientWidth
		@beats.media.currentTime = progress * @beats.media.duration

		i = @beats.phases.length
		while i--

			phase = @beats.phases[ i ]

			currentTime = @beats.media.currentTime
			nextPhase   = @beats.phases[ i + 1 ]
			nextTime    = if nextPhase? then nextPhase.time else @beats.duration

			if currentTime >= phase.time and currentTime <= nextTime and i != @beats.position

				@beats.phases[ i ].initialize()
				@beats.position = i

		@update() if @beats.media.paused

	update: ->

		value = @beats.media.currentTime / @beats.media.duration
		@progress.style.left = value * 100 * @scale + '%'
		@time.innerText = @beats.media.currentTime.toFixed( 3 )

		@draw()

	resize: ->

		@width  = @container.clientWidth
		@height = @container.clientHeight - @name.offsetHeight

		@canvasWidth = @width * @scale

		@canvas.height = @height
		@canvas.width = @canvasWidth

		i = @phases.length
		@phases[ i ].resize( @canvasWidth ) while i--

		@done = false
		@draw()

		@update()
		@set()
