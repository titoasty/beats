import colors from './colors';

export default class Outcome {

	constructor(beats) {
		this.highlightCallback = this.highlightCallback.bind(this);
		this.toggle = this.toggle.bind(this);
		this.draw = this.draw.bind(this);
		this.beats = beats;
		this.container = document.querySelector('.graph-keys');
		this.graphControls = this.container.querySelector('.graph-keys-controls');
		this.grid = this.container.querySelector('.grid');
		this.canvas = this.container.querySelector('canvas');
		this.context = this.canvas.getContext('2d');

		//# Show player controls
		this.controls = document.querySelector('.controls');
		this.media = this.beats.input.mediaElement;
		this.media.className = 'audio';
		this.controls.appendChild(this.media);

		this.bpm = document.createElement('div');
		this.bpm.className = 'bpm';
		this.controls.appendChild(this.bpm);

		//# Draw output container
		this.outputs = [];
		this.values = [];
		this.levels = [];
		this.thresholds = [];
		this.callbacks = [];
		this.circles = [];

		let keyTemplate = this.controls.querySelector('.template');
		let buttonTemplate = this.graphControls.querySelector('.template');

		this.keys = this.beats.keys;
		this.buttons = [];

		this.datas = [];

		let iterable = __range__(0, this.keys.length, false);
		for (let k = 0; k < iterable.length; k++) {
			let i = iterable[k];
			let output = keyTemplate.cloneNode(true);
			output.className = 'output';

			let name = output.querySelector('.name');
			name.style.color = colors[i];
			name.innerText = this.keys[i].name;
			this.controls.appendChild(output);

			this.outputs[this.outputs.length++] = output;
			this.values[this.values.length++] = output.querySelector('.value');
			this.thresholds[this.thresholds.length++] = output.querySelector('.threshold');
			this.callbacks[this.callbacks.length++] = output.querySelector('.callback');
			this.circles[this.circles.length++] = output.querySelector('.circle');

			let level = this.levels[this.levels.length++] = output.querySelector('.level');

			let button = document.createElement('div');
			button.innerText = this.keys[i].name;
			button.style.color = colors[i];

			button.className = 'button-graph button';
			if (this.keys[i].active) {
				button.classList.add('active');
			}

			this.graphControls.appendChild(button);

			button.addEventListener('click', this.toggle);
			this.buttons[i] = button;

			this.datas[i] = [];
		}

		this.keys.forEach((key, index) => key.callback = () => this.highlightCallback(key));

		//# Draw grid
		let grid = this.container.querySelector('.grid');
		let linesCount = 10;

		let iterable1 = __range__(0, linesCount, true);
		for (let i1 = 0; i1 < iterable1.length; i1++) {
			let j = iterable1[i1];
			let line = document.createElement('div');

			if (j % 5 === 0) {
				line.className = "line h half";
			} else {
				line.className = "line h";
			}

			line.style.top = (( 100 / linesCount ) * j) + "%";
			grid.appendChild(line);
		}
	}

	highlightCallback(key) {
		let callback = this.callbacks[key.index];
		this.setCallbackStyle(callback, colors[key.index], 1);
		return setTimeout(() => {
				return this.setCallbackStyle(callback, '#ffffff', 0.5);
			}
			, 250);
	}

	setCallbackStyle(callback, color, opacity) {
		callback.style.opacity = opacity;
		return callback.style.color = color;
	}

	toggle(event) {
		event.currentTarget.classList.toggle('active');
		return this.update();
	}

	update() {
		this.context.clearRect(0, 0, this.width, this.canvas.height);

		if (!this.initialize) {

			this.bpm.textContent = this.beats.bpm + ' BPM';
			this.initialize = true;
		}

		//# Update keys
		let i = this.beats.keys.length;
		return (() => {
			let result = [];
			while (i--) {
				let item;
				let key = this.beats.keys[i];
				this.values[i].innerText = key.value.toFixed(3);

				if (key.threshold != null) {

					this.thresholds[i].style.height = (100 * key.currentThreshold) + "%";
					this.thresholds[i].style.display = "block";

					this.callbacks[i].style.top = (100 - (100 * key.currentThreshold)) + "%";
					this.callbacks[i].style.display = "block";

				} else {

					this.thresholds[i].style.display = "none";
					this.callbacks[i].style.display = "none";
				}

				if (key.active) {

					this.outputs[i].style.opacity = 1.0;
					this.levels[i].style.height = (100 * key.value) + "%";
					this.circles[i].style.transform = `scale(${key.value})`;

				} else {
					this.outputs[i].style.opacity = 0.2;
				}

				if (this.datas[i].length >= this.waveCountKeys) {
					this.datas[i].shift();
				}
				this.datas[i][this.datas[i].length++] = key.value;

				if (this.buttons[i].classList.contains('active')) {
					item = this.draw(key, this.datas[i], colors[i]);
				}
				result.push(item);
			}
			return result;
		})();
	}

	draw(key, datas, color) {
		//# Update graph
		this.context.strokeStyle = color;

		this.context.beginPath();
		this.context.setLineDash([]);

		let iterable = __range__(0, this.waveCountKeys, false);
		for (let j = 0; j < iterable.length; j++) {
			let i = iterable[j];
			var y = (-datas[i] * this.height) + this.height;
			this.context.lineTo(i * this.waveSizeKeys, y);
		}

		this.context.stroke();

		if (key.threshold == null) {
			return;
		}

		//# Threshold
		this.context.beginPath();
		this.context.strokeStyle = color;

		var y = (-key.threshold * this.height) + this.height;
		this.context.setLineDash([5, 5]);
		this.context.moveTo(0, y);
		this.context.lineTo(this.width, y);
		return this.context.stroke();
	}

	resize() {
		this.width = this.canvas.width = this.canvas.parentNode.clientWidth;
		this.height = this.canvas.height = this.grid.clientHeight;

		this.waveCountKeys = 300;
		return this.waveSizeKeys = this.width / this.waveCountKeys;
	}
}

function __range__(left, right, inclusive) {
	let range = [];
	let ascending = left < right;
	let end = !inclusive ? right : ascending ? right + 1 : right - 1;
	for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
		range.push(i);
	}
	return range;

}
