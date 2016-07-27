import Phase from './Phase';

export default class Track {

	constructor(beats) {
		this.set = this.set.bind(this);
		this.draw = this.draw.bind(this);
		this.onScroll = this.onScroll.bind(this);
		this.addListener = this.addListener.bind(this);
		this.removeListener = this.removeListener.bind(this);
		this.moveTo = this.moveTo.bind(this);
		this.beats = beats;
		this.container = document.querySelector('.track');
		this.name = this.container.querySelector('.container-name');
		this.progress = document.querySelector('.progress');
		this.time = this.progress.querySelector('.time');

		this.nodes = [];
		this.values = [];

		//# if scale = 1 then canvas width = container width
		this.scale = 3;

		this.canvas = this.container.querySelector('canvas');
		this.context = this.canvas.getContext('2d');

		this.container.addEventListener('mousedown', this.addListener);

		this.sequences = this.container.querySelector('.sequences');
		let template = this.container.querySelector('.template');

		//# Draw Phase
		this.phases = [];
		let iterable = __range__(0, this.beats.phases.length, false);
		for (let j = 0; j < iterable.length; j++) {
			let i = iterable[j];
			this.phases[i] = new Phase(this.beats.phases[i], this.beats.media.duration, this, template);
			this.sequences.appendChild(this.phases[i].element);
		}

		this.sequences.addEventListener('scroll', this.onScroll);
		this.onScroll();
	}

	set() {
	}

	resample(width, audioData) {
		// http://stackoverflow.com/questions/22073716/create-a-waveform-of-the-full-track-with-web-audio-api
		let j;
		let resampled = new Float64Array(width * 6);

		let i = j = 0;
		let buckIndex = 0;

		let min = 1e6;
		let max = -1e6;
		let value = 0;
		let res = 0;

		let sampleCount = audioData.length;

		//# First pass for mean
		i = 0;
		while (i < sampleCount) {
			//# In which bucket do we fall ?
			buckIndex = 0 | ((width * i) / sampleCount);
			buckIndex *= 6;

			//# Positive or negative ?
			value = audioData[i];
			if (value > 0) {
				resampled[buckIndex] += value;
				resampled[buckIndex + 1] += 1;
			} else if (value < 0) {
				resampled[buckIndex + 3] += value;
				resampled[buckIndex + 4] += 1;
			}

			if (value < min) {
				min = value;
			}
			if (value > max) {
				max = value;
			}

			i++;
		}

		//# Compute mean now
		i = j = 0;
		while (i < width) {
			if (resampled[j + 1] !== 0) {
				resampled[j] /= resampled[j + 1];
			}

			if (resampled[j + 4] !== 0) {
				resampled[j + 3] /= resampled[j + 4];
			}

			i++;
			j += 6;
		}

		//# Second pass for mean variation  ( variance is too low)
		i = 0;
		while (i < audioData.length) {
			//# In which bucket do we fall ?
			buckIndex = 0 | ((width * i) / audioData.length);
			buckIndex *= 6;

			//# Positive or negative ?
			value = audioData[i];
			if (value > 0) {
				resampled[buckIndex + 2] += Math.abs(resampled[buckIndex] - value);
			} else if (value < 0) {
				resampled[buckIndex + 5] += Math.abs(resampled[buckIndex + 3] - value);
			}

			i++;
		}

		//# Compute mean variation / variance now
		i = j = 0;
		while (i < width) {
			if (resampled[j + 1]) {
				resampled[j + 2] /= resampled[j + 1];
			}

			if (resampled[j + 4]) {
				resampled[j + 5] /= resampled[j + 4];
			}

			i++;
			j += 6;
		}

		return resampled;
	}

	draw() {
		// @context.clearRect( 0, 0, @width, @height )

		if ((this.beats.buffer == null) || this.done) {
			return;
		}
		this.done = true;

		// Draw beat
		// offset = @width / ( @beats.bpm * ( @beats.duration / 60 ) )
		// x = 0
		// while x < @canvasWidth

		// 	x += offset * 8

		// 	beat = document.createElement( 'div' )
		// 	beat.classList.add( 'beat' )
		// 	beat.style.left = x + 'px'
		// 	@sequences.appendChild( beat )

		let span = this.container.querySelector('.container-name span');
		span.innerText = '';

		let resampledData = this.resample(this.width * this.scale, this.beats.buffer.getChannelData(0));

		this.context.translate(0.5, this.height * 0.5);
		this.context.scale(1, 100);

		let i = 0;
		return (() => {
			let result = [];
			while (i < this.width * this.scale) {
				let j = i * 6;

				// Update from positiveAvg - variance to negativeAvg - variance
				this.context.strokeStyle = '#ffffff';
				this.context.beginPath();
				this.context.moveTo(i, resampledData[j] - ( resampledData[j + 2] ));
				this.context.lineTo(i, resampledData[j + 3] + resampledData[j + 5]);
				this.context.stroke();

				// Update from positiveAvg - variance to positiveAvg + variance
				this.context.beginPath();
				this.context.moveTo(i, resampledData[j] - ( resampledData[j + 2] ));
				this.context.lineTo(i, resampledData[j] + resampledData[j + 2]);
				this.context.stroke();

				// Update from negativeAvg + variance to negativeAvg - variance
				this.context.beginPath();
				this.context.moveTo(i, resampledData[j + 3] + resampledData[j + 5]);
				this.context.lineTo(i, resampledData[j + 3] - ( resampledData[j + 5] ));
				this.context.stroke();
				result.push(i++);
			}
			return result;
		})();
	}

	onScroll() {
		if (this.sequences.scrollLeft <= 10) {
			this.container.classList.add('hide-left');
		} else {
			this.container.classList.remove('hide-left');
		}

		if (this.sequences.scrollLeft >= this.sequences.scrollWidth - 10) {
			return this.container.classList.add('hide-right');
		} else {
			return this.container.classList.remove('hide-right');
		}
	}

	addListener(event) {
		if (this.dragged) {
			return;
		}

		this.moveTo(event);

		this.container.addEventListener('mousemove', this.moveTo);
		return this.container.addEventListener('mouseup', this.removeListener);
	}

	removeListener() {
		this.container.removeEventListener('mousemove', this.moveTo);
		return this.container.removeEventListener('mouseup', this.removeListener);
	}

	moveTo(event) {
		let progress = ( (event.clientX + this.sequences.scrollLeft) - this.container.offsetLeft ) / this.canvas.clientWidth;
		this.beats.media.currentTime = progress * this.beats.media.duration;

		let i = this.beats.phases.length;
		while (i--) {

			let phase = this.beats.phases[i];

			let { currentTime } = this.beats.media;
			let nextPhase = this.beats.phases[i + 1];
			let nextTime = (nextPhase != null) ? nextPhase.time : this.beats.duration;

			if (currentTime >= phase.time && currentTime <= nextTime && i !== this.beats.position) {

				this.beats.phases[i].initialize();
				this.beats.position = i;
			}
		}

		if (this.beats.media.paused) {
			return this.update();
		}
	}

	update() {
		let value = this.beats.media.currentTime / this.beats.media.duration;
		this.progress.style.left = (value * 100 * this.scale) + '%';
		this.time.innerText = this.beats.media.currentTime.toFixed(3);

		return this.draw();
	}

	resize() {
		this.width = this.container.clientWidth;
		this.height = this.container.clientHeight - this.name.offsetHeight;

		this.canvasWidth = this.width * this.scale;

		this.canvas.height = this.height;
		this.canvas.width = this.canvasWidth;

		let i = this.phases.length;
		while (i--) {
			this.phases[i].resize(this.canvasWidth);
		}

		this.done = false;
		this.draw();

		this.update();
		return this.set();
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
