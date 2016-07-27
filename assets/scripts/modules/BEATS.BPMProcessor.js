export default class BPMProcessor {

	constructor(buffer) {
		this.start = this.start.bind(this);
		this.process = this.process.bind(this);
		this.identifyIntervals = this.identifyIntervals.bind(this);
		this.groupByTempo = this.groupByTempo.bind(this);
		this.minThreshold = 0.3;
		this.minPeaks = 15;

		this.offlineContext = new OfflineAudioContext(1, buffer.length, buffer.sampleRate);

		this.source = this.offlineContext.createBufferSource();
		this.source.buffer = buffer;

		//# Pipe the buffer into the filter
		let filter = this.offlineContext.createBiquadFilter();
		filter.type = 'lowpass';
		this.source.connect(filter);

		//# And the filter into the offline context
		filter.connect(this.offlineContext.destination);

		//# Process the data when the context finish rendering
		this.offlineContext.addEventListener('complete', this.process);
	}

	start() {
		this.source.start(0);
		return this.offlineContext.startRendering();
	}

	process(event) {
		let buffer = event.renderedBuffer;

		//# Get a Float32Array containing the PCM data
		let data = buffer.getChannelData(0);

		let peaks = [];

		//# Track a threshold volume level
		let min = BEATS.Utils.getArrayMin(data);
		let max = BEATS.Utils.getArrayMax(data);

		let threshold = min + ( max - min );

		while (peaks.length < this.minPeaks && threshold >= this.minThreshold) {
			peaks = this.getPeaksAtThreshold(data, threshold);
			threshold -= 0.02;
		}

		if (peaks.length < this.minPeaks) {
			throw new Error('Could not find enough samples for a reliable detection');
			return;
		}

		//# Count intervals between peaks
		let intervals = this.identifyIntervals(peaks);
		let tempos = this.groupByTempo(intervals);

		tempos.sort((a, b) => b.count - a.count);
		return __guardFunc__(this.onProcessEnd, f => f(tempos[0].tempo));
	}

	getPeaksAtThreshold(data, threshold) {
		let result = [];

		let i = 0;
		while (i < data.length) {
			if (data[i] > threshold) {
				result[result.length++] = i;
				i += 10000;
			}

			i++;
		}

		return result;
	}

	identifyIntervals(peaks) {
		let counts = [];

		peaks.forEach(function (peak, index) {
			let i = 0;
			return (() => {
				let result1 = [];
				while (i < 10) {
					let interval = peaks[index + i] - peak;

					let result = counts.some(function (counts) {
						if (counts.interval === interval) {
							return counts.count++;
						}
					});

					if (!isNaN(interval) && interval !== 0 && !result) {
						counts[counts.length++] = {interval, count: 1};
					}

					result1.push(i++);
				}
				return result1;
			})();
		});

		return counts;
	}

	groupByTempo(counts) {
		let results = [];

		counts.forEach(function (count) {
			if (count.interval === 0) {
				return;
			}

			//# Convert an interval to tempo
			let theoreticalTempo = 60 / ( count.interval / 44100 );

			//# Adjust the tempo to fit within the 90-180 BPM range
			while (theoreticalTempo < 90) {
				theoreticalTempo *= 2;
			}
			while (theoreticalTempo > 180) {
				theoreticalTempo /= 2;
			}

			//# Round to legible integer
			theoreticalTempo = Math.round(theoreticalTempo);

			let foundTempo = results.some(function (result) {
				if (result.tempo === theoreticalTempo) {
					return result.count += count.count;
				}
			});

			if (!foundTempo) {
				return results[results.length++] = {
					tempo: theoreticalTempo,
					count: count.count
				};
			}
		});

		return results;
	}
};

function __guardFunc__(func, transform) {
	return typeof func === 'function' ? transform(func) : undefined;
}
