BEATS = require 'Beats'
require 'GUI'

audio   = new Audio()
context = new AudioContext

url     = 'audio/Walk.mp3'

initialize = ->

	audio.removeEventListener( 'canplaythrough', initialize )

	update = ->

		beats.update()
		beatsGUI.update()
		requestAnimationFrame( update )

	beats = new BEATS.Interface context, audio,
		destination  : context.destination
		fftSize      : 1024  ## Size of the Fast Fourier Transform
		levelCount   : 128   ## Must be a power of two
		mono         : false ## Down-mix from stereo to mono

		onProcessEnd : update

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
		name       : 'kick'
		modulator  : 'lowpass'
		active     : false
		threshold  : 0.9 ## Minimal value for callback
		delay      : 200 ## Delay between which the callback can be called
		callback   : -> console.log 'Kicked'

	beats.add new BEATS.Key 90, 120, 0.1, 0.35,
		name      : 'hit-hat'
		modulator : 'highpass1'
		active    : false

	beats.add new BEATS.Key 50, 90, 0.4, 0.5,
		name       : 'snare'
		modulator  : 'highpass2'
		type       : 'max'
		active     : false
		threshold  : 0.8
		delay      : 200

	beats.add new BEATS.Key 12, 30, 0.1, 0.35,
		name       : 'piano'
		smoothness : 10
		active     : true

	beats.add new BEATS.Key 68, 88, 0.08, 0.3,
		name       : 'effect'
		smoothness : 15
		active     : true


	beats.add new BEATS.Phase 27.550,

		'kick' :
			active : true
			min    : 0.88

		'snare'  : active : true
		'effect' : active : false
		'piano'  : active : false

	beats.add new BEATS.Phase 55.000,

		'hit-hat' : active : true

	beats.add new BEATS.Phase 82.500,

		'kick' :
			start : 1
			end   : 2
			min   : 0.88
			max   : 0.92

		'lowpass' :
			frequency : 100

	beatsGUI = new BEATS.GUI( beats )

audio.addEventListener( 'canplaythrough', initialize )
audio.src = url
