export default class Key {

	constructor(values, bounds, color, template) {
		this.resize = this.resize.bind(this);
		this.values = values;
		this.bounds = bounds;
		this.element = template.cloneNode(true);
		this.element.className = 'key';

		this.element.style.boxShadow = `0 0 0 1px ${color} inset`;

		this.name = this.element.querySelector('.name');
		this.name.innerText = this.values.name;

		this.handle = this.element.querySelector('.handle');
	}

	set() {
		let self = this;
		this.update();

		//# Set draggables for easily change key values
		Draggable.create(this.element, {
				bounds: this.bounds,
				liveSnap: {
					x: value => {
						return this.levelSize * Math.round(value / this.levelSize);
					}
				},
				onDrag() {

					let difference = self.values.max - self.values.min;
					self.values.max = 1 - (this.y / self.canvasHeight);
					self.values.min = self.values.max - difference;

					difference = self.values.end - self.values.start;
					self.values.start = Math.round(this.x / self.levelSize);
					return self.values.end = self.values.start + difference;
				}
			}
		);

		return Draggable.create(this.handle, {
				bounds: this.bounds,
				type: 'top, left',
				onPress(event) {
					return event.stopPropagation();
				},
				onDrag(event) {
					self.values.min = self.values.max - (this.y / self.canvasHeight);
					self.values.end = self.values.start + Math.round(this.x / self.levelSize);

					return TweenLite.set(this.target.parentNode, {width: this.x, height: this.y});
				},
				liveSnap: {
					x: value => this.levelSize * Math.round(value / this.levelSize)
				}
			}
		);
	}

	update() {
		if (this.values.active) {
			if (!this.element.classList.contains('active')) {
				this.element.classList.add('active');
			}

		} else {
			this.element.classList.remove('active');
		}

		let x = this.values.start * this.levelSize;
		let y = ( 1 - this.values.max ) * this.canvasHeight;

		let width = ( this.values.end - this.values.start ) * this.levelSize;
		let height = ( this.values.max - this.values.min ) * this.canvasHeight;

		this.element.style.height = height + 'px';
		this.element.style.width = width + 'px';

		return this.element.style.transform = `translate3d( ${x}px,${y}px, 0px )`;
	}

	resize(levelSize, canvasHeight) {
		this.levelSize = levelSize;
		this.canvasHeight = canvasHeight;
		this.update();

		return this.set();
	}

}
