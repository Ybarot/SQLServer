use master
IF OBJECT_ID('tempdb.dbo.#onlineIndex_table') IS NOT NULL
DROP TABLE #onlineIndex_table
create table #onlineIndex_table
(
DBName sysname NOT NULL ,
Enabled char(2) NOT NULL,
Status varchar(50) NOT NULL
)

Insert #onlineIndex_table
EXEC sp_msforeachdb
N' USE [?] SELECT ''?'' as DBName , IIF(count(1)>0,1,0) as Enabled, ''You are using ONLINE INDEX feature'' as Status
FROM FN_DBLOG(NULL,NULL)
WHERE [Transaction Name] =''ONLINE_INDEX_DDL''
'


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
select DBName, Enabled, Status from #onlineIndex_table where Enabled=1
order by enabled desc
DROP TABLE #onlineIndex_table

