module.exports = class Outcome

	constructor: (@beats) ->

		@container = document.querySelector '.graph-keys'
		@canvas    = @container.querySelector 'canvas'
		@context   = @canvas.getContext '2d'

		## Show player controls
		@controls = document.querySelector '.controls'
		@media = @beats.input.mediaElement
		@media.className = 'audio'
		@controls.appendChild @media

		Draggable.create @controls

		## Draw output container
		@outputs    = []
		@values     = []
		@levels     = []
		@thresholds = []
		@callbacks  = []
		@circles    = []

		template = @controls.querySelector '.template'

		@keys = @beats.keys

		@currentKey  = @keys[ 0 ]
		@valueByTime = []

		for i in [ 0...@keys.length ]

			output = template.cloneNode true
			output.className = "output"

			name = output.querySelector '.name'
			name.innerText = @keys[ i ].name
			@controls.appendChild output

			@outputs[ @outputs.length++ ]       = output
			@values[ @values.length++ ]         = output.querySelector '.value'
			@levels[ @levels.length++ ]         = output.querySelector '.level'
			@thresholds[ @thresholds.length++ ] = output.querySelector '.threshold'
			@callbacks[ @callbacks.length++ ]   = output.querySelector '.callback'
			@circles[ @circles.length++ ]       = output.querySelector '.circle'

		## Draw grid
		grid = @container.querySelector '.grid'
		linesCount = 10

		for j in [ 0..linesCount ]

			line = document.createElement 'div'

			if j % 5 == 0 then line.className = "line h half"
			else line.className = "line h"

			line.style.top = ( 100 / linesCount ) * j + "%"
			grid.appendChild line

	update: ->

		## Update keys
		i = @beats.keys.length
		while i--

			key = @beats.keys[ i ]
			@values[ i ].innerText = key.value.toFixed 3

			if key.threshold?

				@thresholds[ i ].style.height  = 100 * key.currentThreshold + "%"
				@thresholds[ i ].style.display = "block"

				@callbacks[ i ].style.top  = 100 - 100 * key.currentThreshold + "%"
				@callbacks[ i ].style.display = "block"

			else

				@thresholds[ i ].style.display = "none"
				@callbacks[ i ].style.display = "none"

			if key.active

				@outputs[ i ].style.opacity   = 1.0
				@levels[ i ].style.height     = 100 * key.value + "%"
				@circles[ i ].style.transform = 'translateX(-25%) scale(' + key.value + ')'

			else @outputs[ i ].style.opacity = 0.2


		## Update graph
		@context.clearRect 0, 0, @width, @canvas.height
		@context.strokeStyle = "white"

		if @valueByTime.length >= @waveCountKeys then @valueByTime.shift()

		if !@currentKey? then return
		@valueByTime[ @valueByTime.length++ ] = @currentKey.value

		@context.beginPath()
		@context.setLineDash []

		for i in [ 0...@waveCountKeys ]

			height = -@valueByTime[ i ] * @height + @height
			@context.lineTo i * @waveSizeKeys, height

		@context.stroke()

		if !@currentKey.threshold? then return

		## Threshold
		@context.beginPath()
		@context.strokeStyle = "white"

		height = -@currentKey.threshold * @height + @height
		@context.setLineDash [ 5, 5 ]
		@context.moveTo 0, height
		@context.lineTo @width, height
		@context.stroke()

	resize: ->

		@width  = @canvas.width  = @canvas.parentNode.clientWidth
		@height = @canvas.height = 150

		@waveCountKeys = 300
		@waveSizeKeys  = @width / @waveCountKeys
