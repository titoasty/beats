gulp       = require 'gulp'
watchify   = require 'watchify'
browserify = require 'browserify'
sass       = require 'gulp-sass'
livereload = require 'gulp-livereload'
coffee     = require 'gulp-coffee'
gutil      = require 'gulp-util'
sourcemaps = require 'gulp-sourcemaps'
rename     = require 'gulp-rename'
source     = require 'vinyl-source-stream'
buffer     = require 'vinyl-buffer'
nodemon    = require 'gulp-nodemon'
console    = require 'better-console'

# --- CONFIG

build = gutil.env.type is 'build'

sources =
    app    : 'assets/coffee/app.coffee'
    coffee : [
        'assets/coffee/**/*.coffee',
        '!assets/coffee/app.coffee'
    ]
    scss :
        index : 'assets/scss/index.scss'
        all   : 'assets/scss/*.scss'

destinations =
    app  : ''
    js   : 'assets/js/'
    css  : 'assets/css'


## Nodemon
server = nodemon {
    script: 'app.js'
    ignore: [
      'assets/**'
    ]
}

## Browserify

entries =
    engine : './assets/coffee/modules/example.coffee'

options =

    entries    : './assets/coffee/modules/example.coffee'
    debug      : true
    transform  : [ 'coffeeify' ]
    extensions : [ '.coffee' ]
    paths: [

        './node_modules'

        './assets/js'
        './assets/js/modules'

        './assets/coffee'
        './assets/coffee/modules'
    ]

handleError = (error) ->

    console.log error.toString()
    @emit 'end'

# --- TASKS

gulp.task 'scripts', ->

    bundler = browserify options

    bundler.bundle()
    .on 'error', handleError
    .pipe source 'demo.bundle.js'
    .pipe buffer()
    .pipe sourcemaps.init({ loadMaps: true })
    .pipe sourcemaps.write( './maps' )
    .pipe gulp.dest destinations.js

gulp.task 'app', ->

    gulp.src sources.app
    .on 'error', gutil.log.bind(gutil, 'App Error')
    .pipe coffee({ bare: true })
    .pipe gulp.dest('')

gulp.task 'nodemon', ->

    ## Stop server and restart
    server.emit 'exit'
    server.emit 'restart'

gulp.task 'styles', ->

    gulp.src sources.scss.index
    .pipe sass({ style: 'expanded', errLogToConsole: true })
    .pipe gulp.dest destinations.css
    .pipe livereload()

gulp.task 'watch', ->

    livereload.listen()
    gulp.watch sources.app,      [ 'app' ]
    gulp.watch sources.coffee,   [ 'scripts' ]
    gulp.watch sources.scss.all, [ 'styles' ]


gulp.task 'default', [ 'watch', 'scripts' ]
