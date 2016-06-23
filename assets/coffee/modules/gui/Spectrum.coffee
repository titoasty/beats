TweenMax = require 'gsap'
require 'Draggable'

Key = require 'gui/Key'
colors = require 'gui/colors'

module.exports = class Spectrum

	constructor: ( @beats, @changeOutput ) ->

		@container     = document.querySelector( '.graph-spectrum' )
		@graphControls = @container.querySelector( '.graph-spectrum-controls' )
		@grid          = @container.querySelector( '.grid' )
		@canvas        = @container.querySelector( 'canvas' )
		@context       = @canvas.getContext( '2d' )

		@buttons = [ @graphControls.querySelector( '.active' ) ]
		@current = @buttons[ 0 ]

		## Add control to show waveform or not
		button        = @container.querySelector( '.button-waveform' )
		@showWaveform = false

		button.classList.add( 'active' ) if @showWaveform

		button.addEventListener 'click', ( event ) =>

			if event.target.classList.contains( 'active' )

				@showWaveform = false
				event.target.classList.remove( 'active' )

			else

				@showWaveform = true
				event.target.classList.add( 'active' )

		## Draw keys
		@keys = []
		template = @container.querySelector( '.template' )

		for i in [ 0...@beats.keys.length ]

			@keys[ i ] = new Key( @beats.keys[ i ], @grid, colors[ i ], template )
			@grid.appendChild( @keys[ i ].element )

		for i in [ 0...@beats.modulators.length ]

			button = document.createElement( 'div' )
			button.textContent = @beats.modulators[ i ].name

			button.className = 'button-graph button'
			@graphControls.appendChild( button )

			@buttons[ i + 1 ] = button

		i = @buttons.length
		@buttons[ i ].addEventListener( 'click', @getAnalyser ) while i--

		## Draw horizontal lines
		linesCount = 20
		for i in [ 0..linesCount ]

			line = document.createElement( 'div' )

			if i % 10 == 0 then line.className = "line h half"
			else line.className = "line h "

			line.style.top = ( 100 / linesCount ) * i + "%"
			@grid.appendChild( line )

		## Store vertical lines to position them on resize
		@lines = []

		## Draw vertical lines
		for i in [ 0..@beats.levelCount ]

			line = document.createElement( 'div' )
			line.className = "line v"

			@lines[ @lines.length++ ] = line
			@grid.appendChild( line )

	getAnalyser: ( event ) =>

		@current?.classList.remove( 'active' )

		@current = event.currentTarget
		name     = @current.textContent

		@current.classList.add( 'active' )

		modulator = @beats.get( name )
		if name == 'main' then output = @beats.analyser
		else output = modulator.analyser

		@changeOutput( output )

		## Get filter response
		@frequencyHz = null
		@magnitude   = null
		@phase       = null

		if modulator?

			@filter = modulator.filter

			@frequencyBars = 1000

			@frequencies = new Float32Array( @frequencyBars )
			@magnitude   = new Float32Array( @frequencyBars )
			@phase       = new Float32Array( @frequencyBars )

			i = @frequencyBars
			@frequencies[ i ] = 2000 / @frequencyBars * ( i + 1 ) while i--

	update: ( output ) ->

		@context.clearRect( 0, 0, @width, @height )

		## Draw spectrum
		i = @levelCount
		while i--

			@context.fillStyle = 'rgba( 255, 255, 255, 0.15 )'

			if output.spectrum[ i ] > 0

				x      = i * @levelSize
				height = output.spectrum[ i ] *  @height
				width  = @levelSize

				y = @height - height
				@context.fillRect( x, y, width, height )

		if @magnitude?

			@filter.getFrequencyResponse( @frequencies, @magnitude, @phase )

			## Draw magnitude
			barWidth = @width / @frequencyBars

			@context.strokeStyle = 'rgba( 255, 255, 255, 0.8 )'
			@context.beginPath()
			@context.setLineDash( [ 2, 2 ] )

			step = 0
			while step < @frequencyBars
				@context.lineTo(
					step * barWidth,
					@height - @magnitude[ step ] * 90 )
				step++

			@context.stroke()

			## Draw phase

			@context.strokeStyle = 'rgba( 255, 255, 255, 0.2 )'
			@context.beginPath()

			step = 0
			while step < @frequencyBars
				@context.lineTo(
					step * barWidth,
					@height - ( @phase[ step ] * 90 + 300 ) / Math.PI )
				step++

			@context.stroke()
			@context.setLineDash( [] )

		## Set waveform opacity to 0 to hide it
		if @showWaveform

			## Draw waveform
			@context.strokeStyle = "rgba( 200, 200, 200, 0.95 )"
			@context.beginPath()

			i = @waveCount
			while i--

				height = output.waveform[ i ] * @height * 0.5 + @height * 0.5
				@context.lineTo( i * @waveSize, height )

			@context.stroke()

		## Resize keys
		i = @keys.length
		@keys[ i ].update() while i--

	resize: ->

		@width  = @canvas.width  = @container.clientWidth
		@height = @canvas.height = 300

		## Get level size according to the level count
		@levelCount  = @beats.levelCount || @beats.analyser.frequencyData.length
		@levelSize   = @width / @levelCount

		## Get wave size according to the wave count
		@waveCount = @beats.analyser.timeDomainData.length
		@waveSize  = @width / @waveCount

		## Position lines
		i = @lines.length
		@lines[ i ].style.left = @levelSize * i + "px" while i--

		## Resize keys
		i = @keys.length
		@keys[ i ].resize( @levelSize, @height ) while i--
