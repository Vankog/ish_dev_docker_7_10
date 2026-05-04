/*
 * 
 * Name			: update ICMDB after restore
 * Description	: After the ISH DB was restored, this script updates the necessary properties and users.
 *				Based on "createICMDB" script 
 *				from https://support.intershop.com/kb/index.php/Display/2863F2#GuideSetupMicrosoftSQLServerasIntershopDevelopmentDatabase-SQLScript 
 * Input		: DBName		- database name (required)
 *				PreviousUserID	- the old login name from the backup. Will be deleted. (required)
 *				UserID			- new login name. Replaces 'PreviousUserID' (required)
 *				Password		- password of login user (required)
 *				RecreateDB		- recreate database if exists (possible values: TRUE, FALSE), default: FALSE
 *				RecreateUser	- recreate user if exists (possible values: TRUE, FALSE), default: FALSE
 *				IsAzureDB		- is Azure Managed Instance  (possible values: TRUE, FALSE), default: FALSE
 *				Recovery		- Recovery model (possible values: FULL, SIMPLE, BULKLOGGED), default: FULL, only used if @IsAzureDB = 0
 * Version		: 1.0.0
 * Example		: DECLARE  @DBName SYSNAME = 'ish_icmpre_edit';
 *				  EXEC #updateCollation @DBName;
 *				  EXEC #updateIcmDB @DBName, 
 *						@PreviousUserID = 'ish_icmint_edit',
 *						@UserID = 'intershop', 
 *						@Password = '!InterShop00!', 
 *						@IsAzureDB = 'FALSE',
 *						@Recovery = 'SIMPLE';
*/

CREATE OR ALTER PROC #updateCollation
			 @DBName SYSNAME
AS
BEGIN
DECLARE  @Sql NVARCHAR(MAX)

IF (SELECT collation_name from sys.databases WHERE name = @DBname) = 'Latin1_General_100_CI_AS'
BEGIN
	PRINT 'Collation applied successful'
END
ELSE
BEGIN
	PRINT 'Collation setting not correct. Altering...'
	SET @Sql = 'ALTER DATABASE ' + QUOTENAME(@DBName) + ' COLLATE Latin1_General_100_CI_AS';
	print 'Executing SQL: ' + @Sql;
	EXECUTE sp_executesql @Sql;
END

END;
GO

CREATE OR ALTER PROC #updateIcmDB
			 @DBName SYSNAME,
			 @PreviousUserID SYSNAME,
			 @UserID SYSNAME,
			 @Password NVARCHAR(128),
			 @IsAzureDB BIT = 'FALSE',
			 @Recovery NVARCHAR(30) = 'FULL'
AS
BEGIN
DECLARE  @Sql NVARCHAR(MAX),
		 @SqlFiles NVARCHAR(MAX) = '',
		 @Looper int = 1,
		 @FileEnding NVARCHAR(10),
		 @tempDBName SYSNAME,
		 @CurrentDBUser SYSNAME;

/*-- Drop Old Login
IF EXISTS (SELECT 1 FROM [master].[sys].[server_principals] WHERE Name = @PreviousUserID)
BEGIN
	print 'Dropping existing user: ' + QUOTENAME(@PreviousUserID);
	SET @Sql = 'DROP LOGIN ' + QUOTENAME(@PreviousUserID)
	print 'Executing SQL: ' + @Sql;
	EXECUTE sp_executesql @Sql;
END;
*/

-- Create Login
IF NOT EXISTS (SELECT 1 FROM [master].[sys].[server_principals] WHERE Name = @UserID)
BEGIN
	print 'Creating user: ' + QUOTENAME(@UserID);
	SET @Sql = 'CREATE LOGIN
	' + QUOTENAME(@UserID) + '
	WITH
	PASSWORD = ''' + REPLICATE('*', LEN(@Password)) + '''
	, DEFAULT_DATABASE = [master]
	, DEFAULT_LANGUAGE = [us_english]
	, CHECK_EXPIRATION = OFF
	, CHECK_POLICY = OFF';
	print 'Executing SQL: ' + @Sql;
	SET @Sql = REPLACE(@sql, REPLICATE('*', LEN(@Password)), REPLACE(@Password, '''', ''''''))
	EXECUTE sp_executesql @Sql;
END;
ELSE 
BEGIN
	print 'set password for: ' + QUOTENAME(@UserID);
	SET @Sql = 'ALTER LOGIN
	' + QUOTENAME(@UserID) + '
	WITH
	PASSWORD = ''' + REPLICATE('*', LEN(@Password)) + ''';';
	print 'Executing SQL: ' + @Sql;
	SET @Sql = REPLACE(@sql, REPLICATE('*', LEN(@Password)), REPLACE(@Password, '''', ''''''))
	EXECUTE sp_executesql @Sql;
END;


IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
BEGIN
	print 'Enabling full-text search...';
	SET @Sql = QUOTENAME(@DBName) + '.[dbo].[sp_fulltext_database] @action = ''enable''';
	print 'Executing SQL: ' + @Sql;
	EXECUTE sp_executesql @Sql;
END;

print 'Setting default database ...';
SET @Sql = 'ALTER LOGIN ' + QUOTENAME(@UserID) + ' WITH DEFAULT_DATABASE = ' + QUOTENAME(@DBName);
print 'Executing SQL: ' + @Sql;
EXECUTE sp_executesql @Sql;

print 'Setting database owner ...'
SET @Sql = 'ALTER AUTHORIZATION ON DATABASE::' + QUOTENAME(@DBName) + ' TO ' +QUOTENAME(@UserID);
print 'Executing SQL: ' + @Sql;
EXECUTE sp_executesql @Sql;

print 'Setting Read Committed Snapshot ...';
SET @Sql = 'ALTER DATABASE ' + QUOTENAME(@DBName) + ' SET READ_COMMITTED_SNAPSHOT ON'
print 'Executing SQL: ' + @Sql;
EXECUTE sp_executesql @Sql;

IF @IsAzureDB = 0 AND LEN(@Recovery) > 0
BEGIN
	print 'Setting Recovery Model ...';
	SET @Sql = 'ALTER DATABASE ' + QUOTENAME(@DBName) + ' SET RECOVERY ' + @Recovery
	print 'Executing SQL: ' + @Sql;
	EXECUTE sp_executesql @Sql;
END

print 'Grant access to credentials'
SET @Sql = 'GRANT ALTER ANY CREDENTIAL TO ' + QUOTENAME(@UserID)
print 'Executing SQL: ' + @Sql;
EXECUTE sp_executesql @Sql;

IF (SELECT is_read_committed_snapshot_on from sys.databases WHERE name = @DBname) = 1
BEGIN
	PRINT 'Setting READ COMMITTED SNAPSHOT applied successful'
END
ELSE
BEGIN
	PRINT 'Value for ''READ COMMITTED SNAPSHOT'' not correct. Please check'
END

IF (SELECT is_fulltext_enabled from sys.databases WHERE name = @DBname) = 1
BEGIN
	PRINT 'Fulltext enabled successful'
END
ELSE
BEGIN
	PRINT 'Fulltext search not enabled. Please check'
END

END;
GO

USE [master]
DECLARE @DBName SYSNAME = 'ish_icmpre_edit';
EXEC #updateCollation @DBName;
EXEC #updateIcmDB	@DBName, 
					@PreviousUserID = 'dontdropme',
					@UserID = 'ish_icmpre_edit', 
					@Password = '!InterShop00!', 
					@IsAzureDB = 'FALSE',
					@Recovery = 'SIMPLE';
GO
