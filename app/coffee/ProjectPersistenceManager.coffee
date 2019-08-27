UrlCache = require "./UrlCache"
CompileManager = require "./CompileManager"
db = require "./db"
dbQueue = require "./DbQueue"
async = require "async"
logger = require "logger-sharelatex"
oneDay = 24 * 60 * 60 * 1000
Settings = require "settings-sharelatex"

module.exports = ProjectPersistenceManager =

	EXPIRY_TIMEOUT: Settings.project_cache_length_ms || oneDay * 2.5

	markProjectAsJustAccessed: (project_id, callback = (error) ->) ->
		job = (cb)->
			db.Project.findOrCreate(where: {project_id: project_id})
				.spread(
					(project, created) ->
						project.update(lastAccessed: new Date())
							.then(() -> cb())
							.error cb
				)
				.error cb
		dbQueue.queue.push(job, callback)


	clearExpiredProjects: (callback = (error) ->) ->
		ProjectPersistenceManager._findExpiredProjectIds (error, project_ids) ->
			return callback(error) if error?
			logger.log project_ids: project_ids, "clearing expired projects"
			jobs = for project_id in (project_ids or [])
				do (project_id) ->
					(callback) ->
						ProjectPersistenceManager.clearProjectFromCache project_id, (err) ->
							if err?
								logger.error err: err, project_id: project_id, "error clearing project"
							callback()
			async.series jobs, (error) ->
				return callback(error) if error?
				CompileManager.clearExpiredProjects ProjectPersistenceManager.EXPIRY_TIMEOUT, (error) ->
					callback() # ignore any errors from deleting directories

	clearProject: (project_id, user_id, callback = (error) ->) ->
		logger.log project_id: project_id, user_id:user_id, "clearing project for user"
		CompileManager.clearProject project_id, user_id, (error) ->
			return callback(error) if error?
			ProjectPersistenceManager.clearProjectFromCache project_id, (error) ->
				return callback(error) if error?
				callback()

	clearProjectFromCache: (project_id, callback = (error) ->) ->
		logger.log project_id: project_id, "clearing project from cache"
		UrlCache.clearProject project_id, (error) ->
			if error?
				logger.err error:error, project_id: project_id, "error clearing project from cache"
				return callback(error) 
			ProjectPersistenceManager._clearProjectFromDatabase project_id, (error) ->
				if error?
					logger.err error:error, project_id:project_id, "error clearing project from database"
				callback(error)

	_clearProjectFromDatabase: (project_id, callback = (error) ->) ->
		logger.log project_id:project_id, "clearing project from database"
		job = (cb)->
			db.Project.destroy(where: {project_id: project_id})
				.then(() -> cb())
				.error cb
		dbQueue.queue.push(job, callback)


	_findExpiredProjectIds: (callback = (error, project_ids) ->) ->
		job = (cb)->
			keepProjectsFrom = new Date(Date.now() - ProjectPersistenceManager.EXPIRY_TIMEOUT)
			q = {}
			q[db.op.lt] = keepProjectsFrom
			db.Project.findAll(where:{lastAccessed:q})
				.then((projects) ->
					cb null, projects.map((project) -> project.project_id)
				).error cb

		dbQueue.queue.push(job, callback)


logger.log {EXPIRY_TIMEOUT: ProjectPersistenceManager.EXPIRY_TIMEOUT}, "project assets kept timeout"
