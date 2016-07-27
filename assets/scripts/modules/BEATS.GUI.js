import dat from 'dat-gui';

import Outcome from './gui/Outcome';
import Spectrum from './gui/Spectrum';
import Track from './gui/Track';

import colors from './gui/colors';

export default class GUI {

	constructor(beats) {
		this.start = this.start.bind(this);
		this.pause = this.pause.bind(this);
		this.changeOutput = this.changeOutput.bind(this);
		this.repeatPhase = this.repeatPhase.bind(this);
		this.updateKeys = this.updateKeys.bind(this);
		this.resize = this.resize.bind(this);
		this.beats = beats;
		this.beats.media.controls = true;
		this.beats.media.autoplay = false;

		//# Initialize dat.GUI
		this.gui = new dat.GUI();

		//# Override dat.GUI style
		document.head.appendChild(document.querySelector('.main-style'));

		//# Initial output (which analyser will be shown)
		this.output = this.beats.analyser;

		this.outcome = new Outcome(this.beats);
		this.spectrum = new Spectrum(this.beats, this.changeOutput);
		this.track = new Track(this.beats);

		//# Set dat controls
		this.setControllers();

		addEventListener('resize', this.resize, true);
		addEventListener('keydown', this.pause, false);

		//# Resize once on start
		this.resize();
	}

	start() {
		return document.querySelector('.overlay').classList.add('hide');
	}

	pause(event) {
		if (event.keyCode === 32) {
			event.preventDefault();

			let { media } = this.beats;
			if (media.paused) {
				return media.play();
			} else {
				return media.pause();
			}
		} else {
			return;
		}
	}

	changeOutput(output) {
		//# Swicth output
		this.beats.output.disconnect(0);
		this.beats.output = output;
		return this.beats.output.connect(this.beats.destination);
	}

	repeatPhase(value) {
		this.loop = null;

		let i = this.phasesNames.length;
		while (i--) {
			//# Get the index of the phase
			if (value !== this.phasesNames[i] || this.phasesNames[i] === 'none') {
				continue;
			} else {
				var index = i - 1;
			}
		}

		if (index == null) {
			return;
		}

		//# Store loop parameters
		this.loop = {
			index,
			start: this.beats.phases[index],
			end: this.beats.phases[index + 1] || this.beats.duration
		};

		//# Update media current time
		this.beats.media.currentTime = this.loop.start.time;
		this.beats.position = this.loop.index;

		return this.update(true);
	}

	updateKeys() {
		let i = this.spectrum.keys.length;
		return (() => {
			let result = [];
			while (i--) {
				result.push(this.spectrum.keys[i].update());
			}
			return result;
		})();
	}

	setControllers() {
		let key;
		var folder;
		let folders = this.gui.addFolder('General');
		folders.add(this.beats.media, 'playbackRate', [0.5, 1.0, 1.5, 2.0]).name('playbackRate');

		//# Add controller to repear a phase
		let phases = {repeat: null};
		this.phasesNames = ['none'];

		let i = this.beats.phases.length;
		while (i--) {
			this.phasesNames[this.phasesNames.length++] = ( `000${i}` ).substr(-3);
		}

		folders.add(phases, 'repeat', this.phasesNames).name('repeatPhase')
			.onChange(this.repeatPhase);

		//# Store name of modulators to be able to change it in keys controllers
		let modulatorsNames = ['none'];

		folders = this.gui.addFolder('Modulators');
		let { modulators } = this.beats;

		let iterable = __range__(0, this.beats.modulators.length, false);
		for (let j = 0; j < iterable.length; j++) {

			i = iterable[j];
			let modulator = this.beats.modulators[i];

			//# Add folder for each modulator and store its name
			var folder = folders.addFolder(modulator.name);
			modulatorsNames[modulatorsNames.length++] = modulator.name;

			let { filter } = modulator;

			let frequency = folder.add(filter.frequency, 'value', 0, 40000);
			frequency.name('frequency');

			folder.add(filter.Q, 'value', 0, 10).name('Q');
			folder.add(filter.gain, 'value', 0, 10).name('gain');
		}

		folders = this.gui.addFolder('Keys');
		let { keys }    = this.beats;

		return __range__(0, this.beats.keys.length, false).map((i) =>
			(key = this.beats.keys[i],
				//# Add folder for each key
				folder = folders.addFolder(key.name),

				folder.add(key, 'active').listen().onChange(this.updateKeys),
				folder.add(key, 'type', ['average', 'max']).listen().onChange(this.updateKeys),
				folder.add(key, 'start', 0, this.levelCount).listen().step(1).onChange(this.updateKeys),
				folder.add(key, 'end', 0, this.levelCount).listen().step(1).onChange(this.updateKeys),
				folder.add(key, 'min', 0, 1).listen().step(0.01).onChange(this.updateKeys),
				folder.add(key, 'max', 0, 1).listen().step(0.01).onChange(this.updateKeys),
				folder.add(key, 'smoothness', 1, 100).listen().onChange(this.updateKeys),

				folder.add(key, 'modulator', modulatorsNames).listen().onChange(this.updateKeys)));
	}

	update(force) {
		//# Loop through one phase if the parameters is set
		if ((this.loop != null) && this.beats.currentTime >= this.loop.end.time) {
			this.beats.media.currentTime = this.loop.start.time;
			this.beats.position = this.loop.index;
		}

		if (!this.outcome.initialize) {
			force = true;
			this.start();
		}

		//# Update all the UI element
		if (((this.beats.media != null) && !this.beats.media.paused) || force) {
			this.outcome.update();
			this.spectrum.update(this.beats.output);
			this.track.update();

			return force = false;
		}
	}

	resize() {

		this.outcome.resize();
		this.spectrum.resize();
		return this.track.resize();
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
