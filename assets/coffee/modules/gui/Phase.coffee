module.exports = class Phase

	constructor: ( @values, @mediaDuration, @track,  template ) ->

		@element = template.cloneNode( true )
		@element.className  = "sequence"

		@text = @element.querySelector( '.value' )

		self = @
		@draggable = new Draggable @element,

			bounds   : @track.sequences
			type     : 'x'
			lockAxis : true
			cursor   : 'ew-resize'

			onPress   : => @track.dragged = true
			onRelease : => @track.dragged = false

			onDrag   : -> self.onDrag( @x )

	onDrag: ( x ) =>

		time = x / @canvasWidth * @mediaDuration
		time = Math.round( time * 1000 ) * 0.001
		@text.textContent = time.toFixed( 3 )

		@values.time = time

	set: =>

		TweenMax.set @element, x : @values.time / @mediaDuration * @canvasWidth
		@text.textContent = @values.time.toFixed( 3 )

		@draggable?.update()

	resize: ( @canvasWidth ) =>

		@set()

