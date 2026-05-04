/*
 * Creates the application SQL login if it does not already exist.
 *
 * The database itself is NOT created here.
 * Workflow:
 *   1. Build & start the container  →  this script runs once at image-build time.
 *   2. Import a .bacpac file via SSMS.
 *   3. Run 'update restored DB.sql' manually to re-map ownership and settings.
 */

USE [master];
GO

IF NOT EXISTS (SELECT 1 FROM [master].[sys].[server_principals] WHERE [name] = N'$(DB_USER)')
BEGIN
    PRINT 'Creating login: [$(DB_USER)]';
    DECLARE @sql NVARCHAR(MAX) =
        N'CREATE LOGIN ' + QUOTENAME(N'$(DB_USER)') +
        N' WITH PASSWORD     = ''' + REPLACE(N'$(DB_PASSWORD)', N'''', N'''''') + N'''
             , DEFAULT_DATABASE = [master]
             , DEFAULT_LANGUAGE = [us_english]
             , CHECK_EXPIRATION = OFF
             , CHECK_POLICY     = OFF';
    EXECUTE sp_executesql @sql;
    PRINT 'Login created.';
END
ELSE
BEGIN
    PRINT 'Login [$(DB_USER)] already exists – skipping.';
END
GO
