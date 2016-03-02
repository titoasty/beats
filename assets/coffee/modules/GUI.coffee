BEATS     = require 'Beats'
dat       = require 'dat-gui'
Draggable = require 'Draggable'

Outcome  = require 'gui/Outcome'
Spectrum = require 'gui/Spectrum'
Track    = require 'gui/Track'

BEATS.GUI = class GUI

	constructor: (@beats) ->

		## Initialize dat.GUI
		@gui = new dat.GUI()

		# Draggable.create @gui.domElement

		## Initial output (which analyser will be shown)
		@output = @beats.analyser

		@outcome  = new Outcome @beats
		@spectrum = new Spectrum @beats
		@track    = new Track @beats

		## Set dat controls
		@dat()

		addEventListener 'resize', @resize, true

		## Resize once on start
		@resize()

	changeOutput: (output) ->

		@output = output
		@beats.output.disconnect()
		@output.connect @beats.destination
		@beats.output = @output

	dat: ->

		## Store name of modulators to be able to change it in keys controls
		names = [ 'none' ]
		folders = @gui.addFolder 'Modulators'

		name = @spectrum.container.querySelector '.container-name span'
		modulators = @beats.modulators

		for i in [ 0...@beats.modulators.length ]

			modulator = @beats.modulators[ i ]

			## Add folder for each modulator and store its name
			folder = folders.addFolder modulator.name
			names[ names.length++ ] = modulator.name

			filter = modulator.filter

			frequency = folder.add filter.frequency, 'value', 0, 40000
			frequency.name 'frequency'

			Q = folder.add filter.Q, 'value', 0, 10
			Q.name 'Q'

			gain = folder.add filter.gain, 'value', 0, 10
			gain.name 'gain'

			## Create "output" property
			modulator.output = false

			output = folder.add modulator, 'output'
			output.name 'output'

			self = @
			output.listen().onChange (value) ->

				i = modulators.length
				while i--

					if @object.name == modulators[ i ].name
					else modulators[ i ].output = false

				if value

					name.innerText = @object.name
					self.changeOutput @object.analyser

				else

					name.innerText = 'Main analyser'
					self.changeOutput self.beats.analyser


		## Keys
		folders = @gui.addFolder 'Keys'

		name = @outcome.container.querySelector '.container-name span'
		keys = @beats.keys

		updateKeys = =>

			i = @spectrum.keys.length
			while i-- then @spectrum.keys[ i ].update()

		for i in [ 0...@beats.keys.length ]

			key = @beats.keys[ i ]
			folder = folders.addFolder key.name

			folder.add( key, 'active', ).listen().onChange updateKeys
			folder.add( key, 'type', [ 'average', 'max' ] ).listen().onChange updateKeys
			folder.add( key, 'start', 0, @levelCount ).listen().step( 1 ).onChange updateKeys
			folder.add( key, 'end'  , 0, @levelCount ).listen().step( 1 ).onChange updateKeys
			folder.add( key, 'min'  , 0, 1 ).listen().step( 0.01 ).onChange updateKeys
			folder.add( key, 'max'  , 0, 1 ).listen().step( 0.01 ).onChange updateKeys
			folder.add( key, 'modulator', names ).listen().onChange updateKeys

			if !i then key.graph = true else key.graph = false

			outcome = @outcome
			folder.add( key, 'graph', ).listen().onChange (value) ->

				i = keys.length
				while i--
					keys[ i ].graph = false

				if value

					outcome.currentKey = @object
					name.innerText  = @object.name
					@object.graph   = true

				else

					outcome.currentKey = null
					name.innerText  = 'Nothing selected'

	update: ->

		@outcome.update @output
		@spectrum.update @output
		@track.update @output

	resize: =>

		@outcome.resize()
		@spectrum.resize()
		@track.resize()



