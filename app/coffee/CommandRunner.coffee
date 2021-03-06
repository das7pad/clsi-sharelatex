Settings = require "settings-sharelatex"
logger = require "logger-sharelatex"

if Settings.clsi?.dockerRunner == true
	commandRunnerPath = "./DockerRunner"
else 
	commandRunnerPath = "./LocalCommandRunner"
logger.info commandRunnerPath:commandRunnerPath, "selecting command runner for clsi"

if commandRunnerPath == "./DockerRunner"
	module.exports = require("./DockerRunner")
else
	module.exports = require("./LocalCommandRunner")
