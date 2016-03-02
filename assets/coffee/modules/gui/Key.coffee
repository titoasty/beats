module.exports = class Key

	constructor: (@values, @bounds, template) ->

		@element = template.cloneNode true
		@element.className = 'key'

		@name = @element.querySelector '.name'
		@name.innerText = @values.name

		@handle = @element.querySelector '.handle'

	set: ->

		self = @
		@update()

		## Set draggables for easily change key valeus
		Draggable.create @element,

			bounds   : @bounds
			liveSnap : x : (value) => @levelSize * Math.round value / @levelSize
			onDrag: ->

				difference      = self.values.max - self.values.min
				self.values.max = 1 - @y / self.canvasHeight
				self.values.min = self.values.max - difference

				difference        = self.values.end - self.values.start
				self.values.start = Math.round @x / self.levelSize
				self.values.end   = self.values.start + difference

		Draggable.create @handle,

			bounds   : @bounds
			type     : 'top, left'
			onPress  : (event) -> event.stopPropagation()
			onDrag   : (event) ->

				self.values.min = self.values.max - @y / self.canvasHeight
				self.values.end = self.values.start + Math.round @x / self.levelSize

				TweenLite.set @target.parentNode, width: @x, height: @y

			liveSnap : x : (value) => @levelSize * Math.round value / @levelSize

	update: ->

		if @values.active
			if !@element.classList.contains 'active'
				@element.classList.add 'active'
		else @element.classList.remove 'active'

		x = @values.start * @levelSize
		y = ( 1 - @values.max ) * @canvasHeight

		width  = ( @values.end - @values.start ) * @levelSize
		height = ( @values.max - @values.min ) * @canvasHeight

		@element.style.height    = height + 'px'
		@element.style.width     = width + 'px'
		@element.style.transform = 'translate3d(' + x + 'px,' + y + 'px, 0px)'

	resize: (@levelSize, @canvasHeight) -> @set()
