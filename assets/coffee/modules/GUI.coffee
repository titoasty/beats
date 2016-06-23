BEATS     = require 'Beats'
dat       = require 'dat-gui'
Draggable = require 'Draggable'

Outcome  = require 'gui/Outcome'
Spectrum = require 'gui/Spectrum'
Track    = require 'gui/Track'

colors = require 'gui/colors'

BEATS.GUI = class GUI

	constructor: ( @beats ) ->

		@beats.media.controls = true
		@beats.media.autoplay = false

		## Initialize dat.GUI
		@gui = new dat.GUI()

		## Override dat.GUI style
		document.head.appendChild( document.querySelector( '.main-style' ) )

		## Initial output (which analyser will be shown)
		@output = @beats.analyser

		@outcome  = new Outcome( @beats )
		@spectrum = new Spectrum( @beats, @changeOutput )
		@track    = new Track( @beats )

		## Set dat controls
		@setControllers()

		addEventListener( 'resize', @resize, true )
		addEventListener( 'keydown', @pause, false )

		## Resize once on start
		@resize()

	start: =>

		document.querySelector( '.overlay' ).classList.add( 'hide' )

	pause: ( event ) =>

		if event.keyCode == 32

			event.preventDefault()

			media = @beats.media
			if media.paused then media.play()
			else media.pause()

		else return

	changeOutput: ( output ) =>

		## Swicth output
		@beats.output.disconnect( 0 )
		@beats.output = output
		@beats.output.connect( @beats.destination )

	repeatPhase: ( value ) =>

		@loop = null

		i = @phasesNames.length
		while i--

			## Get the index of the phase
			if value != @phasesNames[ i ] || @phasesNames[ i ] == 'none' then continue
			else index = i - 1

		return if !index?

		## Store loop parameters
		@loop =
			index : index
			start : @beats.phases[ index ]
			end   : @beats.phases[ index + 1 ] || @beats.duration

		## Update media current time
		@beats.media.currentTime = @loop.start.time
		@beats.position = @loop.index

		@update( true )

	updateKeys: =>

		i = @spectrum.keys.length
		@spectrum.keys[ i ].update() while i--

	setControllers: ->

		folders = @gui.addFolder( 'General' )
		folders.add( @beats.media, 'playbackRate', [ 0.5, 1.0, 1.5, 2.0 ] ).name( 'playbackRate' )

		## Add controller to repear a phase
		phases = repeat : null
		@phasesNames  = [ 'none' ]

		i = @beats.phases.length
		@phasesNames[ @phasesNames.length++ ] = ( '000' + i ).substr( -3 ) while i--

		folders.add( phases, 'repeat', @phasesNames ).name( 'repeatPhase' )
		.onChange( @repeatPhase )

		## Store name of modulators to be able to change it in keys controllers
		modulatorsNames = [ 'none' ]

		folders = @gui.addFolder( 'Modulators' )
		modulators = @beats.modulators

		for i in [ 0...@beats.modulators.length ]

			modulator = @beats.modulators[ i ]

			## Add folder for each modulator and store its name
			folder = folders.addFolder( modulator.name )
			modulatorsNames[ modulatorsNames.length++ ] = modulator.name

			filter = modulator.filter

			frequency = folder.add( filter.frequency, 'value', 0, 40000 )
			frequency.name( 'frequency' )

			folder.add( filter.Q, 'value', 0, 10 ).name( 'Q' )
			folder.add( filter.gain, 'value', 0, 10 ).name( 'gain' )


		folders = @gui.addFolder( 'Keys' )
		keys    = @beats.keys

		for i in [ 0...@beats.keys.length ]

			key = @beats.keys[ i ]

			## Add folder for each key
			folder = folders.addFolder( key.name )

			folder.add( key, 'active', ).listen().onChange( @updateKeys )
			folder.add( key, 'type', [ 'average', 'max' ] ).listen().onChange( @updateKeys )
			folder.add( key, 'start', 0, @levelCount ).listen().step( 1 ).onChange( @updateKeys )
			folder.add( key, 'end'  , 0, @levelCount ).listen().step( 1 ).onChange( @updateKeys )
			folder.add( key, 'min'  , 0, 1 ).listen().step( 0.01 ).onChange( @updateKeys )
			folder.add( key, 'max'  , 0, 1 ).listen().step( 0.01 ).onChange( @updateKeys )
			folder.add( key, 'smoothness', 1, 100 ).listen().onChange( @updateKeys )

			folder.add( key, 'modulator', modulatorsNames ).listen().onChange( @updateKeys )

	update: ( force ) ->

		## Loop through one phase if the parameters is set
		if @loop? and @beats.currentTime >= @loop.end.time

			@beats.media.currentTime = @loop.start.time
			@beats.position = @loop.index

		if !@outcome.initialize

			force = true
			@start()

		## Update all the UI element
		if @beats.media? and !@beats.media.paused or force

			@outcome.update()
			@spectrum.update( @beats.output )
			@track.update()

			force = false

	resize: =>

		@outcome.resize()
		@spectrum.resize()
		@track.resize()



