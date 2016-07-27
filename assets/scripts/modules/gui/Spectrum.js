import TweenMax from 'gsap';

import Key from './Key';
import colors from './colors';

export default class Spectrum {

	constructor(beats, changeOutput) {

		this.getAnalyser = this.getAnalyser.bind(this);
		this.beats = beats;
		this.changeOutput = changeOutput;
		this.container = document.querySelector('.graph-spectrum');
		this.graphControls = this.container.querySelector('.graph-spectrum-controls');
		this.grid = this.container.querySelector('.grid');
		this.canvas = this.container.querySelector('canvas');
		this.context = this.canvas.getContext('2d');

		this.buttons = [this.graphControls.querySelector('.active')];
		this.current = this.buttons[0];

		//# Add control to show waveform or not
		let button = this.container.querySelector('.button-waveform');
		this.showWaveform = false;

		if (this.showWaveform) {
			button.classList.add('active');
		}

		button.addEventListener('click', event => {

				if (event.target.classList.contains('active')) {

					this.showWaveform = false;
					return event.target.classList.remove('active');

				} else {

					this.showWaveform = true;
					return event.target.classList.add('active');
				}
			}
		);

		//# Draw keys
		this.keys = [];
		let template = this.container.querySelector('.template');

		let iterable = __range__(0, this.beats.keys.length, false);
		for (let j = 0; j < iterable.length; j++) {

			var i = iterable[j];
			this.keys[i] = new Key(this.beats.keys[i], this.grid, colors[i], template);
			this.grid.appendChild(this.keys[i].element);
		}

		let iterable1 = __range__(0, this.beats.modulators.length, false);
		for (let k = 0; k < iterable1.length; k++) {

			var i = iterable1[k];
			button = document.createElement('div');
			button.textContent = this.beats.modulators[i].name;

			button.className = 'button-graph button';
			this.graphControls.appendChild(button);

			this.buttons[i + 1] = button;
		}

		var i = this.buttons.length;
		while (i--) {
			this.buttons[i].addEventListener('click', this.getAnalyser);
		}

		//# Draw horizontal lines
		let linesCount = 20;
		let iterable2 = __range__(0, linesCount, true);
		for (let i1 = 0; i1 < iterable2.length; i1++) {

			i = iterable2[i1];
			var line = document.createElement('div');

			if (i % 10 === 0) {
				line.className = "line h half";
			} else {
				line.className = "line h ";
			}

			line.style.top = (( 100 / linesCount ) * i) + "%";
			this.grid.appendChild(line);
		}

		//# Store vertical lines to position them on resize
		this.lines = [];

		//# Draw vertical lines
		let iterable3 = __range__(0, this.beats.levelCount, true);
		for (let j1 = 0; j1 < iterable3.length; j1++) {

			i = iterable3[j1];
			var line = document.createElement('div');
			line.className = "line v";

			this.lines[this.lines.length++] = line;
			this.grid.appendChild(line);
		}
	}

	getAnalyser(event) {

		__guard__(this.current, x => x.classList.remove('active'));

		this.current = event.currentTarget;
		let name = this.current.textContent;

		this.current.classList.add('active');

		let modulator = this.beats.get(name);
		if (name === 'main') {
			var output = this.beats.analyser;
		} else {
			var output = modulator.analyser;
		}

		this.changeOutput(output);

		//# Get filter response
		this.frequencyHz = null;
		this.magnitude = null;
		this.phase = null;

		if (modulator != null) {

			this.filter = modulator.filter;

			this.frequencyBars = 1000;

			this.frequencies = new Float32Array(this.frequencyBars);
			this.magnitude = new Float32Array(this.frequencyBars);
			this.phase = new Float32Array(this.frequencyBars);

			let i = this.frequencyBars;
			return (() => {
				let result = [];
				while (i--) {
					result.push(this.frequencies[i] = (2000 / this.frequencyBars) * ( i + 1 ));
				}
				return result;
			})();
		}
	}

	update(output) {

		this.context.clearRect(0, 0, this.width, this.height);

		//# Draw spectrum
		let i = this.levelCount;
		while (i--) {

			this.context.fillStyle = 'rgba( 255, 255, 255, 0.15 )';

			if (output.spectrum[i] > 0) {

				let x = i * this.levelSize;
				var height = output.spectrum[i] * this.height;
				let width = this.levelSize;

				let y = this.height - height;
				this.context.fillRect(x, y, width, height);
			}
		}

		if (this.magnitude != null) {

			this.filter.getFrequencyResponse(this.frequencies, this.magnitude, this.phase);

			//# Draw magnitude
			let barWidth = this.width / this.frequencyBars;

			this.context.strokeStyle = 'rgba( 255, 255, 255, 0.8 )';
			this.context.beginPath();
			this.context.setLineDash([2, 2]);

			let step = 0;
			while (step < this.frequencyBars) {
				this.context.lineTo(
					step * barWidth,
					this.height - (this.magnitude[step] * 90));
				step++;
			}

			this.context.stroke();

			//# Draw phase

			this.context.strokeStyle = 'rgba( 255, 255, 255, 0.2 )';
			this.context.beginPath();

			step = 0;
			while (step < this.frequencyBars) {
				this.context.lineTo(
					step * barWidth,
					this.height - (( (this.phase[step] * 90) + 300 ) / Math.PI));
				step++;
			}

			this.context.stroke();
			this.context.setLineDash([]);
		}

		//# Set waveform opacity to 0 to hide it
		if (this.showWaveform) {

			//# Draw waveform
			this.context.strokeStyle = "rgba( 200, 200, 200, 0.95 )";
			this.context.beginPath();

			i = this.waveCount;
			while (i--) {

				var height = (output.waveform[i] * this.height * 0.5) + (this.height * 0.5);
				this.context.lineTo(i * this.waveSize, height);
			}

			this.context.stroke();
		}

		//# Resize keys
		i = this.keys.length;
		return (() => {
			let result = [];
			while (i--) {
				result.push(this.keys[i].update());
			}
			return result;
		})();
	}

	resize() {

		this.width = this.canvas.width = this.container.clientWidth;
		this.height = this.canvas.height = 300;

		//# Get level size according to the level count
		this.levelCount = this.beats.levelCount || this.beats.analyser.frequencyData.length;
		this.levelSize = this.width / this.levelCount;

		//# Get wave size according to the wave count
		this.waveCount = this.beats.analyser.timeDomainData.length;
		this.waveSize = this.width / this.waveCount;

		//# Position lines
		let i = this.lines.length;
		while (i--) {
			this.lines[i].style.left = (this.levelSize * i) + "px";
		}

		//# Resize keys
		i = this.keys.length;
		return (() => {
			let result = [];
			while (i--) {
				result.push(this.keys[i].resize(this.levelSize, this.height));
			}
			return result;
		})();
	}
};

function __range__(left, right, inclusive) {
	let range = [];
	let ascending = left < right;
	let end = !inclusive ? right : ascending ? right + 1 : right - 1;
	for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
		range.push(i);
	}
	return range;
}
function __guard__(value, transform) {
	return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}