module.exports = (buffers, assets, callback) =>

		if !window.AudioContext? then return
		audioContext = new AudioContext

		keys = Object.keys buffers
		length = keys.length - 1

		load = (name) =>

			source = buffers[ name ]

			request = new XMLHttpRequest()
			request.open "GET", source, true
			request.responseType = "arraybuffer"

			request.onload = =>

				audioContext.decodeAudioData \

					request.response
					,(decodedBuffer) =>

						assets.buffers[ name ] = decodedBuffer
						next()

					,(decodedBuffer) =>
						console.log 'Error during the load. Wrong url or cross origin issue'
						next()

			request.send()

		next = =>

			length--

			if length < 0 then callback()
			else load keys[ length ]

		load keys[ length ]
