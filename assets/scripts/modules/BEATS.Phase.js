export default class Phase {

	constructor(time, values, parameters) {
		this.initialize = this.initialize.bind(this);
		this.time = time;
		this.values = values;
		if (this.values == null) {
			this.values = {};
		}
		if (parameters == null) {
			parameters = {};
		}

		this.name = parameters.name;

		this.onStart = parameters.onStart;
		this.onUpdate = parameters.onUpdate;
		this.onComplete = parameters.onComplete;
	}

	initialize() {
		let i = 0;
		return (() => {
			let result = [];
			while (i <= this.index) {
				for (let name in this.phases[i].values) {
					let values = this.phases[i].values[name];
					let j = this.keys.length;
					while (j--) {
						if (this.keys[j].name === name) {
							let key = this.keys[j];

							for (var parameter in values) {
								var value = values[parameter];
								key[parameter] = value;
							}
						}
					}

					j = this.modulators.length;
					while (j--) {
						if (this.modulators[j].name === name) {
							let modulator = this.modulators[j];

							for (var parameter in values) {
								var value = values[parameter];
								if (parameter === 'active') {
									modulator.active = value;
								} else {
									modulator.filter[parameter].value = value;
								}
							}
						}
					}
				}

				result.push(i++);
			}
			return result;
		})();
	}

}
