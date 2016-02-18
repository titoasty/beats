BEATS = require 'Beats'
require 'Beats.GUI'

audioContext =  new AudioContext

# Create an audio element
audio = new Audio()

url = 'audio/Walk.mp3'

audio.src      = url
audio.controls = true
audio.autoplay = false
audio.loop     = true

ready = false

audio.oncanplaythrough = ->

	if @readyState != 4 || ready == true then return
	ready = true

	# Create media element source node
	input = audioContext.createMediaElementSource audio
	input.mediaElement.play()
	input.mediaElement.currentTime = 28

	## Initialize Beats interface to handle Keys and Modulators
	beats = new BEATS.Interface audioContext, input,
		destination : audioContext.destination
		fftSize     : 1024  ## Size of the Fast Fourier Transform
		levelCount  : 128   ## Must be a power of two
		mono        : false ## Down-mix from stereo to mono


	beats.add new BEATS.Modulator 'lowpass', 440,
		name   : 'lowpass'
		active : true
		Q      : 1
		gain   : 2

	beats.add new BEATS.Modulator 'highpass', 10000,
		name   : 'highpass1'
		active : true
		Q      : 1
		gain   : 2

	beats.add new BEATS.Modulator 'highpass', 2000,
		name   : 'highpass2'
		active : true
		Q      : 1
		gain   : 2


	beats.add new BEATS.Key 1.0, 2.0, 0.8, 0.9,
		name      : 'kick'
		modulator : 'lowpass'
		active    : false
		threshold : 0.9 ## Minimal value for callback
		delay     : 200 ## Delay between the callback can be called
		callback  : -> console.log 'Kicked'

	beats.add new BEATS.Key 90, 120, 0.1, 0.35,
		name      : 'hit-hat'
		modulator : 'highpass1'
		active    : false

	beats.add new BEATS.Key 50, 90, 0.4, 0.5,
		name      : 'snare'
		modulator : 'highpass2'
		type      : 'max'
		active    : false
		threshold : 0.9
		delay     : 200

	beats.add new BEATS.Key 12, 30, 0.1, 0.35,
		name   : 'piano'
		active : true

	beats.add new BEATS.Key 68, 88, 0.08, 0.3,
		name   : 'effect'
		active : true


	sequences = [
		[
			27
			onStart : =>

				beats.get( 'kick' ).active = true
				beats.get( 'kick' ).min    = 0.88

				beats.get( 'snare' ).active  = true
				beats.get( 'effect' ).active = false
				beats.get( 'piano' ).active  = false
		]
		[
			54
			onStart : =>
				beats.get( 'hit-hat' ).active = true
		]
		[
			82
			onStart : =>
				beats.get( 'kick' ).set 1, 2, 0.88, 0.92
				beats.get( 'lowpass' ).filter.frequency.value = 100
		]
	]

	sequencer = beats.add new BEATS.Sequencer
		onChange  : -> console.log 'Sequence change'
		sequences : sequences


	beats.active = true

	beatsGUI = new BEATS.GUI beats
	sequencer.onChange = => beatsGUI.updateKeys()



	## Update loop
	startTime = performance.now()
	oldTime   = startTime

	frameRate = 30
	interval  = 1000 / frameRate

	update = ->

		newTime  = performance.now()
		delta    = newTime - oldTime

		## Control draw loop frame rate
		if delta > interval

			oldTime = newTime - ( delta % interval )
			beats.update()
			beatsGUI.update()

		requestAnimationFrame update

	update()
