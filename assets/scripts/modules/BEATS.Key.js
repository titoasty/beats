export default class Key {

	constructor(start, end, min, max, parameters) {
		this.update = this.update.bind(this);
		if (parameters == null) {
			parameters = {};
		}

		this.set(start, end, min, max);

		this.value = 0;

		this.smoothness = parameters.smoothness || 1;

		this.delay = parameters.delay;
		this.timeout = null;
		this.lower = true;

		this.threshold = parameters.threshold;
		this.currentThreshold = this.threshold;

		this.type = parameters.type || 'average';

		this.name = parameters.name;
		this.modulator = parameters.modulator || null;
		this.active = parameters.active;

		this.callback = parameters.callback || null;
	}

	set(start, end, min, max, threshold) {
		if (start != null) {
			this.start = start;
		}
		if (end != null) {
			this.end = end;
		}
		if (min != null) {
			this.min = min;
		}
		if (max != null) {
			return this.max = max;
		}
	}

	update(frequency) {
		if (!this.active) {
			this.value = 0;
			return;
		}

		//# Compute value according to parameters
		let value = ( frequency - this.min ) / ( this.max - this.min );

		//# Constricts value
		value = Math.min(1, Math.max(0, value));

		if (this.smoothness <= 1) {
			this.value = value;
		} else {
			this.value += ( value - this.value ) * ( 1 / this.smoothness );
		}

		//# Check if a callback sould be called
		if (!this.threshold) {
			return;
		}

		if (this.value >= this.currentThreshold && this.lower) {

			let callback = () => this.lower = true;
			this.timeout = setTimeout(callback, this.delay);
			this.lower = false;

			if (this.callback != null) {
				return this.callback();
			}
		}
	}

}
