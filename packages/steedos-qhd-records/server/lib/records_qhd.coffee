schedule = Npm.require('node-schedule')

RecordsQHD = {}

#	*    *    *    *    *    *
#	┬    ┬    ┬    ┬    ┬    ┬
#	│    │    │    │    │    |
#	│    │    │    │    │    └ day of week (0 - 7) (0 or 7 is Sun)
#	│    │    │    │    └───── month (1 - 12)
#	│    │    │    └────────── day of month (1 - 31)
#	│    │    └─────────────── hour (0 - 23)
#	│    └──────────────────── minute (0 - 59)
#	└───────────────────────── second (0 - 59, OPTIONAL)

logger = new Logger 'Records_QHD'

RecordsQHD.settings_records_qhd = Meteor.settings.records_qhd

RecordsQHD.test = () ->
	logger.debug "[#{new Date()}]run RecordsQHD.test"

RecordsQHD.scheduleJobMaps = {}

RecordsQHD.run = ()->
	try
		RecordsQHD.instanceToArchive();
	catch  e
		console.error "RecordsQHD.instanceToArchive", e

RecordsQHD.instanceToArchive = (ins_ids)->

	spaces = RecordsQHD.settings_records_qhd.spaces

	to_archive_sett = RecordsQHD.settings_records_qhd.to_archive

	archive_server = to_archive_sett.archive_server

	flows = to_archive_sett?.contract_instances?.flows

	to_archive_api = to_archive_sett?.non_contract_instances?.to_archive_api

	contract_archive_api = to_archive_sett?.contract_instances?.to_archive_api

	if !spaces
		logger.error "缺少settings配置: records-qhd.spaces"
		return

	if !archive_server
		logger.error "缺少settings配置: records-qhd.to_archive_sett.archive_server"
		return

	if !flows
		logger.error "缺少settings配置: records-qhd.to_archive_sett.contract_instances.flows"
		return

	if !contract_archive_api
		logger.error "缺少settings配置: records-qhd.to_archive_sett.contract_instances.contract_archive_api"
		return

	if !to_archive_api
		logger.error "缺少settings配置: records-qhd.to_archive_sett.non_contract_instances.to_archive_api"
		return

	instancesToArchive = new InstancesToArchive(spaces, archive_server, flows, ins_ids)

	instancesToArchive.sendContractInstances(contract_archive_api);

	instancesToArchive.sendNonContractInstances(to_archive_api)

RecordsQHD.startScheduleJob = (name, recurrenceRule, fun) ->

	if !recurrenceRule
		logger.error "Miss recurrenceRule"
		return
	if !_.isString(recurrenceRule)
		logger.error "RecurrenceRule is not String. https://github.com/node-schedule/node-schedule"
		return

	if !fun
		logger.error "Miss function"
	else if !_.isFunction(fun)
		logger.error "#{fun} is not function"
	else
		logger.info "Add scheduleJobMaps: #{name}"
		RecordsQHD.scheduleJobMaps[name] = schedule.scheduleJob recurrenceRule, fun

if RecordsQHD.settings_records_qhd?.recurrenceRule
	RecordsQHD.startScheduleJob "RecordsQHD.instanceToArchive", RecordsQHD.settings_records_qhd?.recurrenceRule, Meteor.bindEnvironment(RecordsQHD.run)