export default class Phase {

	constructor(values, mediaDuration, track, template) {
		this.onDrag = this.onDrag.bind(this);
		this.set = this.set.bind(this);
		this.resize = this.resize.bind(this);
		this.values = values;
		this.mediaDuration = mediaDuration;
		this.track = track;
		this.element = template.cloneNode(true);
		this.element.className = "sequence";

		this.text = this.element.querySelector('.value');

		let self = this;
		this.draggable = new Draggable(this.element, {
				bounds: this.track.sequences,
				type: 'x',
				lockAxis: true,
				cursor: 'ew-resize',

				onPress: () => this.track.dragged = true,
				onRelease: () => this.track.dragged = false,

				onDrag() {
					return self.onDrag(this.x);
				}
			}
		);
	}

	onDrag(x) {
		let time = (x / this.canvasWidth) * this.mediaDuration;
		time = Math.round(time * 1000) * 0.001;
		this.text.textContent = time.toFixed(3);

		return this.values.time = time;
	}

	set() {
		TweenMax.set(this.element, {x: (this.values.time / this.mediaDuration) * this.canvasWidth});
		this.text.textContent = this.values.time.toFixed(3);

		return __guard__(this.draggable, x => x.update());
	}

	resize(canvasWidth) {
		this.canvasWidth = canvasWidth;
		return this.set();
	}
}


function __guard__(value, transform) {
	return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}
