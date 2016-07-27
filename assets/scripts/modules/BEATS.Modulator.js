export default class Modulator {

	constructor(type, frequency, parameters) {
		//# Filter property
		this.type = type;
		this.frequency = frequency;
		this.Q = parameters.Q;
		this.gain = parameters.gain;

		//# Modulator property
		this.name = parameters.name;
		this.active = parameters.active;
	}

	set(frequency, Q, gain) {
		//# Create filter and analyser
		this.filter = this.context.createBiquadFilter();
		this.analyser = this.context.createAnalyser();
		this.filter.connect(this.analyser);

		//# Create typed array to store data
		this.analyser.frequencyData = new Uint8Array(this.analyser.frequencyBinCount);
		this.analyser.timeDomainData = new Uint8Array(this.analyser.frequencyBinCount);

		//# Create typed array to store normalized data
		this.analyser.normalizedFrequencyData = new Float32Array(this.analyser.frequencyBinCount);
		this.analyser.normalizedTimeDomainData = new Float32Array(this.analyser.frequencyBinCount);

		this.filter.type = this.type;
		this.filter.frequency.value = this.frequency;

		if ((this.filter.Q != null) && (this.Q != null)) {
			this.filter.Q.value = this.Q;
		}
		if ((this.filter.gain != null) && (this.gain != null)) {
			return this.filter.gain.value = this.gain;
		}
	}

}
