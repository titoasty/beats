colors = require 'gui/colors'

module.exports = class Outcome

	constructor: ( @beats ) ->

		@container     = document.querySelector( '.graph-keys' )
		@graphControls = @container.querySelector( '.graph-keys-controls' )
		@grid          = @container.querySelector( '.grid' )
		@canvas        = @container.querySelector( 'canvas' )
		@context       = @canvas.getContext( '2d' )

		## Show player controls
		@controls = document.querySelector( '.controls' )
		@media = @beats.input.mediaElement
		@media.className = 'audio'
		@controls.appendChild( @media )

		@bpm = document.createElement( 'div' )
		@bpm.className = 'bpm'
		@controls.appendChild( @bpm )

		## Draw output container
		@outputs    = []
		@values     = []
		@levels     = []
		@thresholds = []
		@callbacks  = []
		@circles    = []

		keyTemplate    = @controls.querySelector( '.template' )
		buttonTemplate = @graphControls.querySelector( '.template' )

		@keys    = @beats.keys
		@buttons = []

		@datas = []

		for i in [ 0...@keys.length ]

			output = keyTemplate.cloneNode( true )
			output.className = 'output'

			name = output.querySelector( '.name' )
			name.style.color = colors[ i ]
			name.innerText = @keys[ i ].name
			@controls.appendChild( output )

			@outputs[ @outputs.length++ ]       = output
			@values[ @values.length++ ]         = output.querySelector( '.value' )
			@thresholds[ @thresholds.length++ ] = output.querySelector( '.threshold' )
			@callbacks[ @callbacks.length++ ]   = output.querySelector( '.callback' )
			@circles[ @circles.length++ ]       = output.querySelector( '.circle' )

			level = @levels[ @levels.length++ ] = output.querySelector( '.level' )

			button = document.createElement( 'div' )
			button.innerText = @keys[ i ].name
			button.style.color = colors[ i ]

			button.className = 'button-graph button'
			button.classList.add( 'active' ) if @keys[ i ].active

			@graphControls.appendChild( button )

			button.addEventListener( 'click', @toggle )
			@buttons[ i ] = button

			@datas[ i ] = []

		@keys.forEach ( key, index ) => key.callback = => @highlightCallback( key )

		## Draw grid
		grid = @container.querySelector( '.grid' )
		linesCount = 10

		for j in [ 0..linesCount ]

			line = document.createElement( 'div' )

			if j % 5 == 0 then line.className = "line h half"
			else line.className = "line h"

			line.style.top = ( 100 / linesCount ) * j + "%"
			grid.appendChild( line )

	highlightCallback: ( key ) =>

		callback = @callbacks[ key.index ]
		@setCallbackStyle( callback, colors[ key.index ], 1 )
		setTimeout =>
			@setCallbackStyle( callback, '#ffffff', 0.5 )
		, 250

	setCallbackStyle: ( callback, color, opacity ) ->

		callback.style.opacity = opacity
		callback.style.color   = color

	toggle: ( event ) =>

		event.currentTarget.classList.toggle( 'active' )
		@update()

	update: ->

		@context.clearRect( 0, 0, @width, @canvas.height )

		if !@initialize

			@bpm.textContent = @beats.bpm + ' BPM'
			@initialize = true

		## Update keys
		i = @beats.keys.length
		while i--

			key = @beats.keys[ i ]
			@values[ i ].innerText = key.value.toFixed( 3 )

			if key.threshold?

				@thresholds[ i ].style.height  = 100 * key.currentThreshold + "%"
				@thresholds[ i ].style.display = "block"

				@callbacks[ i ].style.top     = 100 - 100 * key.currentThreshold + "%"
				@callbacks[ i ].style.display = "block"

			else

				@thresholds[ i ].style.display = "none"
				@callbacks[ i ].style.display  = "none"

			if key.active

				@outputs[ i ].style.opacity   = 1.0
				@levels[ i ].style.height     = 100 * key.value + "%"
				@circles[ i ].style.transform = 'scale(' + key.value + ')'

			else @outputs[ i ].style.opacity = 0.2

			@datas[ i ].shift() if @datas[ i ].length >= @waveCountKeys
			@datas[ i ][ @datas[ i ].length++ ] = key.value

			@draw( key, @datas[ i ], colors[ i ] ) if @buttons[ i ].classList.contains( 'active' )

	draw: ( key, datas, color ) =>

		## Update graph
		@context.strokeStyle = color

		@context.beginPath()
		@context.setLineDash( [] )

		for i in [ 0...@waveCountKeys ]

			y = -datas[ i ] * @height + @height
			@context.lineTo( i * @waveSizeKeys, y )

		@context.stroke()

		return if !key.threshold?

		## Threshold
		@context.beginPath()
		@context.strokeStyle = color

		y = -key.threshold * @height + @height
		@context.setLineDash( [ 5, 5 ] )
		@context.moveTo( 0, y )
		@context.lineTo( @width, y )
		@context.stroke()

	resize: ->

		@width  = @canvas.width  = @canvas.parentNode.clientWidth
		@height = @canvas.height = @grid.clientHeight

		@waveCountKeys = 300
		@waveSizeKeys  = @width / @waveCountKeys
