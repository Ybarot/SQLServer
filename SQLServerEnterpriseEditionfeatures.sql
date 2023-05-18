DECLARE @Status bit;
use master
IF NOT EXISTS (SELECT name FROM sys.dm_xe_sessions  WHERE name = 'online_rebuild')
Begin
CREATE EVENT SESSION [online_rebuild] ON SERVER 
ADD EVENT sqlserver.progress_report_online_index_operation(SET collect_database_name=(0))
ADD TARGET package0.event_counter
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
End

SELECT @Status = iif(RS.name IS NULL, 0, 1)
FROM sys.dm_xe_sessions RS
RIGHT JOIN sys.server_event_sessions ES ON RS.name = ES.name
WHERE es.name = 'online_rebuild'

if @Status = 0
Begin
ALTER EVENT SESSION [online_rebuild] ON SERVER STATE =  START ;
End

IF OBJECT_ID('tempdb.dbo.#EnterpriseFeaturesDB') IS NOT NULL
DROP TABLE #EnterpriseFeaturesDB
CREATE TABLE #EnterpriseFeaturesDB
(
DatabaseName Varchar(100),
Feature_Name Varchar(100)
)
EXEC sp_msforeachdb
N' USE [?]
IF (SELECT COUNT(*) FROM sys.dm_db_persisted_sku_features) >0
BEGIN
INSERT INTO #EnterpriseFeaturesDB
SELECT DatabaseName=DB_NAME(),Feature_Name
FROM sys.dm_db_persisted_sku_features
END '
SELECT DatabaseName as DBName,IIF(count(1)>0,1,0) as Enabled, Concat(Feature_name,' - User Databases are using Enterprise Level Features') AS Enterprise_Feature
FROM #EnterpriseFeaturesDB Group by [DatabaseName],Feature_Name
Union
SELECT DB_Name() as DBName,IIF(count(1)>0,1,0) as Enabled , 'You have Availability Groups with > 1 database' AS Enterprise_Feature
FROM sys.availability_databases_cluster Databaselist
INNER JOIN sys.availability_groups_cluster Groups ON Databaselist.group_id = Groups.group_id
GROUP BY [name] HAVING COUNT([database_name]) >1
UNION
SELECT DB_Name() as DBName,IIF(count(1)>0,1,0) as Enabled, 'You have read-only Replicas' AS Enterprise_Feature
from sys.availability_replicas
WHERE secondary_role_allow_connections <> 0
UNION
SELECT DB_Name() as DBName,IIF(count(1)>0,1,0) as Enabled, 'You have Asynchronous commit Replicas' AS Enterprise_Feature
FROM sys.availability_replicas
WHERE availability_mode=0
UNION
SELECT DB_Name() as DBName,IIF(count(1)>0,1,0) as Enabled, 'You are using Resource Governor' AS Enterprise_Feature
FROM sys.dm_resource_governor_resource_pools
WHERE name NOT IN ('internal','default')
UNION
SELECT DB_Name() as DBName,IIF(count(1)>0,1,0) as Enabled, 'You are using peer-to-peer replication' AS Enterprise_Feature
FROM sys.dm_repl_articles
WHERE intPublicationOptions = 0x1
UNION
SELECT DB_Name() as DBName,IIF(count(1)>0,1,0) as Enabled, 'You are using R or Python extensions' AS Enterprise_Feature
FROM sys.dm_external_script_requests
WHERE language IN ('R','Python')
UNION
SELECT DB_Name() as DBName,IIF(count(1)>0,1,0) as Enabled, 'Tempdb metadata memory-optimized is enabled' AS Enterprise_Feature
FROM sys.configurations
WHERE name = N'tempdb metadata memory-optimized'
AND value_in_use = 1
UNION
SELECT DB_Name() as DBName,IIF(count(1)>48,1,0) as Enabled,'SQL Server has > 48 vCPU' AS Enterprise_Feature
FROM sys.dm_os_schedulers WITH (NOLOCK)
WHERE scheduler_id < 255 and [status] = 'VISIBLE ONLINE'
UNION
SELECT DB_Name() as DBName,IIF(count(1)>0,1,0) as Enabled, 'SQL Server has > 128 GB Memory' AS Enterprise_Feature
FROM sys.dm_os_sys_memory
WHERE total_physical_memory_kb/1024/1024 > 128
UNION
SELECT DB_Name() as DBName,IIF(count(1)>0,1,0) as Enabled, 'You are using asynchronous mirroring' AS Enterprise_Feature
from sys.database_mirroring
WHERE mirroring_safety_level = 1
union
SELECT DB_Name() as DBName,IIF(count(1)>0,1,0) as Enabled, 
Case
 WHEN IIF(count(1)>0,1,0) > 0 then 'You are using Online Indexing Enterprise Feature' 
 ELSE 'You are not using Online Index features or Online Indexing not done after enabling Event Sessions'
 END AS Enterprise_Feature
FROM (
SELECT 
        CAST(xet.target_data AS xml)  as target_data
    FROM sys.dm_xe_session_targets AS xet  
    JOIN sys.dm_xe_sessions AS xe  
       ON (xe.address = xet.event_session_address)  
    WHERE xe.name = 'online_rebuild' 
        and target_name='event_counter'

    ) as t
CROSS APPLY t.target_data.nodes('//CounterTarget/Packages/Package/Event') AS xed (slot_data)
where xed.slot_data.value('(@count)[1]', 'varchar(256)') >0


