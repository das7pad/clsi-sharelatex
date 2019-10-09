fs = require "fs"
Path = require "path"
spawn = require("child_process").spawn
logger = require "logger-sharelatex"
Metrics = require "./Metrics"
_ = require "underscore"

module.exports = OutputFileOptimiser =

	optimiseFile: (src, callback = (error) ->) ->
		# check output file (src) and see if we can optimise it inplace
		if src.match(/\/output\.pdf$/)
			OutputFileOptimiser.checkIfPDFIsOptimised src, (err, isOptimised) ->
				return callback(null) if err? or isOptimised
				OutputFileOptimiser.optimisePDF src, callback
		else
			callback (null)

	checkIfPDFIsOptimised: (file, callback) ->
		SIZE = 16*1024 # check the header of the pdf
		# fill with 0 to prevent leakage of uninitialised buffer
		result = Buffer.alloc(SIZE, 0)
		fs.open file, "r", (err, fd) ->
			return callback(err) if err?
			fs.read fd, result, 0, SIZE, 0, (errRead, bytesRead, buffer) ->
				fs.close fd, (errClose) ->
					return callback(errRead) if errRead?
					return callback(errClose) if errReadClose?
					isOptimised = buffer.toString('ascii').indexOf("/Linearized 1") >= 0
					callback(null, isOptimised)

	optimisePDF: (src, callback = (error) ->) ->
		tmpOutput = src + '.opt'
		args = ["--linearize", src, tmpOutput]
		logger.log args: args, "running qpdf command"

		timer = new Metrics.Timer("qpdf")
		proc = spawn("qpdf", args)
		stdout = ""
		proc.stdout.on "data", (chunk) ->
			stdout += chunk.toString()
		callback = _.once(callback) # avoid double call back for error and close event
		proc.on "error", (err) ->
			logger.warn {err, args}, "qpdf failed"
			callback(null) # ignore the error
		proc.on "close", (code) ->
			timer.done()
			if code != 0
				logger.warn {code, args}, "qpdf returned error"
				return callback(null) # ignore the error
			fs.rename tmpOutput, src, (err) ->
				if err?
					logger.warn {tmpOutput, src}, "failed to rename output of qpdf command"
				callback(null) # ignore the error
