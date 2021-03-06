Client = require "./helpers/Client"
request = require "request"
chai = require("chai")
chai.should()
fs = require "fs"
ChildProcess = require "child_process"
ClsiApp = require "./helpers/ClsiApp"
logger = require("logger-sharelatex")
Path = require("path")
fixturePath = (path) -> Path.normalize(__dirname + "/../fixtures/" + path)
process = require "process"
logger.log process.pid, process.ppid, process.getuid(),process.getgroups(), "PID"

if not fs.existsSync(fixturePath("tmp"))
	try
		logger.log "creating tmp directory", fixturePath("tmp")
		fs.mkdirSync(fixturePath("tmp"))
	catch err
		logger.fatal {err, path: fixturePath("tmp")}, "unable to create fixture tmp path"

MOCHA_LATEX_TIMEOUT = 60 * 1000

convertToPng = (pdfPath, pngPath, callback = (error) ->) ->
	command = "convert #{fixturePath(pdfPath)} #{fixturePath(pngPath)}"
	logger.log {command}, "COMMAND"
	convert = ChildProcess.exec command
	convert.stdout.on "data", (chunk) -> logger.log({command, chunk: chunk.toString()}, "convert STDOUT")
	convert.stderr.on "data", (chunk) -> logger.log({command, chunk: chunk.toString()}, "convert STDERR")
	convert.on "exit", () ->
		callback()

compare = (originalPath, generatedPath, callback = (error) ->) ->
	diff_file = "#{fixturePath(generatedPath)}-diff.png"
	proc = ChildProcess.exec "compare -metric mae #{fixturePath(originalPath)} #{fixturePath(generatedPath)} #{diff_file}"
	stderr = ""
	proc.stderr.on "data", (chunk) -> stderr += chunk
	proc.on "exit", () ->
		if stderr.trim() == "0 (0)"
			# remove output diff if test matches expected image
			fs.unlink diff_file, (err) ->
				if err
					logger.fatal({err, diff_file}, "cleanup failed")
					return callback(err)
				callback null
		else
			logger.fatal {originalPath, generatedPath, stderr}, "compare result"
			callback new Error('page does not match fixture')

checkPdfInfo = (pdfPath, callback = (error) ->) ->
	proc = ChildProcess.exec "pdfinfo #{fixturePath(pdfPath)}"
	stdout = ""
	proc.stdout.on "data", (chunk) -> stdout += chunk
	proc.stderr.on "data", (chunk) -> logger.log {pdfPath, chunk: chunk.toString()}, "pdfinfo STDERR"
	proc.on "exit", () ->
		if stdout.match(/Optimized:\s+yes/)
			callback null
		else
			callback new Error('pdf is not optimized')

compareMultiplePages = (project_id, callback = (error) ->) ->
	compareNext = (page_no, callback) ->
		path = "tmp/#{project_id}-source-#{page_no}.png"
		fs.stat fixturePath(path), (error, stat) ->
			if error?
				callback()
			else
				compare  "tmp/#{project_id}-source-#{page_no}.png", "tmp/#{project_id}-generated-#{page_no}.png", (error) =>
					return callback(error) if error?
					compareNext page_no + 1, callback
	compareNext 0, callback

comparePdf = (project_id, example_dir, callback = (error) ->) ->
	logger.log {project_id, example_dir}, "CONVERT"
	convertToPng "tmp/#{project_id}.pdf", "tmp/#{project_id}-generated.png", (error) =>
		return callback(error) if error?
		convertToPng "examples/#{example_dir}/output.pdf", "tmp/#{project_id}-source.png", (error) =>
			return callback(error) if error?
			fs.stat fixturePath("tmp/#{project_id}-source-0.png"), (error, stat) =>
				if error?
					compare  "tmp/#{project_id}-source.png", "tmp/#{project_id}-generated.png", callback
				else
					compareMultiplePages project_id, (error) ->
						return callback(error) if error?
						callback()

downloadAndComparePdf = (project_id, example_dir, url, callback = (error) ->) ->
	writeStream = fs.createWriteStream(fixturePath("tmp/#{project_id}.pdf"))
	request.get(url).pipe(writeStream)
	logger.log {project_id}, "writing file out"
	writeStream.on "close", () =>
		checkPdfInfo "tmp/#{project_id}.pdf", (error) =>
			return callback(error) if error?
			comparePdf project_id, example_dir, callback

Client.runServer(4242, fixturePath("examples"))


broken = [
	'asymptote',
	'feynmf',
	'feynmp',
	'glossaries',
	'hebrew',
	'knitr',
	'knitr_utf8',
	'latex_compiler',
	'makeindex-custom-style',
	'nomenclature',
]

describe "Example Documents", ->
	@timeout(10000)

	before (done) ->
		ChildProcess.exec("rm test/acceptance/fixtures/tmp/*").on "exit", () -> 
			ClsiApp.ensureRunning done


	for example_dir in fs.readdirSync fixturePath("examples")
		if example_dir in broken
			continue
		do (example_dir) ->
			describe example_dir, ->
				before ->
					@project_id = Client.randomId() + "_" + example_dir

				it "should generate the correct pdf", (done) ->
					this.timeout(MOCHA_LATEX_TIMEOUT)
					Client.compileDirectory @project_id, fixturePath("examples"), example_dir, 4242, (error, res, body) =>
						if error || body?.compile?.status is "failure"
							logger.fatal {error, example_dir, body: JSON.stringify(body) }, "compile error"
							return done(new Error("Compile failed"))
						pdf = Client.getOutputFile body, "pdf"
						downloadAndComparePdf(@project_id, example_dir, pdf.url, done)

				it "should generate the correct pdf on the second run as well", (done) ->
					this.timeout(MOCHA_LATEX_TIMEOUT)
					Client.compileDirectory @project_id, fixturePath("examples"), example_dir, 4242, (error, res, body) =>
						if error || body?.compile?.status is "failure"
							logger.fatal {error, example_dir, body: JSON.stringify(body) }, "compile error"
							return done(new Error("Compile failed"))
						pdf = Client.getOutputFile body, "pdf"
						downloadAndComparePdf(@project_id, example_dir, pdf.url, done)
