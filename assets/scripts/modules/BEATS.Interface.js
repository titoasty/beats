export default class Interface {

	constructor(context, audio, parameters) {
		this.getSpectrum = this.getSpectrum.bind(this);
		this.computeBPM = this.computeBPM.bind(this);
		this.update = this.update.bind(this);
		this.context = context;
		this.keys = [];
		this.modulators = [];
		this.phases = [];

		//# Add a default first phase
		this.phases[0] = new BEATS.Phase(0);

		//# Initialize sequencer position
		this.position = 0;

		//# Create audio source node
		this.input = this.context.createMediaElementSource(audio);

		//# Load source to an audio buffer
		this.loadBuffer(audio.src);

		//# Default analyser
		this.analyser = this.context.createAnalyser();
		// @input.channelCount = 1 if parameters.mono
		this.input.connect(this.analyser);

		this.media = this.input.mediaElement;
		this.duration = this.media.duration;
		this.active = true;

		//# Connect the analyser to the destination
		this.destination = parameters.destination;
		if (this.destination != null) {
			//# Connect analyser to the audio context destination
			this.analyser.connect(this.destination);

			//# Set the analyser as output
			this.output = this.analyser;
		}

		if (parameters.fftSize) {
			this.analyser.fftSize = parameters.fftSize;
		}

		if (parameters.smoothingTimeConstant) {
			this.analyser.smoothingTimeConstant = parameters.smoothingTimeConstant;
		}

		//# Create typed array to store data
		this.analyser.frequencyData = new Uint8Array(this.analyser.frequencyBinCount);
		this.analyser.timeDomainData = new Uint8Array(this.analyser.frequencyBinCount);

		//# Create typed array to store normalized data
		this.analyser.normalizedFrequencyData = new Float32Array(this.analyser.frequencyBinCount);
		this.analyser.normalizedTimeDomainData = new Float32Array(this.analyser.frequencyBinCount);

		//# Restrict level counts
		if (parameters.levelCount != null) {
			this.setLevelCount(parameters.levelCount);
		}

		//# Update the default analyser once on start
		this.getSpectrum(this.analyser, true);
		this.getWaveform(this.analyser, true);

		this.onLoading = parameters.onLoading;
		this.onProcessEnd = parameters.onProcessEnd;
	}

	setLevelCount(levelCount) {
		//# Create typed array to store data, with a length equal to level count
		this.levelCount = levelCount;
		this.levelStep = this.analyser.frequencyBinCount / this.levelCount;
		return this.analyser.levels = new Float32Array(this.levelCount);
	}

	loadBuffer(url) {
		let request = new XMLHttpRequest();
		request.open("GET", url, true);
		request.responseType = "arraybuffer";

		let onSuccess = buffer => {
			this.buffer = buffer;

			// Get the bpm when the array buffer is decoded
			return this.computeBPM();
		};

		let onError = function () {
			throw new Error(`Error decoding the file ${error}`);
		};

		request.onload = () => {
			//# If the request succeed then decode audio data
			return this.context.decodeAudioData(request.response, onSuccess, onError);
		};

		request.onprogress = event => {
			return __guardFunc__(this.onLoading, f => f(event.loaded / event.total));
		};

		request.onerror = function (error) {
			throw new Error(`Error loading the file${error}`);
		};

		return request.send();
	}

	getSpectrum(analyser, normalized) {
		//# Get raw data
		analyser.getByteFrequencyData(analyser.frequencyData);
		let spectrum = analyser.frequencyData;

		//# Compute normalized values
		if (normalized) {
			var i = analyser.frequencyData.length;
			while (i--) {
				analyser.normalizedFrequencyData[i] = analyser.frequencyData[i] / 256;
			}

			spectrum = analyser.normalizedFrequencyData;
		}

		//# Compute sampled values
		if (this.levelCount != null) {
			var i = this.levelCount;
			while (i--) {

				let start = i * this.levelStep;
				let end = (( i + 1 ) * this.levelStep) - 1;

				analyser.levels[i] = this.getFrequency(spectrum, start, end);
			}

			spectrum = analyser.levels;
		}

		analyser.spectrum = spectrum;
		return spectrum;
	}

	getWaveform(analyser, normalized) {
		//# Get raw data
		analyser.getByteTimeDomainData(analyser.timeDomainData);
		let waveform = analyser.timeDomainData;

		//# Compute normalized values
		if (normalized) {
			let i = analyser.timeDomainData.length;
			while (i--) {
				analyser.normalizedTimeDomainData[i] = ( analyser.timeDomainData[i] - 128 ) / 128;
			}

			waveform = analyser.normalizedTimeDomainData;
		}

		analyser.waveform = waveform;
		return waveform;
	}

	getFrequency(spectrum, start, end) {
		//# Get the average frequency between start and end
		if (end - start > 1) {
			//# Sum up selected frequencies
			let sum = 0;
			let iterable = __range__(start, end, true);
			for (let j = 0; j < iterable.length; j++) {
				let i = iterable[j];
				sum += spectrum[i];
			}

			//# Divide by length
			return sum / ( (end - start) + 1 );
		} else {
			return spectrum[start];
		}
	}

	getMaxFrequency(spectrum, start, end) {
		let max = 0;
		if (end == null) {
			end = start;
		}

		let iterable = __range__(start, end, true);
		for (let j = 0; j < iterable.length; j++) {
			let i = iterable[j];
			if (spectrum[i] > max) {
				max = spectrum[i];
			}
		}

		return max;
	}

	computeBPM() {
		this.BPMProcessor = new BEATS.BPMProcessor(this.buffer);
		this.BPMProcessor.onProcessEnd = result => {
			this.bpm = result;
			return (this.onProcessEnd() != null);
		};

		return this.BPMProcessor.start();
	}

	add(object) {
		if (object instanceof BEATS.Modulator) {
			if (object.name == null) {
				modulator.name = `M|${this.modulators.length}`;
			}

			//# The context is needed to create a filter and an analyser
			object.context = this.context;
			object.set();

			//# Create a typed array to receive normalized data
			object.analyser.levels = new Float32Array(this.levelCount);

			//# Update the modulator analyser once when added
			this.getSpectrum(object.analyser, true);
			this.getWaveform(object.analyser, true);

			this.input.connect(object.filter);

			//# Add modulator to the interface
			this.modulators[this.modulators.length++] = object;
		}

		if (object instanceof BEATS.Key) {
			if (object.name == null) {
				object.name = `K|${this.keys.length}`;
			}
			object.index = this.keys.length;

			//# Add key to the interface
			this.keys[this.keys.length++] = object;
		}

		if (object instanceof BEATS.Phase) {
			//# Add phase to the interface
			this.phases[this.phases.length++] = object;

			//# Sort phases according to their time
			this.phases.sort((a, b) => {
					if (a.time > b.time) {
						return 1;
					}
					if (a.time < b.time) {
						return -1;
					}

					return 0;
				}
			);

			object.keys = this.keys;
			object.modulators = this.modulators;
			object.phases = this.phases;

			var i = this.phases.length;
			while (i--) {
				this.phases[i].index = i;
			}
		}

		//# Set the first phase which contains the original values of the keys and modulators
		this.phases[0].keys = this.keys;
		this.phases[0].modulators = this.modulators;
		this.phases[0].phases = this.phases;

		var i = this.keys.length;
		while (i--) {
			let key = this.keys[i];
			var values = this.phases[0].values[key.name] = {};

			for (var name in key) {
				let value = key[name];
				if (typeof value !== "function") {
					values[name] = value;
				}
			}
		}

		i = this.modulators.length;
		while (i--) {
			var modulator = this.modulators[i];
			var values = this.phases[0].values[modulator.name] = {};

			values.active = modulator.active;

			for (var name in modulator.filter) {
				let parameter = modulator.filter[name];
				if (name === 'frequency' || name === 'Q' || name === 'gain') {
					values[name] = parameter.value;
				}
			}
		}
	}

	remove(object) {
		//# Find the object type
		switch (object.constructor.name) {
			case 'Modulator':
				var objects = this.modulators;
				break;
			case 'Key':
				objects = this.keys;
				break;
			case 'Sequencer':
				objects = this.sequencer;
				break;
			default:

				throw new Error('Unknown object type');
				return;
		}

		//# Find the object according to type
		let i = objects.length;
		return (() => {
			let result = [];
			while (i--) {
				let item;
				if (objects[i] === object) {
					item = objects.splice(i, 1);
				}
				result.push(item);
			}
			return result;
		})();
	}

	get(name) {
		//# Get object by name
		if (typeof name === 'string') {
			//# Loop through keys
			let i = this.keys.length;
			while (i--) {
				if (this.keys[i].name === name) {
					return this.keys[i];
				}
			}

			//# Loop through modulators
			i = this.modulators.length;
			while (i--) {
				if (this.modulators[i].name === name) {
					return this.modulators[i];
				}
			}

		} else {
			throw new Error(`Can't find object named : ${name}`);
			return;
		}
	}

	update() {
		if ((this.media == null) || this.media.paused || !this.active) {
			return;
		}

		//# Update time and progression
		this.currentTime = this.media.currentTime;
		this.progress = this.currentTime / this.duration;

		//# Update main analyser
		this.getSpectrum(this.analyser, true);
		this.getWaveform(this.analyser, true);

		//# Update modulators analyser
		let i = this.modulators.length;
		while (i--) {
			var modulator = this.modulators[i];
			if (!modulator.active) {
				continue;
			}

			let { analyser } = modulator;

			this.getSpectrum(analyser, true);
			this.getWaveform(analyser, true);
		}

		//# Update keys value
		i = this.keys.length;
		while (i--) {
			let key = this.keys[i];
			var modulator = null;

			//# Check if the key needs to be modulated
			if (key.modulator != null) {
				modulator = this.get(key.modulator);
			}

			//# Check if the modulator exists and is active
			if ((modulator != null) && modulator.active) {
				var { spectrum } = modulator.analyser;

				//# Else use the default spectrum
			} else {
				var { spectrum } = this.analyser;
			}

			//# Get the average or the maximal frequency according to key type
			if (key.type === "average") {
				var frequency = this.getFrequency(spectrum, key.start, key.end);

			} else if (key.type === "max") {
				var frequency = this.getMaxFrequency(spectrum, key.start, key.end);
			}

			key.update(frequency);
		}

		//# Update sequencer
		if (this.phases.length > 0) {
			//# Call current phase update callback
			__guardFunc__(this.phases[this.position].onUpdate, f => f());

			let nextPhase = this.phases[this.position + 1];
			let nextTime = (nextPhase != null) ? nextPhase.time : this.duration;

			if (this.currentTime >= nextTime) {
				//# Call current phase end callback
				__guardFunc__(this.phases[this.position].onComplete, f1 => f1());

				//# Return if it is the last phase
				if (nextPhase == null) {
					return;
				}

				//# Update position to switch to next phase
				this.position++;

				//# Set keys and modulators values for the new phase
				this.phases[this.position].initialize();

				//# Call new phase start callback
				__guardFunc__(this.phases[this.position].onStart, f2 => f2());

				//# Call interface on phase change event
				return __guardFunc__(this.onPhaseChange, f3 => f3());
			}
		}
	}
}

function __guardFunc__(func, transform) {
	return typeof func === 'function' ? transform(func) : undefined;
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
