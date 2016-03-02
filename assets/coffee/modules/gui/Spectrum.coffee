TweenMax = require 'gsap'
require 'Draggable'

Key = require 'gui/Key'

module.exports = class Spectrum

	constructor: (@beats) ->

		@container = document.querySelector '.graph-spectrum'
		@grid = @container.querySelector '.grid'
		@canvas    = @container.querySelector 'canvas'
		@context   = @canvas.getContext '2d'

		## Add control to show waveform or not
		@showWaveform = false
		button = @container.querySelector '.button-waveform'
		button.addEventListener 'click', (event) =>

			if event.target.classList.contains 'active'

				@showWaveform = false
				event.target.classList.remove 'active'

			else

				@showWaveform = true
				event.target.classList.add 'active'

		## Draw keys
		@keys = []
		template = @container.querySelector '.template'

		for i in [ 0...@beats.keys.length ]

			@keys[ i ] = new Key @beats.keys[ i ], @grid, template
			@grid.appendChild @keys[ i ].element

		## Draw horizontal lines
		linesCount = 20
		for i in [ 0..linesCount ]

			line = document.createElement 'div'

			if i % 10 == 0 then line.className = "line h half"
			else line.className = "line h "

			line.style.top = ( 100 / linesCount ) * i + "%"
			@grid.appendChild line

		## Store vertical lines to position them on resize
		@lines = []

		## Draw vertical lines
		for i in [ 0..@beats.levelCount ]

			line = document.createElement 'div'
			line.className = "line v"

			@lines[ @lines.length++ ] = line
			@grid.appendChild line

	update: (output) ->

		@context.clearRect 0, 0, @width, @height

		## Draw spectrum
		i = @levelCount
		while i--

			@context.fillStyle = 'rgba( 255, 255, 255, 0.5 )'

			if output.spectrum[ i ] > 0

				x      = i * @levelSize
				height = output.spectrum[ i ] *  @height
				width  = @levelSize

				y = @height - height
				@context.fillRect x, y, width, height


		## Draw waveform
		@context.beginPath()

		## Set waveform opacity to 0 to hide it
		if @showWaveform then @context.strokeStyle = "rgba( 200, 200, 200, 0.95 )"
		else @context.strokeStyle = "rgba( 200, 200, 200, 0.0 )"

		i = @waveCount
		while i--

			height = output.waveform[ i ] * @height * 0.5 + @height * 0.5
			@context.lineTo i * @waveSize, height

		@context.stroke()

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
		while i-- then @lines[ i ].style.left = @levelSize * i + "px"

		## Resize keys
		i = @keys.length
		while i-- then @keys[ i ].resize @levelSize, @height
