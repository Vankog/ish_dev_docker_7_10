/*
 * Check 
 * https://support.intershop.com/kb/index.php/Display/2863F2#GuideSetupMicrosoftSQLServerasIntershopDevelopmentDatabase-SQLScript 
 * for updates to this script!
 * 
 * Name			: createICMDB
 * Description	: created a database on a SQL Server instance with all required parameters
 * Input		: DBName          - database name (required)
 *				  UserID          - login name (required)
 *				  Password        - password of login user (required)
 *				  RecreateDB      - recreate database if exists (possible values: TRUE, FALSE), default: FALSE
 *				  RecreateUser    -	recreate user if exists (possible values: TRUE, FALSE), default: FALSE
 *				  IsAzureDB       - is Azure Managed Instance  (possible values: TRUE, FALSE), default: FALSE
 *				  DataPath        - data file(s) location (optional), only used if @IsAzureDB = 0
 *				  LogPath         - log file location (optional), only used if @IsAzureDB = 0
 *				  NumberDataFiles - number of used data files, default: 1, only used if @IsAzureDB = 0
 *				  Recovery        - Recovery model (possible values: FULL, SIMPLE, BULKLOGGED), default: FULL, only used if @IsAzureDB = 0
 * Version		: 1.0.0
 * Example		: EXEC #createIcmDB @DBName = 'icmdb', @UserID = 'intershop', @Password = 'intershop', @RecreateDB = 'TRUE', @RecreateUser = 'TRUE'
 *
*/

CREATE OR ALTER PROC #createIcmDB
			 @DBName SYSNAME,
			 @UserID SYSNAME,
			 @Password NVARCHAR(128),
			 @RecreateDB BIT = 'FALSE',
			 @RecreateUser BIT = 'FALSE', 
			 @IsAzureDB BIT = 'FALSE',
			 @DataPath NVARCHAR(MAX) = NULL,
			 @LogPath NVARCHAR(MAX) = NULL,
			 @NumberDataFiles INT = 1,
			 @Recovery NVARCHAR(30) = 'FULL'
AS
BEGIN
DECLARE  @Sql NVARCHAR(MAX),
		 @SqlFiles NVARCHAR(MAX) = '',
		 @Looper int = 1,
		 @FileEnding NVARCHAR(10),
		 @tempDBName SYSNAME,
		 @CurrentDBUser SYSNAME;
  
-- check owner of existing database
SELECT @CurrentDBUser = SUSER_SNAME(owner_sid) FROM sys.databases WHERE name = @DBName
IF db_id(@DBName) IS NOT NULL AND @CurrentDBUser != @UserID
BEGIN
	print 'Cannot delete database of foreign user. Database ''' + @DBName + ''' is owned by ' + QUOTENAME(@CurrentDBUser)
RETURN
END
  
IF @DataPath IS NULL
	SET @DataPath = CONVERT(NVARCHAR(MAX), SERVERPROPERTY('InstanceDefaultDataPath'));
IF @LogPath IS NULL
	SET @LogPath = CONVERT(NVARCHAR(MAX), SERVERPROPERTY('InstanceDefaultLogPath'));
  
-- Drop Database
IF db_id(@DBName) IS NOT NULL AND @RecreateDB = 1
BEGIN
	print 'Dropping existing database: ' + QUOTENAME(@DBName);
	SET @Sql = 'DROP DATABASE ' + QUOTENAME(@DBName);
	print 'Executing SQL: ' + @Sql;
	EXECUTE sp_executesql @Sql;
END;
  
-- Drop Login
IF EXISTS (SELECT 1 FROM [master].[sys].[server_principals] WHERE Name = @UserID) AND @RecreateUser = 1
BEGIN
	print 'Dropping existing user: ' + QUOTENAME(@UserID);
	SET @Sql = 'DROP LOGIN ' + QUOTENAME(@UserID)
	print 'Executing SQL: ' + @Sql;
	EXECUTE sp_executesql @Sql;
END;
  
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
  
IF db_id(@DBName) IS NULL
BEGIN
	print 'Creating database: ' + QUOTENAME(@DBName);
	SET @Sql = 'CREATE DATABASE
	' + QUOTENAME(@DBName) + '
	CONTAINMENT = NONE'
	
	IF @IsAzureDB = 0
	BEGIN
		SET @Sql = @Sql + ' ON PRIMARY '
	END
 
	IF @IsAzureDB = 0
	BEGIN
		WHILE (@Looper <= @NumberDataFiles)
		BEGIN
			IF @Looper = 1
				SET @FileEnding = N'.mdf'
			ELSE
			SET @FileEnding = N'.ndf'

			IF @NumberDataFiles > 1
				SET @tempDBName = @DBName + CONVERT(varchar(10), @Looper)
			ELSE
				SET @tempDBName = @DBName

			SET @SqlFiles = @SqlFiles + '
				(NAME = ''' + @tempDBName + '''
				, FILENAME = ''' + CONCAT(@DataPath, N'\', @tempDBName, @FileEnding) + '''
				, SIZE = 8MB
				, MAXSIZE = UNLIMITED
				, FILEGROWTH = 64MB)'

			IF @Looper < @NumberDataFiles
				SET @SqlFiles = @SqlFiles + ', '

			SET @Looper = @Looper + 1
		END

		SET @Sql = @Sql + @SqlFiles
	END
	
	IF @IsAzureDB = 0
	BEGIN
		SET @Sql = @Sql + '
			LOG ON (
			NAME = ''' + CONCAT(@DBName, N'_log') + '''
			, FILENAME = ''' + CONCAT(@LogPath, N'\', @DBName, N'_log.ldf') + '''
			, SIZE = 8MB
			, MAXSIZE = UNLIMITED
			, FILEGROWTH = 64MB )'
	END
	
	SET @Sql = @Sql + ' COLLATE Latin1_General_100_CI_AS';
	print 'Executing SQL: ' + @Sql;
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

IF (SELECT collation_name from sys.databases WHERE name = @DBname) = 'Latin1_General_100_CI_AS'
BEGIN
	PRINT 'Collation applied successful'
END
ELSE
BEGIN
    PRINT 'Collation setting not correct. Please check'
END

END;
GO
  
USE [master];
EXEC #createIcmDB @DBName = '$(DB_NAME)', 
                  @UserID = '$(DB_USER)', 
                  @Password = '$(DB_PASSWORD)', 
                  @RecreateDB = 'FALSE', 
                  @RecreateUser = 'FALSE', 
                  @IsAzureDB = 'FALSE',
			      @DataPath = NULL,
			      @LogPath = NULL,
			      @NumberDataFiles = 1, 
                  @Recovery = 'SIMPLE'
GO
