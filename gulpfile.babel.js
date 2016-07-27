import gulp from 'gulp';
import watchify from 'watchify';
import browserify from 'browserify';
import uglify from 'gulp-uglify';
import sass from 'gulp-sass';
import livereload from 'gulp-livereload';
import gutil from 'gulp-util';
import sourcemaps from 'gulp-sourcemaps';
import rename from 'gulp-rename';
import source from 'vinyl-source-stream';
import buffer from 'vinyl-buffer';
import console from 'better-console';

// --- CONFIG

let build = gutil.env.type === 'build';

let sources = {
	app: 'assets/scripts/app.js',
	entry: './assets/scripts/app.js',
	scss: {
		index: 'assets/scss/index.scss',
		all: 'assets/scss/*.scss'
	}
};

let destinations = {
	app: '',
	js: 'assets/js/',
	css: 'assets/css'
};


//# Browserify

let entries = {
	engine: './assets/scripts/modules/example.js'
};


let handleError = function (error) {
	console.log(error.toString());
	return this.emit('end');
};

// --- TASKS

gulp.task('scripts', () =>
	browserify(sources.entry)
		.transform('babelify', {
			presets: ['es2015']
		})
		.bundle()
		.pipe(source('BEATS.js'))
		.pipe(buffer())
		.pipe(sourcemaps.init())
		//.pipe(uglify())
		.pipe(sourcemaps.write('./maps'))
		.pipe(gulp.dest(destinations.js))
);

gulp.task('app', () =>
	gulp.src(sources.app)
		.on('error', gutil.log.bind(gutil, 'App Error'))
		.pipe(coffee({bare: true}))
		.pipe(gulp.dest(''))
);

gulp.task('styles', () =>
	gulp.src(sources.scss.index)
		.pipe(sass({style: 'expanded', errLogToConsole: true}))
		.pipe(gulp.dest(destinations.css))
		.pipe(livereload())
);

gulp.task('watch', function () {
		livereload.listen();
		gulp.watch(sources.app, ['app']);
		gulp.watch(sources.coffee, ['scripts']);
		return gulp.watch(sources.scss.all, ['styles']);
	}
);


gulp.task('default', ['watch', 'scripts']);
