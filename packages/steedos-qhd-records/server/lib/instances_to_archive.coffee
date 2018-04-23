request = Npm.require('request')
path = Npm.require('path')
fs = Npm.require('fs')

logger = new Logger 'Records_QHD -> InstancesToArchive'

# spaces: Array 工作区ID
# contract_flows： Array 合同类流程
InstancesToArchive = (spaces, contract_flows, ins_ids) ->
	@spaces = spaces
	@contract_flows = contract_flows
	@ins_ids = ins_ids
	return

InstancesToArchive.success = (instance)->
	console.log("success, name is #{instance.name}, id is #{instance._id}")
	db.instances.direct.update({_id: instance._id}, {$set: {is_recorded: true}})

InstancesToArchive.failed = (instance, error)->
	console.log("failed, name is #{instance.name}, id is #{instance._id}. error: ")
	console.log error

#	获取非合同类的申请单：正常结束的(不包括取消申请、被驳回的申请单)
InstancesToArchive::getNonContractInstances = ()->
	query = {
		space: {$in: @spaces},
		flow: {$nin: @contract_flows},
		# is_archived字段被老归档接口占用，所以使用 is_recorded 字段判断是否归档
		$or: [
			{is_recorded: false},
			{is_recorded: {$exists: false}}
		],
		is_deleted: false,
		state: "completed",
		"values.record_need": "true",
		$or: [
			{final_decision: "approved"},
			{final_decision: {$exists: false}},
			{final_decision: ""}
		]
	}
	if @ins_ids
		query._id = {$in: @ins_ids}
	return db.instances.find(query, {fields: {_id: 1}}).fetch()



# 按年度计算件数,生成电子文件号的最后组成
buildElectronicRecordCode = (formData) ->
	num = db.archive_wenshu.find({'year':formData?.year}).count() + 1
	strCount = (Array(6).join('0') + num).slice(-6)
	strElectronicRecordCode = formData?.fonds_identifier +
								formData?.archival_category_code +
								formData?.year + strCount
	return strElectronicRecordCode


# 整理档案表数据
_minxiInstanceData = (formData, instance) ->
	if !instance
		return
	dateFormat = "YYYY-MM-DD HH:mm:ss"

	formData.space = instance.space

	# 字段映射
	field_values = InstanceManager.handlerInstanceByFieldMap(instance)
	formData = _.extend formData, field_values

	# 根据FONDSID查找全宗号
	fond = db.archive_fonds.findOne({'name':formData?.fonds_name})
	formData.fonds_identifier = fond?._id
	# 根据机构查找对应的类别号
	classification = db.archive_classification.findOne({'dept':/{formData?.organizational_structure}/})
	formData.category_code = classification?._id
	# 保管期限代码查找
	retention = db.archive_retention.findOne({'code':formData?.archive_retention_code})
	formData.retention_peroid = retention?._id
	# 根据保管期限,处理标志
	if retention?.years >= 10
		formData.produce_flag = "在档"
	else
		formData.produce_flag = "暂存"

	# 电子文件号，不生成，点击接收的时候才生成
	# formData.electronic_record_code = buildElectronicRecordCode formData
	# 归档日期
	formData.archive_date = moment(new Date()).format(dateFormat)

	# OA表单的ID，作为判断OA归档的标志
	formData.external_id = instance._id

	formData.is_receive = false

	fieldNames = _.keys(formData)

	fieldNames.forEach (key)->
		fieldValue = formData[key]
		if _.isDate(fieldValue)
			fieldValue = moment(fieldValue).format(dateFormat)

		if _.isObject(fieldValue)
			fieldValue = fieldValue?.name

		if _.isArray(fieldValue) && fieldValue.length > 0 && _.isObject(fieldValue)
			fieldValue = fieldValue?.getProperty("name")?.join(",")

		if _.isArray(fieldValue)
			fieldValue = fieldValue?.join(",")

		if !fieldValue
			fieldValue = ''



	# ===============正文附件=======================
	formData.attach = new Array()
	formData.attachInfo = new Array()


	# 整理附件数据
	# _minxiAttachmentInfo = (formData, instance, attach) ->
	# 	user = db.users.findOne({_id: attach.metadata.owner})
	# 	formData.attachInfo.push {
	# 		instance: instance._id,
	# 		attach_name: encodeURI(attach.name()),
	# 		owner: attach.metadata.owner,
	# 		owner_username: encodeURI(user.username || user.steedos_id),
	# 		is_private: attach.metadata.is_private || false
	# 	}

	mainFilesHandle = (f)->
		console.log "============正文附件流=============="
		console.log f.createReadStream('instances')
		try
			fileStream = f.createReadStream('instances')
			if fileStream
				formData.attach.push {
					value: fileStream
				}
				# _minxiAttachmentInfo formData, instance, f
			else
				logger.error "附件不存在：#{f._id}"
		catch e
			logger.error "正文附件下载失败：#{f._id}. error: " + e

	mainFile = cfs.instances.find({
		'metadata.instance': instance._id,
		'metadata.current': true,
		"metadata.main": true
	}).fetch()

	# mainFile.forEach mainFilesHandle

	console.log("_minxiInstanceData end", instance._id)

	return formData

InstancesToArchive.syncNonContractInstance = (instance, callback) ->
	#	表单数据
	formData = {}

	_minxiInstanceData(formData, instance)

	#	校验必填
	_checkParameter = (formData) ->
		if !formData.fonds_name
			return false
		return true

	if _checkParameter(formData)
		logger.debug("_sendContractInstance: #{instance._id}")
		# 添加到相应的档案表
		db.archive_wenshu.direct.insert(formData)
		# InstancesToArchive.success instance
	else
		InstancesToArchive.failed instance, "立档单位 不能为空"

InstancesToArchive::syncNonContractInstances = () ->
	# instance = db.instances.findOne({_id: 'hEKkSrLCoQ4Q2Y5z4'})
	# if instance
	# 	InstancesToArchive.syncNonContractInstance instance

	console.time("syncNonContractInstances")
	instances = @getNonContractInstances()
	that = @
	console.log "instances.length is #{instances.length}"
	instances.forEach (mini_ins)->
		instance = db.instances.findOne({_id: mini_ins._id})
		if instance
			console.log instance.name
			InstancesToArchive.syncNonContractInstance instance
	console.timeEnd("syncNonContractInstances")