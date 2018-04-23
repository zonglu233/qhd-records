rem set DB_SERVER=192.168.0.21
rem set DB_SERVER=localhost
rem set MONGO_URL=mongodb://%DB_SERVER%/steedos

set DB_SERVER=192.168.0.23
set MONGO_URL=mongodb://%DB_SERVER%/qhd201711091030

set MONGO_OPLOG_URL=mongodb://%DB_SERVER%/local
set MULTIPLE_INSTANCES_COLLECTION_NAME=workflow_instances
set ROOT_URL=http://127.0.0.1:3006
meteor run --settings settings.json --port 3006