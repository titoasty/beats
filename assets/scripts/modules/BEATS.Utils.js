export default {

	getArrayMin(data) {
		let min = Infinity;

		let i = data.length;
		while (i--) {
			if (data[i] < min) {
				min = data[i];
			}
		}

		return min;
	},

	getArrayMax(data) {
		let max = -Infinity;

		let i = data.length;
		while (i--) {
			if (data[i] > max) {
				max = data[i];
			}
		}

		return max;
	},

	stereoToMono(audioBuffer) {

		let buffer = audioBuffer;
		if (buffer.numberOfChannels = 2) {
			//# Get each audio buffer's channel
			let leftChannel = buffer.getChannelData(0);
			let rightChannel = buffer.getChannelData(1);

			let i = buffer.length;
			while (i--) {
				//# Get the average
				let mixedChannel = 0.5 * ( leftChannel[i] + rightChannel[i] );
				leftChannel[i] = rightChannel[i] = mixedChannel;
			}

			buffer.numberOfChannels = 1;
		}

		return buffer;
	}
}
