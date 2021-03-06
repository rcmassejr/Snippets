-----------------------------------
--********************************
--Mark users to be deleted
--********************************
-----------------------------------
ALTER TABLE name disable trigger all
UPDATE N SET n.STATUS = 'D' FROM Name as n 
WHERE N.MEMBER_TYPE <> 'STAFF' AND ID > 5
-----------------------------------
--********************************
--RESET FINANCIAL DATA
--********************************
-----------------------------------
delete from order_badge
delete from order_lines
delete from order_meet
delete from order_payments
delete from orders
delete from trans
delete from invoice
delete from invoice_lines
delete from Batch
delete from Subscriptions
delete from Activity
delete from Activity_Attach
DELETE FROM RELATIONSHIP
UPDATE [dbo].[Meet_Master]
SET [TOTAL_REGISTRANTS] = 0
,[TOTAL_CANCELATIONS] = 0
,[TOTAL_REVENUE] = 0
,[HEAD_COUNT] = 0

UPDATE COUNTER SET LAST_VALUE = 1 WHERE COUNTER_NAME = 'Invoice'
UPDATE COUNTER SET LAST_VALUE = 1 WHERE COUNTER_NAME = 'Invoice_Ref'
UPDATE COUNTER SET LAST_VALUE = 1 WHERE COUNTER_NAME = 'Orders'
UPDATE COUNTER SET LAST_VALUE = 1 WHERE COUNTER_NAME = 'Receipt'
UPDATE COUNTER SET LAST_VALUE = 1 WHERE COUNTER_NAME = 'Trans'
UPDATE COUNTER SET LAST_VALUE = 1 WHERE COUNTER_NAME = 'ACTIVITY'
UPDATE COUNTER SET LAST_VALUE = 1 WHERE COUNTER_NAME = 'ACTIVITY_ATTACH'
UPDATE COUNTER SET LAST_VALUE = 1 WHERE COUNTER_NAME = 'RELATIONSHIP'
UPDATE COUNTER SET LAST_VALUE = 1 WHERE COUNTER_NAME = 'NAME_PICTURE'

--------------------------------------------
--******************************************
--Additional clean up traced from profiler
--******************************************
--------------------------------------------
SET ANSI_DEFAULTS ON;
SET IMPLICIT_TRANSACTIONS OFF;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Purge_Ctrl_ie') AND type IN (N'U'))
 BEGIN
     DROP TABLE dbo.Purge_Ctrl_ie;
 END

CREATE TABLE dbo.Purge_Ctrl_ie(ID         varchar(10) CONSTRAINT DF_Purge_Ctrl_ie_ID                 DEFAULT ('') NOT NULL,
                                STATUS      varchar(5) CONSTRAINT DF_Purge_Ctrl_ie_STATUS             DEFAULT ('') NOT NULL,
                                CERT_REGISTER_BTID bit CONSTRAINT DF_Purge_Ctrl_ie_CERT_REGISTER_BTID DEFAULT (0)  NOT NULL,
                                INVOICE_BALANCE    bit CONSTRAINT DF_Purge_Ctrl_ie_INVOICE_BALANCE    DEFAULT (0)  NOT NULL,
                                NAME_BT_COID       bit CONSTRAINT DF_Purge_Ctrl_ie_NAME_BT_COID       DEFAULT (0)  NOT NULL,
                                NAME_FIN_BTID      bit CONSTRAINT DF_Purge_Ctrl_ie_NAME_FIN_BTID      DEFAULT (0)  NOT NULL,
                                OPEN_ORDERS        bit CONSTRAINT DF_Purge_Ctrl_ie_OPEN_ORDERS        DEFAULT (0)  NOT NULL,
                                REFERRAL_ORPHAN    bit CONSTRAINT DF_Purge_Ctrl_ie_REFERRAL_ORPHAN    DEFAULT (0)  NOT NULL,
                                SUBSCRIPTION       bit CONSTRAINT DF_Purge_Ctrl_ie_SUBSCRIPTION       DEFAULT (0)  NOT NULL,
                                OPP_PROSPECT       bit CONSTRAINT DF_Purge_Ctrl_ie_OPP_PROSPECT       DEFAULT (0)  NOT NULL);

GRANT ALL ON Purge_Ctrl_ie TO IMIS;

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Affect_Cert_Register_ie') AND type IN (N'U'))
 BEGIN
     DROP TABLE dbo.Affect_Cert_Register_ie;
 END;

CREATE TABLE dbo.Affect_Cert_Register_ie(SEQN           integer CONSTRAINT DF_Affect_Cert_Register_ie_SEQN       DEFAULT (0)  NOT NULL,
                                              STUDENT_ID varchar(10) CONSTRAINT DF_Affect_Cert_Register_ie_STUDENT_ID DEFAULT ('') NOT NULL,
                                              BT_ID      varchar(10) CONSTRAINT DF_Affect_Cert_Register_ie_BT_ID      DEFAULT ('') NOT NULL);

GRANT ALL ON dbo.Affect_Cert_Register_ie TO IMIS;

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Affect_Name_Fin_ie') AND type IN (N'U'))
 BEGIN
     DROP TABLE dbo.Affect_Name_Fin_ie;
 END;

CREATE TABLE dbo.Affect_Name_Fin_ie(ID    varchar(10) CONSTRAINT DF_Affect_Name_Fin_ie_ID    DEFAULT ('') NOT NULL,
                                         BT_ID varchar(10) CONSTRAINT DF_Affect_Name_Fin_ie_BT_ID DEFAULT ('') NOT NULL);

GRANT ALL ON dbo.Affect_Name_Fin_ie TO IMIS;

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Affect_Name_ie') AND type IN (N'U'))
 BEGIN
     DROP TABLE dbo.Affect_Name_ie;
 END;

CREATE TABLE dbo.Affect_Name_ie(ID    varchar(10) CONSTRAINT DF_Affect_Name_ie_ID    DEFAULT ('') NOT NULL,
                                     CO_ID varchar(10) CONSTRAINT DF_Affect_Name_ie_CO_ID DEFAULT ('') NOT NULL,
                                     BT_ID varchar(10) CONSTRAINT DF_Affect_Name_ie_BT_ID DEFAULT ('') NOT NULL);

GRANT ALL ON dbo.Affect_Name_ie TO IMIS;

INSERT INTO Purge_Ctrl_ie (ID)
     SELECT ID
       FROM Name
      WHERE STATUS LIKE 'D%' AND LAST_FIRST NOT IN ('GUEST', 'MANAGER', 'ADMINISTRATOR', 'IMISLOG', 'SYSTEM');

INSERT INTO Affect_Cert_Register_ie (SEQN, STUDENT_ID, BT_ID)
     SELECT SEQN, STUDENT_ID, BT_ID
       FROM Cert_Register AS c
      WHERE NOT EXISTS(SELECT ID
                         FROM Purge_Ctrl_ie
                        WHERE ID = c.STUDENT_ID) AND EXISTS(SELECT ID
                                                              FROM Purge_Ctrl_ie
                                                             WHERE ID = c.BT_ID);

INSERT INTO Affect_Name_Fin_ie (ID,
                                 BT_ID)
     SELECT ID, BT_ID
       FROM Name_Fin AS n
      WHERE NOT EXISTS(SELECT ID
                         FROM Purge_Ctrl_ie
                        WHERE ID = n.ID) AND EXISTS(SELECT ID
                                                      FROM Purge_Ctrl_ie
                                                     WHERE ID = n.BT_ID);

INSERT INTO Affect_Name_ie (ID,
                             CO_ID,
                             BT_ID)
     SELECT ID, CO_ID, BT_ID
       FROM Name AS n
      WHERE NOT EXISTS(SELECT ID
                         FROM Purge_Ctrl_ie
                        WHERE ID = n.ID) AND (EXISTS(SELECT ID
                                                       FROM Purge_Ctrl_ie
                                                      WHERE ID = n.CO_ID) OR EXISTS(SELECT ID
                                                                                      FROM Purge_Ctrl_ie
                                                                                     WHERE ID = n.BT_ID));

UPDATE p
    SET p.CERT_REGISTER_BTID = 1
   FROM Purge_Ctrl_ie p, Affect_Cert_Register_ie c
  WHERE p.ID = c.BT_ID;

UPDATE p
    SET p.NAME_FIN_BTID = 1
   FROM Purge_Ctrl_ie p, Affect_Name_Fin_ie n
  WHERE p.ID = n.BT_ID;

UPDATE p
    SET p.NAME_BT_COID = 1
   FROM Purge_Ctrl_ie p, Affect_Name_ie n
  WHERE p.ID = n.CO_ID OR p.ID = n.BT_ID;

UPDATE p
    SET p.REFERRAL_ORPHAN = 1
   FROM Purge_Ctrl_ie p, Referral r
  WHERE p.ID = r.PROVIDER_ID AND r.REFERRAL_FEE > 0 AND r.READY_TO_INVOICE = 1 AND r.ORDER_NUMBER = 0;

UPDATE p
    SET p.INVOICE_BALANCE = 1
   FROM Purge_Ctrl_ie p, Invoice i
  WHERE p.ID = i.BT_ID AND i.BALANCE <> 0;

UPDATE p
    SET p.OPEN_ORDERS = 1
   FROM Purge_Ctrl_ie p, Orders o
  WHERE p.ID = o.BT_ID AND o.STAGE NOT IN ('CLOSED', 'CANCELED', 'COMPLETED');


UPDATE p
    SET p.SUBSCRIPTION = 1
   FROM Purge_Ctrl_ie p, Subscriptions s
  WHERE p.ID = s.BT_ID AND s.STATUS LIKE 'A%';

UPDATE p
    SET p.OPP_PROSPECT = 1
   FROM Purge_Ctrl_ie p, OpportunityMain o, ContactMain c
  WHERE p.ID = c.SyncContactID AND c.ContactKey = o.ProspectKey;

UPDATE Purge_Ctrl_ie
    SET STATUS = 'D'
  WHERE CERT_REGISTER_BTID = 0 AND INVOICE_BALANCE = 0 AND NAME_BT_COID = 0 AND NAME_FIN_BTID = 0 AND OPEN_ORDERS = 0 AND REFERRAL_ORPHAN = 0 AND SUBSCRIPTION = 0 AND OPP_PROSPECT = 0;


DECLARE @stmt varchar(1000);
 DECLARE @tname varchar(30);
 DECLARE tnames_cursor CURSOR FAST_FORWARD
     FOR SELECT TABLE_NAME
           FROM UD_Table;
 OPEN tnames_cursor;
 FETCH NEXT FROM tnames_cursor INTO @tname;
 WHILE (@@fetch_status <> -1)
     BEGIN
         SELECT @stmt = 'DELETE n FROM dbo.Purge_Ctrl_ie p INNER JOIN ' + @tname + ' n ON p.ID = n.ID ' + 'WHERE p.STATUS = ''D''  ';
         EXEC (@stmt);
         FETCH NEXT FROM tnames_cursor INTO @tname;
     END;
 DEALLOCATE tnames_cursor;
 INSERT INTO Name_Log(DATE_TIME,
                      LOG_TYPE,
                      SUB_TYPE,
                      USER_ID,
                      ID,
                      LOG_TEXT)
     SELECT GETDATE(),
            'CHANGE',
            'DELETE',
            'GUEST',
            n.ID,
            n.LAST_FIRST + ',' + n.COMPANY
       FROM Name AS n, Purge_Ctrl_ie AS p
      WHERE p.STATUS = 'D' AND p.ID = n.ID;


DELETE Name
   FROM Purge_Ctrl_ie p, Name n
  WHERE p.STATUS = 'D' AND p.ID = n.ID;

DELETE Name_Address
   FROM Purge_Ctrl_ie p, Name_Address n
  WHERE p.STATUS = 'D' AND p.ID = n.ID;


DELETE Name_Fin
   FROM Purge_Ctrl_ie p, Name_Fin n
  WHERE p.STATUS = 'D' AND p.ID = n.ID;

DELETE Name_Security
   FROM Purge_Ctrl_ie p, Name_Security n
  WHERE p.STATUS = 'D' AND p.ID = n.ID;


DELETE Name_Security_Groups
   FROM Purge_Ctrl_ie p, Name_Security_Groups n
  WHERE p.STATUS = 'D' AND p.ID = n.ID;


DELETE Name_Note
   FROM Purge_Ctrl_ie p, Name_Note n
  WHERE p.STATUS = 'D' AND p.ID = n.ID;

DELETE Name_Picture
   FROM Purge_Ctrl_ie p, Name_Picture n
  WHERE p.STATUS = 'D' AND p.ID = n.ID;

DELETE Name_Indexes
   FROM Purge_Ctrl_ie p, Name_Indexes n
  WHERE p.STATUS = 'D' AND p.ID = n.ID;

DELETE Subscriptions
   FROM Purge_Ctrl_ie p, Subscriptions s
  WHERE p.STATUS = 'D' AND p.ID = s.ID;

UPDATE a SET a.ID = ''
   FROM Activity a, Purge_Ctrl_ie p
  WHERE p.STATUS = 'D' AND p.ID = a.ID;

DELETE Prospect
   FROM Purge_Ctrl_ie p, Prospect pr
  WHERE p.STATUS = 'D' AND p.ID = pr.ImisID;


-----------------------------------
--********************************
--ASI Purge Script 
--********************************
-----------------------------------
-- Purging begins here. The entire script below must be run as a single unit
SET NOCOUNT ON
BEGIN TRANSACTION

-- Null out all UserMain records that are not in use (have no associated Name Records)
UPDATE u
SET u.[IsDisabled] = 1,
u.[ContactMaster] = '',
u.[UserId] = ''
FROM [dbo].[UserMain] u
LEFT OUTER JOIN [dbo].[Name] n ON u.[ContactMaster] = n.[ID]
WHERE n.[ID] IS NULL 
AND u.[UserId] NOT IN ('MANAGER', 'SYSTEM', 'ADMINISTRATOR', 'GUEST', 'DEMOSETUP', 'NUNIT1', 'IMISLOG')

-- Clean out ASPNET tables of any IDs for Users that are now nulled out
IF OBJECT_ID('tempdb..#providerKeys') IS NOT NULL DROP TABLE #providerKeys;
CREATE TABLE #providerKeys ([ProviderKey] uniqueidentifier PRIMARY KEY);
INSERT INTO #providerKeys ([ProviderKey])
SELECT [ProviderKey]
FROM [dbo].[UserMain]
WHERE [ContactMaster] = '' AND [UserId] = '' AND [IsDisabled] = 1 AND [ProviderKey] IS NOT NULL AND [ProviderKey] <> ''

DECLARE @applicationKey uniqueidentifier;
SELECT @applicationKey = [ApplicationId] FROM [aspnet_Applications] WHERE [LoweredApplicationName] = 'imis';

DELETE a 
FROM aspnet_Profile a 
INNER JOIN #providerKeys b ON a.[UserId] = b.[ProviderKey]
DELETE a 
FROM aspnet_Membership a 
INNER JOIN #providerKeys b ON a.[UserId] = b.[ProviderKey]
WHERE a.[ApplicationId] = @applicationKey
DELETE a 
FROM aspnet_Users a 
INNER JOIN #providerKeys b ON a.[UserId] = b.[ProviderKey]
WHERE a.[ApplicationId] = @applicationKey

-- Null out the ProviderKey for all UserMain records that have been cleared out
UPDATE [dbo].[UserMain] 
SET [ProviderKey] = NULL
WHERE [ContactMaster] = '' AND [UserId] = '' AND [IsDisabled] = 1 AND [ProviderKey] IS NOT NULL

-- Collect the UserKeys for all nulled-out User records
IF OBJECT_ID('tempdb..#userKeys') IS NOT NULL DROP TABLE #userKeys;
CREATE TABLE #userKeys (UserKey uniqueidentifier PRIMARY KEY);
INSERT INTO #userKeys ([UserKey])
SELECT [UserKey]
FROM [dbo].[UserMain]
WHERE [ContactMaster] = '' AND [UserId] = '' AND [IsDisabled] = 1 AND [ProviderKey] IS NULL

-- Get List of all UserKeys currently 'in use'
DECLARE @allUserKeysSql nvarchar(MAX);
DECLARE @cr nchar(2);
DECLARE @first bit;
SET @first = 0;
SET @allUserKeysSql = N'';
SET @cr = NCHAR(10) + NCHAR(13);
SELECT @allUserKeysSql = @allUserKeysSql + CASE WHEN @first=0 THEN N' ' ELSE @CR + N'UNION' + @CR END + 
N'SELECT DISTINCT([' + cu.COLUMN_NAME + N']), ''' + 
cu.TABLE_NAME + N''', ''' + cu.COLUMN_NAME + N''' FROM [' + 
cu.TABLE_SCHEMA + N'].[' + cu.TABLE_NAME + N'] WHERE [' + cu.COLUMN_NAME + N'] IS NOT NULL', @first = 1
FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS fk
INNER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE cu ON fk.CONSTRAINT_NAME = cu.CONSTRAINT_NAME
WHERE fk.CONSTRAINT_SCHEMA = N'dbo' AND fk.UNIQUE_CONSTRAINT_NAME = N'PK_UserMain'
AND cu.TABLE_NAME NOT IN (N'UserMain', N'UserRole', 'UserToken')

IF OBJECT_ID('tempdb..#allUserKeysInUse') IS NOT NULL DROP TABLE #allUserKeysInUse;
CREATE TABLE #allUserKeysInUse (UserKey uniqueidentifier, TableName sysname COLLATE DATABASE_DEFAULT, ColumnName sysname COLLATE DATABASE_DEFAULT);
INSERT INTO #allUserKeysInUse
EXEC (@allUserKeysSql);

-- Index the UserKeysInUse
CREATE NONCLUSTERED INDEX IX_allUserKeysInUse_UserKey ON #allUserKeysInUse (UserKey ASC);

-- Get a new list of all the UserKeys we're now going to delete
IF OBJECT_ID('tempdb..#usersToDelete') IS NOT NULL DROP TABLE #usersToDelete;
CREATE TABLE #usersToDelete ([UserKey] uniqueidentifier PRIMARY KEY);
INSERT INTO #usersToDelete ([UserKey])
SELECT DISTINCT a.[UserKey] 
FROM #userKeys a
WHERE a.[UserKey] NOT IN (SELECT [UserKey] FROM #allUserKeysInUse);

-- Purge from UserRole and UserToken
DELETE b
FROM #usersToDelete a INNER JOIN [dbo].[UserRole] b ON a.[UserKey] = b.[UserKey]
DELETE b
FROM #usersToDelete a INNER JOIN [dbo].[UserToken] b ON a.[UserKey] = b.[UserKey]

-- Display information about the purge
DECLARE @total int
DECLARE @purging int
DECLARE @ineligible int
SELECT @total = COUNT([UserKey]) FROM #userKeys
SELECT @purging = COUNT([UserKey]) FROM #usersToDelete 
SELECT @ineligible = COUNT(a.[UserKey]) FROM #userKeys a WHERE a.[UserKey] IN (SELECT [UserKey] FROM #allUserKeysInUse);
PRINT N'Total Users flagged as disabled: ' + CAST(@total as nvarchar)
PRINT N'Disabled Users still in use (referenced by other data): ' + CAST(@ineligible as nvarchar(10))
PRINT N'Purging ' + CAST(@purging as nvarchar(10)) + N' total Users from UserMain'

DECLARE @listOfIds varchar(MAX);
SET @listOfIds = '';
SELECT @listOfIds = u.[UserId] + ' (' + CAST(utd.UserKey AS varchar(40)) + ')' + @cr
FROM #usersToDelete utd
INNER JOIN [dbo].[UserMain] u ON utd.UserKey = u.UserKey
PRINT @listOfIds

-- Purge the unreferenced Users from UserMain
DELETE b
FROM #usersToDelete a INNER JOIN [dbo].[UserMain] b ON a.[UserKey] = b.[UserKey]

-- Clean out all Users rows without associated UserMain rows
DELETE a
FROM [dbo].[Users] a LEFT OUTER JOIN [dbo].[UserMain] b ON a.[UserId] = b.[UserId]
WHERE b.[UserId] IS NULL

-- Clean up temp tables
IF OBJECT_ID('tempdb..#providerKeys') IS NOT NULL DROP TABLE #providerKeys;
IF OBJECT_ID('tempdb..#userKeys') IS NOT NULL DROP TABLE #userKeys;
IF OBJECT_ID('tempdb..#allUserKeysInUse') IS NOT NULL DROP TABLE #allUserKeysInUse;
IF OBJECT_ID('tempdb..#usersToDelete') IS NOT NULL DROP TABLE #usersToDelete;

COMMIT TRANSACTION

RAISERROR('Purging Unused Users...' ,0, 1) WITH NOWAIT ;
GO

-- Null out all UserMain records that are not in use (have no associated Name Records)
RAISERROR('  Nulling out orphaned UserMain records' ,0, 1) WITH NOWAIT ;
UPDATE u
   SET u.[IsDisabled] = 1,
       u.[ContactMaster] = '',
       u.[UserId] = ''
  FROM [dbo].[UserMain] u
       LEFT OUTER JOIN [dbo].[Name] n ON u.[ContactMaster] = n.[ID]
 WHERE n.[ID] IS NULL 
   AND u.[UserId] NOT IN ('MANAGER', 'SYSTEM', 'ADMINISTRATOR', 'GUEST', 'DEMOSETUP', 'NUNIT1', 'IMISLOG')
GO
 
-- Clean out ASPNET tables of any IDs for Users that are now nulled out
RAISERROR('  Cleaning out orphaned ASPNET records' ,0, 1) WITH NOWAIT ;
IF OBJECT_ID('tempdb..#providerKeys') IS NOT NULL DROP TABLE #providerKeys;
CREATE TABLE #providerKeys ([ProviderKey] uniqueidentifier PRIMARY KEY);
INSERT INTO #providerKeys ([ProviderKey])
    SELECT [ProviderKey]
      FROM [dbo].[UserMain]
     WHERE [ContactMaster] = '' AND [UserId] = '' AND [IsDisabled] = 1 AND [ProviderKey] IS NOT NULL AND [ProviderKey] <> ''

DECLARE @applicationKey uniqueidentifier;
SELECT @applicationKey = [ApplicationId] FROM [aspnet_Applications] WHERE [LoweredApplicationName] = 'imis';
 
DELETE a 
  FROM aspnet_Profile a 
       INNER JOIN #providerKeys b ON a.[UserId] = b.[ProviderKey]
DELETE a 
  FROM aspnet_Membership a 
       INNER JOIN #providerKeys b ON a.[UserId] = b.[ProviderKey]
 WHERE a.[ApplicationId] = @applicationKey
DELETE a 
  FROM aspnet_Users a 
       INNER JOIN #providerKeys b ON a.[UserId] = b.[ProviderKey]
 WHERE a.[ApplicationId] = @applicationKey

IF OBJECT_ID('tempdb..#providerKeys') IS NOT NULL DROP TABLE #providerKeys;
GO

-- Null out the ProviderKey for all UserMain records that have been cleared out
RAISERROR('  Cleaning out orphaned provider keys' ,0, 1) WITH NOWAIT ;
UPDATE [dbo].[UserMain] 
   SET [ProviderKey] = NULL
 WHERE [ContactMaster] = '' AND [UserId] = '' AND [IsDisabled] = 1 AND [ProviderKey] IS NOT NULL 
GO

-- Collect the UserKeys for all nulled-out User records
RAISERROR('  Collecting orphaned provider keys' ,0, 1) WITH NOWAIT ;
IF OBJECT_ID('tempdb..#userKeys') IS NOT NULL DROP TABLE #userKeys;
CREATE TABLE #userKeys (UserKey uniqueidentifier PRIMARY KEY);
INSERT INTO #userKeys ([UserKey])
    SELECT [UserKey]
      FROM [dbo].[UserMain]
     WHERE [ContactMaster] = '' AND [UserId] = '' AND [IsDisabled] = 1 AND [ProviderKey] IS NULL 
--SELECT COUNT(1) AS TotalOrphanedUserKeys FROM #userKeys;

-- Get List of all UserKeys currently 'in use'
DECLARE @allUserKeysSql nvarchar(MAX);
DECLARE @cr nchar(2);
DECLARE @first bit;
SET @first = 0;
SET @allUserKeysSql = N'';
SET @cr = NCHAR(10) + NCHAR(13);
SELECT @allUserKeysSql = @allUserKeysSql + CASE WHEN @first=0 THEN N' ' ELSE @CR + N'UNION' + @CR END + 
       N'SELECT DISTINCT([' + cu.COLUMN_NAME + N']), ''' + 
       cu.TABLE_NAME + N''', ''' + cu.COLUMN_NAME + N''' FROM [' + 
       cu.TABLE_SCHEMA + N'].[' + cu.TABLE_NAME + N'] WHERE [' + cu.COLUMN_NAME + N'] IS NOT NULL', @first = 1
  FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS fk
       INNER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE cu ON fk.CONSTRAINT_NAME = cu.CONSTRAINT_NAME
 WHERE fk.CONSTRAINT_SCHEMA = N'dbo' AND fk.UNIQUE_CONSTRAINT_NAME = N'PK_UserMain'
   AND cu.TABLE_NAME NOT IN (N'UserMain', N'UserRole', 'UserToken')

IF OBJECT_ID('tempdb..#allUserKeysInUse') IS NOT NULL DROP TABLE #allUserKeysInUse;
CREATE TABLE #allUserKeysInUse (UserKey uniqueidentifier, TableName sysname COLLATE DATABASE_DEFAULT, ColumnName sysname COLLATE DATABASE_DEFAULT);
INSERT INTO #allUserKeysInUse
    EXEC (@allUserKeysSql);
    
-- Index the UserKeysInUse
CREATE NONCLUSTERED INDEX IX_allUserKeysInUse_UserKey ON #allUserKeysInUse (UserKey ASC);
--SELECT COUNT(1) AS TotalUserKeysInUse FROM #allUserKeysInUse;

-- Get a new list of all the UserKeys we're now going to delete
IF OBJECT_ID('tempdb..#usersToDelete') IS NOT NULL DROP TABLE #usersToDelete;
CREATE TABLE #usersToDelete ([UserKey] uniqueidentifier PRIMARY KEY);
INSERT INTO #usersToDelete ([UserKey])
    SELECT DISTINCT a.[UserKey] 
      FROM #userKeys a
     WHERE a.[UserKey] NOT IN (SELECT [UserKey] FROM #allUserKeysInUse);
--SELECT COUNT(1) AS TotalUsersToDelete FROM #userKeys;

-- Purge from UserRole and UserToken
RAISERROR('  Purging UserRole and UserToken' ,0, 1) WITH NOWAIT ;
DELETE b
  FROM #usersToDelete a INNER JOIN [dbo].[UserRole] b ON a.[UserKey] = b.[UserKey]
DELETE b
  FROM #usersToDelete a INNER JOIN [dbo].[UserToken] b ON a.[UserKey] = b.[UserKey]

-- Display information about the purge
DECLARE @total int
DECLARE @purging int
DECLARE @ineligible int
SELECT @total = COUNT([UserKey]) FROM #userKeys
SELECT @purging = COUNT([UserKey]) FROM #usersToDelete 
SELECT @ineligible = COUNT(a.[UserKey]) FROM #userKeys a  WHERE a.[UserKey] IN (SELECT [UserKey] FROM #allUserKeysInUse);
PRINT N'Total Users flagged as disabled: ' + CAST(@total as nvarchar)
PRINT N'Disabled Users still in use (referenced by other data): ' + CAST(@ineligible as nvarchar(10))
PRINT N'Purging ' + CAST(@purging as nvarchar(10)) + N' total Users from UserMain'

-- Purge the unreferenced Users from UserMain
RAISERROR('  Purging UserMain' ,0, 1) WITH NOWAIT ;
DECLARE @deleteSql varchar(max);
SET @deleteSql = '';
SELECT @deleteSql += 'DELETE FROM [dbo].[UserMain] WHERE [UserKey] = ''' + CAST(UserKey AS varchar(40)) + ''';' + CHAR(10) + CHAR(13)
  FROM #usersToDelete a 
RAISERROR(@deleteSql ,0, 1) WITH NOWAIT ;
EXEC(@deleteSql);

-- Clean out all Users rows without associated UserMain rows
RAISERROR('  Purging Users' ,0, 1) WITH NOWAIT ;
DELETE a
  FROM [dbo].[Users] a 
       LEFT OUTER JOIN [dbo].[UserMain] b ON a.[UserId] = b.[UserId]
 WHERE b.[UserId] IS NULL

-- Clean up temp tables
IF OBJECT_ID('tempdb..#userKeys') IS NOT NULL DROP TABLE #userKeys;
IF OBJECT_ID('tempdb..#allUserKeysInUse') IS NOT NULL DROP TABLE #allUserKeysInUse;
IF OBJECT_ID('tempdb..#usersToDelete') IS NOT NULL DROP TABLE #usersToDelete;

RAISERROR('Purging Users complete.' ,0, 1) WITH NOWAIT ;
GO
----------------------------------------------------------------------------------------------------------------------------------
RAISERROR(' ' ,0, 1) WITH NOWAIT ;
RAISERROR('Purging Unused Contacts...' ,0, 1) WITH NOWAIT ;
GO

-- Collect the ContactKeys for all rows that have no associated Name or UserMain row
IF OBJECT_ID('tempdb..#contactKeys') IS NOT NULL DROP TABLE #contactKeys;
CREATE TABLE #contactKeys ([ContactKey] uniqueidentifier PRIMARY KEY, [ID] varchar(50) COLLATE DATABASE_DEFAULT);
INSERT INTO #contactKeys ([ContactKey], [ID])
    SELECT cm.[ContactKey], ''
      FROM [dbo].[ContactMain] cm 
           INNER JOIN [dbo].[ContactStatusRef] cs ON cm.ContactStatusCode = cs.ContactStatusCode 
           LEFT OUTER JOIN [dbo].[Name] n ON cm.SyncContactID = n.ID
           LEFT OUTER JOIN [dbo].[UserMain] um ON cm.ContactKey = um.UserKey
     WHERE n.[ID] IS NULL AND um.[UserKey] IS NULL
           AND (cs.[ContactStatusDesc] = 'Delete' AND cs.[IsSystem] = 1)

RAISERROR('  Getting list of contacts in use' ,0, 1) WITH NOWAIT ;

-- Get List of all ContactKeys currently 'in use'
DECLARE @allContactKeysSql nvarchar(MAX);
DECLARE @cr nchar(2);
DECLARE @first bit;
SET @cr = NCHAR(10) + NCHAR(13);
SET @first = 0;
SET @allContactKeysSql = '';

SELECT @allContactKeysSql = @allContactKeysSql + CASE WHEN @first=0 THEN N' ' ELSE @CR + N'UNION' + @CR END + 
       N'SELECT DISTINCT([' + cu.COLUMN_NAME + N']), ''' + 
       cu.TABLE_NAME + N''', ''' + cu.COLUMN_NAME + N''' FROM [' + 
       cu.TABLE_SCHEMA + N'].[' + cu.TABLE_NAME + N'] WHERE [' + cu.COLUMN_NAME + N'] IS NOT NULL', @first = 1
  FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS fk
       INNER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE cu ON fk.CONSTRAINT_NAME = cu.CONSTRAINT_NAME
 WHERE fk.CONSTRAINT_SCHEMA = N'dbo' AND fk.UNIQUE_CONSTRAINT_NAME = N'PK_ContactMain'
   AND cu.TABLE_NAME NOT IN (
       N'ContactAddress', N'ContactBiography', N'ContactCommunicationReasonPreferences', N'ContactEducation', N'ContactFundraising', 
       N'ContactLog', N'ContactOffering', N'ContactPicture', N'ContactSalutation', N'ContactSkill',
       N'GroupMember', N'GroupMemberDetail', N'Individual', N'Institute', N'RFMMain'
       )

IF OBJECT_ID('tempdb..#allContactKeysInUse') IS NOT NULL DROP TABLE #allContactKeysInUse;
CREATE TABLE #allContactKeysInUse (ContactKey uniqueidentifier, TableName sysname COLLATE DATABASE_DEFAULT, ColumnName sysname COLLATE DATABASE_DEFAULT);
INSERT INTO #allContactKeysInUse
    EXEC (@allContactKeysSql);
-- Add in any UserKeys
INSERT INTO #allContactKeysInUse
    SELECT [UserKey], 'UserMain', 'UserKey' FROM [dbo].[UserMain]
     WHERE [UserKey] NOT IN (SELECT [ContactKey] FROM #allContactKeysInUse)

-- Index the UserKeys
CREATE NONCLUSTERED INDEX IX_allContactKeysInUse_UserKey ON #allContactKeysInUse (ContactKey);

-- Get list of distinct contacts in use
IF OBJECT_ID('tempdb..#distinctContactKeysInUse') IS NOT NULL DROP TABLE #distinctContactKeysInUse;
CREATE TABLE #distinctContactKeysInUse (ContactKey uniqueidentifier, ID varchar(12) COLLATE DATABASE_DEFAULT);
INSERT INTO #distinctContactKeysInUse
    SELECT DISTINCT(ContactKey), NULL FROM #allContactKeysInUse;
-- Add in the ID to link back to Name
UPDATE dckiu
   SET dckiu.ID = n.ID
  FROM #distinctContactKeysInUse dckiu
       INNER JOIN [dbo].[ContactMain] cm ON dckiu.ContactKey = cm.ContactKey
       INNER JOIN [dbo].[Name] n ON cm.SyncContactId = n.ID

RAISERROR('  Getting list of contacts to purge' ,0, 1) WITH NOWAIT ;

IF OBJECT_ID('tempdb..#contactsToDelete') IS NOT NULL DROP TABLE #contactsToDelete;
CREATE TABLE #contactsToDelete ([ContactKey] uniqueidentifier PRIMARY KEY);
-- Insert all easy to delete contacts minus those in use
INSERT INTO #contactsToDelete ([ContactKey])
    SELECT a.[ContactKey] 
      FROM #contactKeys a 
           LEFT OUTER JOIN #distinctContactKeysInUse b ON a.[ContactKey] = b.[ContactKey]
     WHERE b.[ContactKey] IS NULL

-- Display information about the purge
DECLARE @total int
DECLARE @purging int
DECLARE @ineligible int
SELECT @total = COUNT([ContactKey]) FROM #contactKeys
SELECT @purging = COUNT([ContactKey]) FROM #contactsToDelete
SELECT @ineligible = COUNT(a.[ContactKey]) FROM #contactKeys a INNER JOIN #distinctContactKeysInUse b ON a.[ContactKey] = b.[ContactKey]
PRINT N'Total Contacts flagged as deleted: ' + CAST(@total as nvarchar(10))
PRINT N'Deleted Contacts still in use (referenced by other data): ' + CAST(@ineligible as nvarchar(10))
PRINT N'Purging ' + CAST(@purging as nvarchar(10)) + N' total Contacts from ContactMain'

RAISERROR('  purging from groups' ,0, 1) WITH NOWAIT ;

-- Delete contact from group records (group member and group member detail)
DELETE gmd 
  FROM [dbo].[GroupMember] gm 
       INNER JOIN [dbo].[GroupMemberDetail] gmd ON gm.[GroupMemberKey] = gmd.[GroupMemberKey]
       INNER JOIN #contactsToDelete x ON gm.[MemberContactKey] = x.[ContactKey]
DELETE gm 
  FROM [dbo].[GroupMember] gm 
       INNER JOIN #contactsToDelete x ON gm.[MemberContactKey] = x.[ContactKey]
DELETE gmo 
  FROM [dbo].[GroupMemberOptions] gmo 
       INNER JOIN #contactsToDelete x ON gmo.[AlternativeBillToContactKey] = x.[ContactKey]

-- Delete contact from RFM table
DELETE rfm
  FROM [dbo].[RFMMain] rfm 
       INNER JOIN #contactsToDelete x ON rfm.[ContactKey] = x.[ContactKey]

RAISERROR('  purging from branch tables' ,0, 1) WITH NOWAIT ;

-- Delete contact from Individual and Institute branch tables
UPDATE i
   SET [PrimaryInstituteContactKey] = NULL 
  FROM [dbo].[Individual] i
       INNER JOIN #contactsToDelete x ON i.[PrimaryInstituteContactKey] = x.[ContactKey]
DELETE i 
  FROM [dbo].[Individual] i
       INNER JOIN #contactsToDelete x ON i.[ContactKey] = x.[ContactKey]
DELETE i 
  FROM [dbo].[Institute] i
       INNER JOIN #contactsToDelete x ON i.[ContactKey] = x.[ContactKey]

RAISERROR('  purging from contact related  tables' ,0, 1) WITH NOWAIT ;

-- Delete from Contact tables
DELETE c
  FROM [dbo].[ContactAddress] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactBiography] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactCommunicationReasonPreferences] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactEducation] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactFundraising] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactLog] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactOffering] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactPicture] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactSalutation] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactSkill] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
IF OBJECT_ID('dbo.ContactSocialNetwork') IS NOT NULL
BEGIN
    DELETE c
      FROM [dbo].[ContactSocialNetwork] c
           INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
END
DELETE c
  FROM [dbo].[CommunicationLogEvent] c
       INNER JOIN [dbo].[CommunicationLogRecipient] r ON c.CommunicationLogRecipientKey = r.CommunicationLogRecipientKey
       INNER JOIN #contactsToDelete x ON r.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[CommunicationLogRecipient] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]

RAISERROR('  purging from ContactMain' ,0, 1) WITH NOWAIT ;
       
DELETE c
  FROM [dbo].[ContactMain] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
       
RAISERROR('  Looking for orphaned Contacts' ,0, 1) WITH NOWAIT ;
DECLARE @straggleCount int;
SELECT @straggleCount = COUNT(1)
      FROM [dbo].[ContactMain] cm
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN [dbo].[OpportunityMain] om ON cm.[ContactKey] = om.[ProspectKey]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL
   AND (om.[ProspectKey] IS NULL) -- TODO: Clean out OpportunityMain/Group/AccessKey information associated with prospects being deleted
DECLARE @msg varchar(max);
SELECT @msg = 'Deleting ' + CAST(@straggleCount AS varchar(10)) + ' orphaned ContactMain records'
RAISERROR(@msg ,0, 1) WITH NOWAIT ;

RAISERROR('  Clearing orphaned primary contact references' ,0, 1) WITH NOWAIT ;
       
UPDATE i
   SET i.[PrimaryInstituteContactKey] = NULL
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[Individual] i ON cm.[ContactKey] = i.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL
   AND [PrimaryInstituteContactKey] IS NOT NULL

UPDATE i
   SET [PrimaryContactKey] = NULL
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[Institute] i ON cm.[ContactKey] = i.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL
   AND [PrimaryContactKey] IS NOT NULL

RAISERROR('  Deleting orphaned contact references' ,0, 1) WITH NOWAIT ;

DELETE i
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[Individual] i ON cm.[ContactKey] = i.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL
 
DELETE i
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[Institute] i ON cm.[ContactKey] = i.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL
      
DELETE cs
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[ContactSalutation] cs ON cm.[ContactKey] = cs.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL

IF OBJECT_ID('dbo.ContactSocialNetwork') IS NOT NULL
BEGIN
    DELETE csn
      FROM [dbo].[ContactMain] cm
           INNER JOIN [dbo].[ContactSocialNetwork] csn ON cm.[ContactKey] = csn.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
     WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
       AND kiu.[ContactKey] IS NULL
END

RAISERROR('  Deleting orphaned group  references' ,0, 1) WITH NOWAIT ;

DELETE gmd
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[GroupMember] gm ON cm.[ContactKey] = gm.[MemberContactKey]
       INNER JOIN [dbo].[GroupMemberDetail] gmd ON gm.[GroupMemberKey] = gmd.[GroupMemberKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL

DELETE gm
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[GroupMember] gm ON cm.[ContactKey] = gm.[MemberContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL

DELETE rfm
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[RFMMain] rfm ON cm.[ContactKey] = rfm.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL
 
DELETE ce
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[CommunicationLogRecipient] c ON c.[ContactKey] = cm.[ContactKey]
       INNER JOIN [dbo].[CommunicationLogEvent] ce ON ce.[CommunicationLogRecipientKey] = c.[CommunicationLogRecipientKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL

DELETE c
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[CommunicationLogRecipient] c ON c.[ContactKey] = cm.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
   LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL

DELETE cm
  FROM [dbo].[ContactMain] cm
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN [dbo].[OpportunityMain] om ON cm.[ContactKey] = om.[ProspectKey]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL
   AND (om.[ProspectKey] IS NULL) -- TODO: Clean out OpportunityMain/Group/AccessKey information associated with prospects being deleted

IF OBJECT_ID('dbo.GatewayTransaction') IS NOT NULL
    DELETE FROM [dbo].[GatewayTransaction] WHERE [ContactId] NOT IN (SELECT [ID] FROM [dbo].[Name]);

-- Delete orphaned UniformRegistry rows associated with the individuals & institutes we've cleaned up
RAISERROR('  Deleting uniform registry references' ,0, 1) WITH NOWAIT ;
DELETE ur 
  FROM [dbo].[UniformRegistry] ur
       INNER JOIN [dbo].[ComponentRegistry] cm ON ur.[ComponentKey] = cm.[ComponentKey] AND cm.[Name] = 'Individual'
       LEFT OUTER JOIN [dbo].[ContactMain] c ON ur.[UniformKey] = c.[ContactKey]
 WHERE c.[ContactKey] IS NULL
DELETE ur 
  FROM [dbo].UniformRegistry ur
       INNER JOIN [dbo].[ComponentRegistry] cm ON ur.[ComponentKey] = cm.[ComponentKey] AND cm.[Name] = 'Institute'
       LEFT OUTER JOIN [dbo].[ContactMain] c ON ur.[UniformKey] = c.[ContactKey]
 WHERE c.[ContactKey] IS NULL

-- Get all the Orphaned Company Groups
DECLARE @companyGroupTypeKey uniqueidentifier;
SELECT @companyGroupTypeKey = [GroupTypeKey] FROM [dbo].[GroupTypeRef] WHERE [GroupTypeName] = 'Company' AND [IsSystem] = 1;
IF OBJECT_ID('tempdb..#OrphanCompanyGroups') IS NOT NULL DROP TABLE #OrphanCompanyGroups
CREATE TABLE #OrphanCompanyGroups (GroupKey uniqueidentifier PRIMARY KEY, OwnerAccessKey uniqueidentifier);
INSERT INTO #OrphanCompanyGroups (GroupKey, OwnerAccessKey)
    SELECT [GroupKey], [OwnerAccessKey]
      FROM [dbo].[GroupMain]
     WHERE [GroupTypeKey] = @companyGroupTypeKey
       AND [GroupKey] NOT IN (SELECT [InstituteGroupKey] FROM [dbo].[Institute])

DECLARE @orphanGroupCount int;
SELECT @orphanGroupCount = COUNT(1) FROM #OrphanCompanyGroups
SELECT @msg = 'Purging ' + CAST(@orphanGroupCount AS varchar(10)) + ' orphaned company groups';
RAISERROR(@msg ,0, 1) WITH NOWAIT ;

-- Null-out the OwnerAccessKey first, so we can delete all the rows from the security table
UPDATE g
   SET [OwnerAccessKey] = NULL
  FROM [dbo].[GroupMain] g
       INNER JOIN #OrphanCompanyGroups o ON g.GroupKey = o.GroupKey
       
-- Delete all the associated security rows now
DELETE ai
  FROM [dbo].[AccessItem] ai
       INNER JOIN #OrphanCompanyGroups o ON ai.AccessKey = o.OwnerAccessKey
       INNER JOIN [dbo].[AccessMain] am ON ai.AccessKey = am.AccessKey AND am.AccessScope = 'Local'
DELETE am
  FROM [dbo].[AccessMain] am
       INNER JOIN #OrphanCompanyGroups o ON am.AccessKey = o.OwnerAccessKey AND am.AccessScope = 'Local'
-- Now delete all the orphaned company groups themselves
DELETE gmd
  FROM [dbo].[GroupMemberDetail] gmd
       INNER JOIN #OrphanCompanyGroups o ON gmd.GroupKey = o.GroupKey
DELETE gm
  FROM [dbo].[GroupMember] gm
       INNER JOIN #OrphanCompanyGroups o ON gm.GroupKey = o.GroupKey
DELETE g
  FROM [dbo].[GroupMain] g
       INNER JOIN #OrphanCompanyGroups o ON g.GroupKey = o.GroupKey
IF OBJECT_ID('tempdb..#OrphanCompanyGroups') IS NOT NULL DROP TABLE #OrphanCompanyGroups

-- Get all the Orphaned Subscriber Groups
DECLARE @subscriptionGroupTypeKey uniqueidentifier;
SELECT @subscriptionGroupTypeKey = [GroupTypeKey] FROM [dbo].[GroupTypeRef] WHERE [GroupTypeName] = 'Subscriber Group' AND [IsSystem] = 1;
IF OBJECT_ID('tempdb..#OrphanSubscriberGroups') IS NOT NULL DROP TABLE #OrphanSubscriberGroups
CREATE TABLE #OrphanSubscriberGroups (GroupKey uniqueidentifier PRIMARY KEY, OwnerAccessKey uniqueidentifier);
INSERT INTO #OrphanSubscriberGroups (GroupKey, OwnerAccessKey)
    SELECT GroupKey, OwnerAccessKey
      FROM [dbo].[GroupMain]
     WHERE [GroupTypeKey] = @subscriptionGroupTypeKey
   AND CAST([Name] AS uniqueidentifier) NOT IN (SELECT [DocumentVersionKey] FROM [dbo].[DocumentMain] WHERE [DocumentTypeCode] = 'CTY')
   
SELECT @orphanGroupCount = COUNT(1) FROM #OrphanSubscriberGroups
SELECT @msg = 'Purging ' + CAST(@orphanGroupCount AS varchar(10)) + ' orphaned subscriber groups';
RAISERROR(@msg ,0, 1) WITH NOWAIT ;

-- Null-out the OwnerAccessKey first, so we can delete all the rows from the security table
UPDATE g
   SET [OwnerAccessKey] = NULL
  FROM [dbo].[GroupMain] g
       INNER JOIN #OrphanSubscriberGroups o ON g.GroupKey = o.GroupKey
-- Delete all the associated security rows now
DELETE ai
  FROM [dbo].[AccessItem] ai
       INNER JOIN #OrphanSubscriberGroups o ON ai.AccessKey = o.OwnerAccessKey
       INNER JOIN [dbo].[AccessMain] am ON ai.AccessKey = am.AccessKey AND am.AccessScope = 'Local'
DELETE am
  FROM [dbo].[AccessMain] am
       INNER JOIN #OrphanSubscriberGroups o ON am.AccessKey = o.OwnerAccessKey AND am.AccessScope = 'Local'
-- Now delete all the orphaned company groups themselves
DELETE gmd
  FROM [dbo].[GroupMemberDetail] gmd
       INNER JOIN #OrphanSubscriberGroups o ON gmd.GroupKey = o.GroupKey
DELETE gm
  FROM [dbo].[GroupMember] gm
       INNER JOIN #OrphanSubscriberGroups o ON gm.GroupKey = o.GroupKey
DELETE g
  FROM [dbo].[GroupMain] g
       INNER JOIN #OrphanSubscriberGroups o ON g.GroupKey = o.GroupKey
IF OBJECT_ID('tempdb..#OrphanSubscriberGroups') IS NOT NULL DROP TABLE #OrphanSubscriberGroups

-- Get all the Orphaned Opportunity Groups
IF OBJECT_ID('tempdb..#OrphanOpportunityGroups') IS NOT NULL DROP TABLE #OrphanOpportunityGroups
CREATE TABLE #OrphanOpportunityGroups (GroupKey uniqueidentifier PRIMARY KEY, AccessKey uniqueidentifier);
INSERT INTO #OrphanOpportunityGroups (GroupKey, AccessKey)
    SELECT GroupKey, AccessKey
      FROM [dbo].[GroupMain]
     WHERE [GroupTypeKey] IN (
           SELECT GroupTypeKey FROM GroupTypeRef WHERE GroupTypeName LIKE 'Opp %' AND [IsSystem] = 1 AND [IsAutoGenerated] = 1
           ) 
       AND [GroupKey] NOT IN (
           SELECT [OpportunityOwnerGroupKey] FROM [dbo].[OpportunityMain]
           UNION
           SELECT [OpportunityContactGroupKey] FROM [dbo].[OpportunityMain]
           )

SELECT @orphanGroupCount = COUNT(1) FROM #OrphanOpportunityGroups
SELECT @msg = 'Purging ' + CAST(@orphanGroupCount AS varchar(10)) + ' orphaned opportunity groups';
RAISERROR(@msg ,0, 1) WITH NOWAIT ;

-- Delete all the associated security rows now 
DELETE ai
  FROM [dbo].[AccessItem] ai
       INNER JOIN #OrphanOpportunityGroups o ON ai.AccessKey = o.AccessKey
       INNER JOIN [dbo].[AccessMain] am ON ai.AccessKey = am.AccessKey AND (am.AccessScope = 'Local' OR am.AccessScope = 'Shared')
-- Delete the AccessItem rows referencing these groups (if any... TODO: Delete opportunities referencing these security sets)
DELETE ai
  FROM [dbo].[AccessItem] ai
       INNER JOIN #OrphanOpportunityGroups o ON ai.GroupKey = o.GroupKey
       INNER JOIN [dbo].[AccessMain] am ON o.AccessKey = am.AccessKey AND (am.AccessScope = 'Local' OR am.AccessScope = 'Shared')

-- Now delete all the orphaned company groups themselves
DELETE gmd
  FROM [dbo].[GroupMemberDetail] gmd
       INNER JOIN #OrphanOpportunityGroups o ON gmd.GroupKey = o.GroupKey
DELETE gm
  FROM [dbo].[GroupMember] gm
       INNER JOIN #OrphanOpportunityGroups o ON gm.GroupKey = o.GroupKey
DELETE g
  FROM [dbo].[GroupMain] g
       INNER JOIN #OrphanOpportunityGroups o ON g.GroupKey = o.GroupKey
-- Delete task items with access settings that we're going to delete
DELETE ti
  FROM [dbo].[TaskItem] ti
       INNER JOIN #OrphanOpportunityGroups o ON ti.AccessKey = o.AccessKey
-- Delete all the AccessKey rows now
DELETE am
  FROM [dbo].[AccessMain] am
       INNER JOIN #OrphanOpportunityGroups o ON am.AccessKey = o.AccessKey AND (am.AccessScope = 'Local' OR am.AccessScope = 'Shared')
IF OBJECT_ID('tempdb..#OrphanOpportunityGroups') IS NOT NULL DROP TABLE #OrphanOpportunityGroups

-- Finally, clean up the UniformRegistry entries
DELETE ur 
  FROM UniformRegistry ur
       INNER JOIN ComponentRegistry cm ON ur.ComponentKey = cm.ComponentKey AND cm.Name = 'Group'
       LEFT OUTER JOIN [dbo].[GroupMain] g ON ur.UniformKey = g.GroupKey
 WHERE g.GroupKey IS NULL


IF OBJECT_ID('tempdb..#contactKeys') IS NOT NULL DROP TABLE #contactKeys;
IF OBJECT_ID('tempdb..#allContactKeysInUse') IS NOT NULL DROP TABLE #allContactKeysInUse;
IF OBJECT_ID('tempdb..#distinctContactKeysInUse') IS NOT NULL DROP TABLE #distinctContactKeysInUse;
IF OBJECT_ID('tempdb..#contactsToDelete') IS NOT NULL DROP TABLE #contactsToDelete;
GO

RAISERROR('Done.' ,0, 1) WITH NOWAIT ;

GO



-----------------------------------
--********************************
--ASI Purge Scripts
--********************************
-----------------------------------
RAISERROR('Purging Orphaned Rows in Name_* tables...' ,0, 1) WITH NOWAIT ;
GO

-- Purge Related NAME tables
DELETE x FROM [dbo].[Name_Address] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_AlternateId] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Annuity] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_CEU] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Demo] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Estates] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Fin] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_FR] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_FRAdditionalInfo] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_FREventInformation] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_FRProfile] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_FRSurveyQuestion] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_FRTeamInformation] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_FRTransactionLog] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Indexes] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_JoinOnline] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Log] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Lookup] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_MatchPlan] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Note] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Notify] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Picture] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_PlannedGiving] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Research] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Salutation] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Security] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Security_Groups] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Staff] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_TabTest] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Name_Volunteer] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
-- Purge other tables related to ID
DELETE x FROM [dbo].[Receipt] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Basket_Dues] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Basket_Function] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Basket_Meeting] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Basket_Order] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[Basket_Payment] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL
DELETE x FROM [dbo].[CartBilling] x LEFT OUTER JOIN [dbo].[Name] n ON x.ID = n.ID WHERE n.ID IS NULL

-- Delete from UD Tables
DECLARE @cr char(1);
DECLARE @purgeUDTableSql varchar(MAX);
SET @cr = CHAR(13);
SET @purgeUDTableSql = '';
SELECT @purgeUDTableSql += 'DELETE FROM [dbo].' + QUOTENAME(TABLE_NAME) + ' WHERE ID NOT IN (SELECT ID FROM Name);' + @cr
  FROM [dbo].[UD_Table]
 WHERE APPLICATION = 'Membership' AND LINK_VIA = 'ID'
EXEC(@purgeUDTableSql);

-- Delete from Panel Editor tables
DELETE FROM dbo.UserDefinedSingleInstanceProperty WHERE RowID NOT IN (SELECT ID FROM Name);
DELETE FROM dbo.UserDefinedMultiInstanceProperty WHERE RowID NOT IN (SELECT ID FROM Name);

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'UserDefinedTableStorage')
BEGIN
    DELETE FROM dbo.UserDefinedTableStorage WHERE RowID NOT IN (SELECT ID FROM Name);
END


IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'IndividualExternalNetwork')
    DELETE FROM [dbo].[IndividualExternalNetwork]
    WHERE [ID] NOT IN (SELECT [ID] FROM [dbo].[Name])
GO

RAISERROR('Purging Unused Users...' ,0, 1) WITH NOWAIT ;
GO

-- Null out all UserMain records that are not in use (have no associated Name Records)
RAISERROR('  Nulling out orphaned UserMain records' ,0, 1) WITH NOWAIT ;
UPDATE u
   SET u.[IsDisabled] = 1,
       u.[ContactMaster] = '',
       u.[UserId] = ''
  FROM [dbo].[UserMain] u
       LEFT OUTER JOIN [dbo].[Name] n ON u.[ContactMaster] = n.[ID]
 WHERE n.[ID] IS NULL 
   AND u.[UserId] NOT IN ('MANAGER', 'SYSTEM', 'ADMINISTRATOR', 'GUEST', 'DEMOSETUP', 'NUNIT1', 'IMISLOG')
GO
 
-- Clean out ASPNET tables of any IDs for Users that are now nulled out
RAISERROR('  Cleaning out orphaned ASPNET records' ,0, 1) WITH NOWAIT ;
IF OBJECT_ID('tempdb..#providerKeys') IS NOT NULL DROP TABLE #providerKeys;
CREATE TABLE #providerKeys ([ProviderKey] uniqueidentifier PRIMARY KEY);
INSERT INTO #providerKeys ([ProviderKey])
    SELECT [ProviderKey]
      FROM [dbo].[UserMain]
     WHERE [ContactMaster] = '' AND [UserId] = '' AND [IsDisabled] = 1 AND [ProviderKey] IS NOT NULL AND [ProviderKey] <> ''

DECLARE @applicationKey uniqueidentifier;
SELECT @applicationKey = [ApplicationId] FROM [aspnet_Applications] WHERE [LoweredApplicationName] = 'imis';
 
DELETE a 
  FROM aspnet_Profile a 
       INNER JOIN #providerKeys b ON a.[UserId] = b.[ProviderKey]
DELETE a 
  FROM aspnet_Membership a 
       INNER JOIN #providerKeys b ON a.[UserId] = b.[ProviderKey]
 WHERE a.[ApplicationId] = @applicationKey
DELETE a 
  FROM aspnet_Users a 
       INNER JOIN #providerKeys b ON a.[UserId] = b.[ProviderKey]
 WHERE a.[ApplicationId] = @applicationKey

IF OBJECT_ID('tempdb..#providerKeys') IS NOT NULL DROP TABLE #providerKeys;
GO

-- Null out the ProviderKey for all UserMain records that have been cleared out
RAISERROR('  Cleaning out orphaned provider keys' ,0, 1) WITH NOWAIT ;
UPDATE [dbo].[UserMain] 
   SET [ProviderKey] = NULL
 WHERE [ContactMaster] = '' AND [UserId] = '' AND [IsDisabled] = 1 AND [ProviderKey] IS NOT NULL 
GO

-- Collect the UserKeys for all nulled-out User records
RAISERROR('  Collecting orphaned provider keys' ,0, 1) WITH NOWAIT ;
IF OBJECT_ID('tempdb..#userKeys') IS NOT NULL DROP TABLE #userKeys;
CREATE TABLE #userKeys (UserKey uniqueidentifier PRIMARY KEY);
INSERT INTO #userKeys ([UserKey])
    SELECT [UserKey]
      FROM [dbo].[UserMain]
     WHERE [ContactMaster] = '' AND [UserId] = '' AND [IsDisabled] = 1 AND [ProviderKey] IS NULL 
--SELECT COUNT(1) AS TotalOrphanedUserKeys FROM #userKeys;

-- Get List of all UserKeys currently 'in use'
DECLARE @allUserKeysSql nvarchar(MAX);
DECLARE @cr nchar(2);
DECLARE @first bit;
SET @first = 0;
SET @allUserKeysSql = N'';
SET @cr = NCHAR(10) + NCHAR(13);
SELECT @allUserKeysSql = @allUserKeysSql + CASE WHEN @first=0 THEN N' ' ELSE @CR + N'UNION' + @CR END + 
       N'SELECT DISTINCT([' + cu.COLUMN_NAME + N']), ''' + 
       cu.TABLE_NAME + N''', ''' + cu.COLUMN_NAME + N''' FROM [' + 
       cu.TABLE_SCHEMA + N'].[' + cu.TABLE_NAME + N'] WHERE [' + cu.COLUMN_NAME + N'] IS NOT NULL', @first = 1
  FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS fk
       INNER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE cu ON fk.CONSTRAINT_NAME = cu.CONSTRAINT_NAME
 WHERE fk.CONSTRAINT_SCHEMA = N'dbo' AND fk.UNIQUE_CONSTRAINT_NAME = N'PK_UserMain'
   AND cu.TABLE_NAME NOT IN (N'UserMain', N'UserRole', 'UserToken')

IF OBJECT_ID('tempdb..#allUserKeysInUse') IS NOT NULL DROP TABLE #allUserKeysInUse;
CREATE TABLE #allUserKeysInUse (UserKey uniqueidentifier, TableName sysname COLLATE DATABASE_DEFAULT, ColumnName sysname COLLATE DATABASE_DEFAULT);
INSERT INTO #allUserKeysInUse
    EXEC (@allUserKeysSql);
    
-- Index the UserKeysInUse
CREATE NONCLUSTERED INDEX IX_allUserKeysInUse_UserKey ON #allUserKeysInUse (UserKey ASC);
--SELECT COUNT(1) AS TotalUserKeysInUse FROM #allUserKeysInUse;

-- Get a new list of all the UserKeys we're now going to delete
IF OBJECT_ID('tempdb..#usersToDelete') IS NOT NULL DROP TABLE #usersToDelete;
CREATE TABLE #usersToDelete ([UserKey] uniqueidentifier PRIMARY KEY);
INSERT INTO #usersToDelete ([UserKey])
    SELECT DISTINCT a.[UserKey] 
      FROM #userKeys a
     WHERE a.[UserKey] NOT IN (SELECT [UserKey] FROM #allUserKeysInUse);
--SELECT COUNT(1) AS TotalUsersToDelete FROM #userKeys;

-- Purge from UserRole and UserToken
RAISERROR('  Purging UserRole and UserToken' ,0, 1) WITH NOWAIT ;
DELETE b
  FROM #usersToDelete a INNER JOIN [dbo].[UserRole] b ON a.[UserKey] = b.[UserKey]
DELETE b
  FROM #usersToDelete a INNER JOIN [dbo].[UserToken] b ON a.[UserKey] = b.[UserKey]

-- Display information about the purge
DECLARE @total int
DECLARE @purging int
DECLARE @ineligible int
SELECT @total = COUNT([UserKey]) FROM #userKeys
SELECT @purging = COUNT([UserKey]) FROM #usersToDelete 
SELECT @ineligible = COUNT(a.[UserKey]) FROM #userKeys a  WHERE a.[UserKey] IN (SELECT [UserKey] FROM #allUserKeysInUse);
PRINT N'Total Users flagged as disabled: ' + CAST(@total as nvarchar)
PRINT N'Disabled Users still in use (referenced by other data): ' + CAST(@ineligible as nvarchar(10))
PRINT N'Purging ' + CAST(@purging as nvarchar(10)) + N' total Users from UserMain'

-- Purge the unreferenced Users from UserMain
RAISERROR('  Purging UserMain' ,0, 1) WITH NOWAIT ;
DECLARE @deleteSql varchar(max);
SET @deleteSql = '';
SELECT @deleteSql += 'DELETE FROM [dbo].[UserMain] WHERE [UserKey] = ''' + CAST(UserKey AS varchar(40)) + ''';' + CHAR(10) + CHAR(13)
  FROM #usersToDelete a 
RAISERROR(@deleteSql ,0, 1) WITH NOWAIT ;
EXEC(@deleteSql);

-- Clean out all Users rows without associated UserMain rows
RAISERROR('  Purging Users' ,0, 1) WITH NOWAIT ;
DELETE a
  FROM [dbo].[Users] a 
       LEFT OUTER JOIN [dbo].[UserMain] b ON a.[UserId] = b.[UserId]
 WHERE b.[UserId] IS NULL

-- Clean up temp tables
IF OBJECT_ID('tempdb..#userKeys') IS NOT NULL DROP TABLE #userKeys;
IF OBJECT_ID('tempdb..#allUserKeysInUse') IS NOT NULL DROP TABLE #allUserKeysInUse;
IF OBJECT_ID('tempdb..#usersToDelete') IS NOT NULL DROP TABLE #usersToDelete;

RAISERROR('Purging Users complete.' ,0, 1) WITH NOWAIT ;
GO
----------------------------------------------------------------------------------------------------------------------------------
RAISERROR(' ' ,0, 1) WITH NOWAIT ;
RAISERROR('Purging Unused Contacts...' ,0, 1) WITH NOWAIT ;
GO

-- Collect the ContactKeys for all rows that have no associated Name or UserMain row
IF OBJECT_ID('tempdb..#contactKeys') IS NOT NULL DROP TABLE #contactKeys;
CREATE TABLE #contactKeys ([ContactKey] uniqueidentifier PRIMARY KEY, [ID] varchar(50) COLLATE DATABASE_DEFAULT);
INSERT INTO #contactKeys ([ContactKey], [ID])
    SELECT cm.[ContactKey], ''
      FROM [dbo].[ContactMain] cm 
           INNER JOIN [dbo].[ContactStatusRef] cs ON cm.ContactStatusCode = cs.ContactStatusCode 
           LEFT OUTER JOIN [dbo].[Name] n ON cm.SyncContactID = n.ID
           LEFT OUTER JOIN [dbo].[UserMain] um ON cm.ContactKey = um.UserKey
     WHERE n.[ID] IS NULL AND um.[UserKey] IS NULL
           AND (cs.[ContactStatusDesc] = 'Delete' AND cs.[IsSystem] = 1)

RAISERROR('  Getting list of contacts in use' ,0, 1) WITH NOWAIT ;

-- Get List of all ContactKeys currently 'in use'
DECLARE @allContactKeysSql nvarchar(MAX);
DECLARE @cr nchar(2);
DECLARE @first bit;
SET @cr = NCHAR(10) + NCHAR(13);
SET @first = 0;
SET @allContactKeysSql = '';

SELECT @allContactKeysSql = @allContactKeysSql + CASE WHEN @first=0 THEN N' ' ELSE @CR + N'UNION' + @CR END + 
       N'SELECT DISTINCT([' + cu.COLUMN_NAME + N']), ''' + 
       cu.TABLE_NAME + N''', ''' + cu.COLUMN_NAME + N''' FROM [' + 
       cu.TABLE_SCHEMA + N'].[' + cu.TABLE_NAME + N'] WHERE [' + cu.COLUMN_NAME + N'] IS NOT NULL', @first = 1
  FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS fk
       INNER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE cu ON fk.CONSTRAINT_NAME = cu.CONSTRAINT_NAME
 WHERE fk.CONSTRAINT_SCHEMA = N'dbo' AND fk.UNIQUE_CONSTRAINT_NAME = N'PK_ContactMain'
   AND cu.TABLE_NAME NOT IN (
       N'ContactAddress', N'ContactBiography', N'ContactCommunicationReasonPreferences', N'ContactEducation', N'ContactFundraising', 
       N'ContactLog', N'ContactOffering', N'ContactPicture', N'ContactSalutation', N'ContactSkill',
       N'GroupMember', N'GroupMemberDetail', N'Individual', N'Institute', N'RFMMain'
       )

IF OBJECT_ID('tempdb..#allContactKeysInUse') IS NOT NULL DROP TABLE #allContactKeysInUse;
CREATE TABLE #allContactKeysInUse (ContactKey uniqueidentifier, TableName sysname COLLATE DATABASE_DEFAULT, ColumnName sysname COLLATE DATABASE_DEFAULT);
INSERT INTO #allContactKeysInUse
    EXEC (@allContactKeysSql);
-- Add in any UserKeys
INSERT INTO #allContactKeysInUse
    SELECT [UserKey], 'UserMain', 'UserKey' FROM [dbo].[UserMain]
     WHERE [UserKey] NOT IN (SELECT [ContactKey] FROM #allContactKeysInUse)

-- Index the UserKeys
CREATE NONCLUSTERED INDEX IX_allContactKeysInUse_UserKey ON #allContactKeysInUse (ContactKey);

-- Get list of distinct contacts in use
IF OBJECT_ID('tempdb..#distinctContactKeysInUse') IS NOT NULL DROP TABLE #distinctContactKeysInUse;
CREATE TABLE #distinctContactKeysInUse (ContactKey uniqueidentifier, ID varchar(12) COLLATE DATABASE_DEFAULT);
INSERT INTO #distinctContactKeysInUse
    SELECT DISTINCT(ContactKey), NULL FROM #allContactKeysInUse;
-- Add in the ID to link back to Name
UPDATE dckiu
   SET dckiu.ID = n.ID
  FROM #distinctContactKeysInUse dckiu
       INNER JOIN [dbo].[ContactMain] cm ON dckiu.ContactKey = cm.ContactKey
       INNER JOIN [dbo].[Name] n ON cm.SyncContactId = n.ID

RAISERROR('  Getting list of contacts to purge' ,0, 1) WITH NOWAIT ;

IF OBJECT_ID('tempdb..#contactsToDelete') IS NOT NULL DROP TABLE #contactsToDelete;
CREATE TABLE #contactsToDelete ([ContactKey] uniqueidentifier PRIMARY KEY);
-- Insert all easy to delete contacts minus those in use
INSERT INTO #contactsToDelete ([ContactKey])
    SELECT a.[ContactKey] 
      FROM #contactKeys a 
           LEFT OUTER JOIN #distinctContactKeysInUse b ON a.[ContactKey] = b.[ContactKey]
     WHERE b.[ContactKey] IS NULL

-- Display information about the purge
DECLARE @total int
DECLARE @purging int
DECLARE @ineligible int
SELECT @total = COUNT([ContactKey]) FROM #contactKeys
SELECT @purging = COUNT([ContactKey]) FROM #contactsToDelete
SELECT @ineligible = COUNT(a.[ContactKey]) FROM #contactKeys a INNER JOIN #distinctContactKeysInUse b ON a.[ContactKey] = b.[ContactKey]
PRINT N'Total Contacts flagged as deleted: ' + CAST(@total as nvarchar(10))
PRINT N'Deleted Contacts still in use (referenced by other data): ' + CAST(@ineligible as nvarchar(10))
PRINT N'Purging ' + CAST(@purging as nvarchar(10)) + N' total Contacts from ContactMain'

RAISERROR('  purging from groups' ,0, 1) WITH NOWAIT ;

-- Delete contact from group records (group member and group member detail)
DELETE gmd 
  FROM [dbo].[GroupMember] gm 
       INNER JOIN [dbo].[GroupMemberDetail] gmd ON gm.[GroupMemberKey] = gmd.[GroupMemberKey]
       INNER JOIN #contactsToDelete x ON gm.[MemberContactKey] = x.[ContactKey]
DELETE gm 
  FROM [dbo].[GroupMember] gm 
       INNER JOIN #contactsToDelete x ON gm.[MemberContactKey] = x.[ContactKey]
DELETE gmo 
  FROM [dbo].[GroupMemberOptions] gmo 
       INNER JOIN #contactsToDelete x ON gmo.[AlternativeBillToContactKey] = x.[ContactKey]

-- Delete contact from RFM table
DELETE rfm
  FROM [dbo].[RFMMain] rfm 
       INNER JOIN #contactsToDelete x ON rfm.[ContactKey] = x.[ContactKey]

RAISERROR('  purging from branch tables' ,0, 1) WITH NOWAIT ;

-- Delete contact from Individual and Institute branch tables
UPDATE i
   SET [PrimaryInstituteContactKey] = NULL 
  FROM [dbo].[Individual] i
       INNER JOIN #contactsToDelete x ON i.[PrimaryInstituteContactKey] = x.[ContactKey]
DELETE i 
  FROM [dbo].[Individual] i
       INNER JOIN #contactsToDelete x ON i.[ContactKey] = x.[ContactKey]
DELETE i 
  FROM [dbo].[Institute] i
       INNER JOIN #contactsToDelete x ON i.[ContactKey] = x.[ContactKey]

RAISERROR('  purging from contact related  tables' ,0, 1) WITH NOWAIT ;

-- Delete from Contact tables
DELETE c
  FROM [dbo].[ContactAddress] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactBiography] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactCommunicationReasonPreferences] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactEducation] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactFundraising] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactLog] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactOffering] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactPicture] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactSalutation] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[ContactSkill] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
IF OBJECT_ID('dbo.ContactSocialNetwork') IS NOT NULL
BEGIN
    DELETE c
      FROM [dbo].[ContactSocialNetwork] c
           INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
END
DELETE c
  FROM [dbo].[CommunicationLogEvent] c
       INNER JOIN [dbo].[CommunicationLogRecipient] r ON c.CommunicationLogRecipientKey = r.CommunicationLogRecipientKey
       INNER JOIN #contactsToDelete x ON r.[ContactKey] = x.[ContactKey]
DELETE c
  FROM [dbo].[CommunicationLogRecipient] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]

RAISERROR('  purging from ContactMain' ,0, 1) WITH NOWAIT ;
       
DELETE c
  FROM [dbo].[ContactMain] c
       INNER JOIN #contactsToDelete x ON c.[ContactKey] = x.[ContactKey]
       
RAISERROR('  Looking for orphaned Contacts' ,0, 1) WITH NOWAIT ;
DECLARE @straggleCount int;
SELECT @straggleCount = COUNT(1)
      FROM [dbo].[ContactMain] cm
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN [dbo].[OpportunityMain] om ON cm.[ContactKey] = om.[ProspectKey]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL
   AND (om.[ProspectKey] IS NULL) -- TODO: Clean out OpportunityMain/Group/AccessKey information associated with prospects being deleted
DECLARE @msg varchar(max);
SELECT @msg = 'Deleting ' + CAST(@straggleCount AS varchar(10)) + ' orphaned ContactMain records'
RAISERROR(@msg ,0, 1) WITH NOWAIT ;

RAISERROR('  Clearing orphaned primary contact references' ,0, 1) WITH NOWAIT ;
       
UPDATE [dbo].[Individual] 
   SET [PrimaryInstituteContactKey] = NULL 
 WHERE [PrimaryInstituteContactKey] IN (
    SELECT i.ContactKey
      FROM [dbo].[ContactMain] cm
           INNER JOIN [dbo].[Institute] i ON cm.[ContactKey] = i.[ContactKey]
           LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
           LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
           LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
     WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
       AND kiu.[ContactKey] IS NULL
)

UPDATE [dbo].[Institute]
   SET [PrimaryContactKey] = NULL 
 WHERE [PrimaryContactKey] IN (
    SELECT i.ContactKey
      FROM [dbo].[ContactMain] cm
           INNER JOIN [dbo].[Individual] i ON cm.[ContactKey] = i.[ContactKey]
           LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
           LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
           LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
     WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
       AND kiu.[ContactKey] IS NULL
 )

RAISERROR('  Deleting orphaned contact references' ,0, 1) WITH NOWAIT ;

DELETE i
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[Individual] i ON cm.[ContactKey] = i.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL
 
DELETE i
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[Institute] i ON cm.[ContactKey] = i.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL
      
DELETE cs
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[ContactSalutation] cs ON cm.[ContactKey] = cs.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL

IF OBJECT_ID('dbo.ContactSocialNetwork') IS NOT NULL
BEGIN
    DELETE csn
      FROM [dbo].[ContactMain] cm
           INNER JOIN [dbo].[ContactSocialNetwork] csn ON cm.[ContactKey] = csn.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
     WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
       AND kiu.[ContactKey] IS NULL
END

RAISERROR('  Deleting orphaned group  references' ,0, 1) WITH NOWAIT ;

DELETE gmd
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[GroupMember] gm ON cm.[ContactKey] = gm.[MemberContactKey]
       INNER JOIN [dbo].[GroupMemberDetail] gmd ON gm.[GroupMemberKey] = gmd.[GroupMemberKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL

DELETE gm
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[GroupMember] gm ON cm.[ContactKey] = gm.[MemberContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL

DELETE rfm
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[RFMMain] rfm ON cm.[ContactKey] = rfm.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL
 
DELETE ce
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[CommunicationLogRecipient] c ON c.[ContactKey] = cm.[ContactKey]
       INNER JOIN [dbo].[CommunicationLogEvent] ce ON ce.[CommunicationLogRecipientKey] = c.[CommunicationLogRecipientKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL

DELETE c
  FROM [dbo].[ContactMain] cm
       INNER JOIN [dbo].[CommunicationLogRecipient] c ON c.[ContactKey] = cm.[ContactKey]
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
   LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL

DELETE cm
  FROM [dbo].[ContactMain] cm
       LEFT OUTER JOIN [dbo].[UserMain] u ON cm.[ContactKey] = u.[UserKey]
       LEFT OUTER JOIN [dbo].[Name] n ON cm.[SyncContactId] = n.[ID]
       LEFT OUTER JOIN [dbo].[OpportunityMain] om ON cm.[ContactKey] = om.[ProspectKey]
       LEFT OUTER JOIN #distinctContactKeysInUse kiu ON cm.[ContactKey] = kiu.[ContactKey]
 WHERE (cm.[SyncContactID] IS NULL OR cm.[SyncContactID] = '' OR n.[ID] IS NULL) AND (u.[UserKey] IS NULL OR u.[UserId] = '')
   AND kiu.[ContactKey] IS NULL
   AND (om.[ProspectKey] IS NULL) -- TODO: Clean out OpportunityMain/Group/AccessKey information associated with prospects being deleted

IF OBJECT_ID('dbo.GatewayTransaction') IS NOT NULL
    DELETE FROM [dbo].[GatewayTransaction] WHERE [ContactId] NOT IN (SELECT [ID] FROM [dbo].[Name]);

-- Delete orphaned UniformRegistry rows associated with the individuals & institutes we've cleaned up
RAISERROR('  Deleting uniform registry references' ,0, 1) WITH NOWAIT ;
DELETE ur 
  FROM [dbo].[UniformRegistry] ur
       INNER JOIN [dbo].[ComponentRegistry] cm ON ur.[ComponentKey] = cm.[ComponentKey] AND cm.[Name] = 'Individual'
       LEFT OUTER JOIN [dbo].[ContactMain] c ON ur.[UniformKey] = c.[ContactKey]
 WHERE c.[ContactKey] IS NULL
DELETE ur 
  FROM [dbo].UniformRegistry ur
       INNER JOIN [dbo].[ComponentRegistry] cm ON ur.[ComponentKey] = cm.[ComponentKey] AND cm.[Name] = 'Institute'
       LEFT OUTER JOIN [dbo].[ContactMain] c ON ur.[UniformKey] = c.[ContactKey]
 WHERE c.[ContactKey] IS NULL

-- Get all the Orphaned Company Groups
DECLARE @companyGroupTypeKey uniqueidentifier;
SELECT @companyGroupTypeKey = [GroupTypeKey] FROM [dbo].[GroupTypeRef] WHERE [GroupTypeName] = 'Company' AND [IsSystem] = 1;
IF OBJECT_ID('tempdb..#OrphanCompanyGroups') IS NOT NULL DROP TABLE #OrphanCompanyGroups
CREATE TABLE #OrphanCompanyGroups (GroupKey uniqueidentifier PRIMARY KEY, OwnerAccessKey uniqueidentifier);
INSERT INTO #OrphanCompanyGroups (GroupKey, OwnerAccessKey)
    SELECT [GroupKey], [OwnerAccessKey]
      FROM [dbo].[GroupMain]
     WHERE [GroupTypeKey] = @companyGroupTypeKey
       AND [GroupKey] NOT IN (SELECT [InstituteGroupKey] FROM [dbo].[Institute])

DECLARE @orphanGroupCount int;
SELECT @orphanGroupCount = COUNT(1) FROM #OrphanCompanyGroups
SELECT @msg = 'Purging ' + CAST(@orphanGroupCount AS varchar(10)) + ' orphaned company groups';
RAISERROR(@msg ,0, 1) WITH NOWAIT ;

-- Null-out the OwnerAccessKey first, so we can delete all the rows from the security table
UPDATE g
   SET [OwnerAccessKey] = NULL
  FROM [dbo].[GroupMain] g
       INNER JOIN #OrphanCompanyGroups o ON g.GroupKey = o.GroupKey
       
-- Delete all the associated security rows now
DELETE ai
  FROM [dbo].[AccessItem] ai
       INNER JOIN #OrphanCompanyGroups o ON ai.AccessKey = o.OwnerAccessKey
       INNER JOIN [dbo].[AccessMain] am ON ai.AccessKey = am.AccessKey AND am.AccessScope = 'Local'
DELETE am
  FROM [dbo].[AccessMain] am
       INNER JOIN #OrphanCompanyGroups o ON am.AccessKey = o.OwnerAccessKey AND am.AccessScope = 'Local'
-- Now delete all the orphaned company groups themselves
DELETE gmd
  FROM [dbo].[GroupMemberDetail] gmd
       INNER JOIN #OrphanCompanyGroups o ON gmd.GroupKey = o.GroupKey
DELETE gm
  FROM [dbo].[GroupMember] gm
       INNER JOIN #OrphanCompanyGroups o ON gm.GroupKey = o.GroupKey
DELETE g
  FROM [dbo].[GroupMain] g
       INNER JOIN #OrphanCompanyGroups o ON g.GroupKey = o.GroupKey
IF OBJECT_ID('tempdb..#OrphanCompanyGroups') IS NOT NULL DROP TABLE #OrphanCompanyGroups

-- Get all the Orphaned Subscriber Groups
DECLARE @subscriptionGroupTypeKey uniqueidentifier;
SELECT @subscriptionGroupTypeKey = [GroupTypeKey] FROM [dbo].[GroupTypeRef] WHERE [GroupTypeName] = 'Subscriber Group' AND [IsSystem] = 1;
IF OBJECT_ID('tempdb..#OrphanSubscriberGroups') IS NOT NULL DROP TABLE #OrphanSubscriberGroups
CREATE TABLE #OrphanSubscriberGroups (GroupKey uniqueidentifier PRIMARY KEY, OwnerAccessKey uniqueidentifier);
INSERT INTO #OrphanSubscriberGroups (GroupKey, OwnerAccessKey)
    SELECT GroupKey, OwnerAccessKey
      FROM [dbo].[GroupMain]
     WHERE [GroupTypeKey] = @subscriptionGroupTypeKey
   AND CAST([Name] AS uniqueidentifier) NOT IN (SELECT [DocumentVersionKey] FROM [dbo].[DocumentMain] WHERE [DocumentTypeCode] = 'CTY')
   
SELECT @orphanGroupCount = COUNT(1) FROM #OrphanSubscriberGroups
SELECT @msg = 'Purging ' + CAST(@orphanGroupCount AS varchar(10)) + ' orphaned subscriber groups';
RAISERROR(@msg ,0, 1) WITH NOWAIT ;

-- Null-out the OwnerAccessKey first, so we can delete all the rows from the security table
UPDATE g
   SET [OwnerAccessKey] = NULL
  FROM [dbo].[GroupMain] g
       INNER JOIN #OrphanSubscriberGroups o ON g.GroupKey = o.GroupKey
-- Delete all the associated security rows now
DELETE ai
  FROM [dbo].[AccessItem] ai
       INNER JOIN #OrphanSubscriberGroups o ON ai.AccessKey = o.OwnerAccessKey
       INNER JOIN [dbo].[AccessMain] am ON ai.AccessKey = am.AccessKey AND am.AccessScope = 'Local'
DELETE am
  FROM [dbo].[AccessMain] am
       INNER JOIN #OrphanSubscriberGroups o ON am.AccessKey = o.OwnerAccessKey AND am.AccessScope = 'Local'
-- Now delete all the orphaned company groups themselves
DELETE gmd
  FROM [dbo].[GroupMemberDetail] gmd
       INNER JOIN #OrphanSubscriberGroups o ON gmd.GroupKey = o.GroupKey
DELETE gm
  FROM [dbo].[GroupMember] gm
       INNER JOIN #OrphanSubscriberGroups o ON gm.GroupKey = o.GroupKey
DELETE g
  FROM [dbo].[GroupMain] g
       INNER JOIN #OrphanSubscriberGroups o ON g.GroupKey = o.GroupKey
IF OBJECT_ID('tempdb..#OrphanSubscriberGroups') IS NOT NULL DROP TABLE #OrphanSubscriberGroups

-- Get all the Orphaned Opportunity Groups
IF OBJECT_ID('tempdb..#OrphanOpportunityGroups') IS NOT NULL DROP TABLE #OrphanOpportunityGroups
CREATE TABLE #OrphanOpportunityGroups (GroupKey uniqueidentifier PRIMARY KEY, AccessKey uniqueidentifier);
INSERT INTO #OrphanOpportunityGroups (GroupKey, AccessKey)
    SELECT GroupKey, AccessKey
      FROM [dbo].[GroupMain]
     WHERE [GroupTypeKey] IN (
           SELECT GroupTypeKey FROM GroupTypeRef WHERE GroupTypeName LIKE 'Opp %' AND [IsSystem] = 1 AND [IsAutoGenerated] = 1
           ) 
       AND [GroupKey] NOT IN (
           SELECT [OpportunityOwnerGroupKey] FROM [dbo].[OpportunityMain]
           UNION
           SELECT [OpportunityContactGroupKey] FROM [dbo].[OpportunityMain]
           )

SELECT @orphanGroupCount = COUNT(1) FROM #OrphanOpportunityGroups
SELECT @msg = 'Purging ' + CAST(@orphanGroupCount AS varchar(10)) + ' orphaned opportunity groups';
RAISERROR(@msg ,0, 1) WITH NOWAIT ;

-- Delete all the associated security rows now 
DELETE ai
  FROM [dbo].[AccessItem] ai
       INNER JOIN #OrphanOpportunityGroups o ON ai.AccessKey = o.AccessKey
       INNER JOIN [dbo].[AccessMain] am ON ai.AccessKey = am.AccessKey AND (am.AccessScope = 'Local' OR am.AccessScope = 'Shared')
-- Delete the AccessItem rows referencing these groups (if any... TODO: Delete opportunities referencing these security sets)
DELETE ai
  FROM [dbo].[AccessItem] ai
       INNER JOIN #OrphanOpportunityGroups o ON ai.GroupKey = o.GroupKey
       INNER JOIN [dbo].[AccessMain] am ON o.AccessKey = am.AccessKey AND (am.AccessScope = 'Local' OR am.AccessScope = 'Shared')

-- Now delete all the orphaned company groups themselves
DELETE gmd
  FROM [dbo].[GroupMemberDetail] gmd
       INNER JOIN #OrphanOpportunityGroups o ON gmd.GroupKey = o.GroupKey
DELETE gm
  FROM [dbo].[GroupMember] gm
       INNER JOIN #OrphanOpportunityGroups o ON gm.GroupKey = o.GroupKey
DELETE g
  FROM [dbo].[GroupMain] g
       INNER JOIN #OrphanOpportunityGroups o ON g.GroupKey = o.GroupKey
-- Delete task items with access settings that we're going to delete
DELETE ti
  FROM [dbo].[TaskItem] ti
       INNER JOIN #OrphanOpportunityGroups o ON ti.AccessKey = o.AccessKey
-- Delete all the AccessKey rows now
DELETE am
  FROM [dbo].[AccessMain] am
       INNER JOIN #OrphanOpportunityGroups o ON am.AccessKey = o.AccessKey AND (am.AccessScope = 'Local' OR am.AccessScope = 'Shared')
IF OBJECT_ID('tempdb..#OrphanOpportunityGroups') IS NOT NULL DROP TABLE #OrphanOpportunityGroups

-- Finally, clean up the UniformRegistry entries
DELETE ur 
  FROM UniformRegistry ur
       INNER JOIN ComponentRegistry cm ON ur.ComponentKey = cm.ComponentKey AND cm.Name = 'Group'
       LEFT OUTER JOIN [dbo].[GroupMain] g ON ur.UniformKey = g.GroupKey
 WHERE g.GroupKey IS NULL


IF OBJECT_ID('tempdb..#contactKeys') IS NOT NULL DROP TABLE #contactKeys;
IF OBJECT_ID('tempdb..#allContactKeysInUse') IS NOT NULL DROP TABLE #allContactKeysInUse;
IF OBJECT_ID('tempdb..#distinctContactKeysInUse') IS NOT NULL DROP TABLE #distinctContactKeysInUse;
IF OBJECT_ID('tempdb..#contactsToDelete') IS NOT NULL DROP TABLE #contactsToDelete;
GO

RAISERROR('Done.' ,0, 1) WITH NOWAIT ;

GO


-----------------------------------
--********************************
--Additional clean up scripts 
--********************************
-----------------------------------
DELETE FROM ChangeProperty
DELETE FROM ChangeLog
DELETE FROM workflowqueue
DELETE FROM Taskitem
DELETE FROM TaskQueuePublishDetail
DELETE FROM TaskQueueTriggerDetail
DELETE FROM TaskQueue;
DELETE FROM CommunicationLogEvent
DELETE FROM CommunicationLogRecipient
DELETE FROM ContactCommunicationReasonPreferences
DELETE FROM ContactSocialNetwork
DELETE FROM NAME_PICTURE

/*********************************
--Set manager as last updated
**********************************/
/*
UPDATE SequenceCounter SET UpdatedByUserKey = 'E982D078-994A-4BF9-B424-1010E64097D4', CreatedByUserKey = 'E982D078-994A-4BF9-B424-1010E64097D4'
UPDATE DocumentMain SET UpdatedByUserKey = 'E982D078-994A-4BF9-B424-1010E64097D4', CreatedByUserKey = 'E982D078-994A-4BF9-B424-1010E64097D4', StatusUpdatedByUserKey= 'E982D078-994A-4BF9-B424-1010E64097D4'
UPDATE CONTACTMAIN SET UpdatedByUserKey= 'E982D078-994A-4BF9-B424-1010E64097D4'
*/


-----------------------------------
--********************************
--Update Counters
--********************************
-----------------------------------
Select *
Into   #Temp
From   COUNTER
WHERE 
COUNTER_NAME NOT IN (
'NAME','Activity_Attach','Cmty_Discussion_Forums','Cmty_Discussion_Posts','Cmty_News','Cmty_Shared_Files','Cmty_Shared_Folders','Comment_Log','Community','Content_Pages','Country_Addr_Layouts','GL_Interface','HotelLog','Invoice','Invoice_Ref','Job_Record','Name_Address',
'Name_Note','Name_Picture','Orders','Product_Trans','ProductGroupTrans',
'Receipt','Receipt_ID','Ref_Client','Referral','TabProfile','Trans')
DECLARE @COUNTER_NAME NVARCHAR(50)
DECLARE @UPDATESTRING NVARCHAR(500)  

While (Select Count(*) From #Temp) > 0
Begin

    Select Top 1 @COUNTER_NAME = RTRIM(LTRIM(COUNTER_NAME)) From #Temp

	--SQL QUERY STRING 
	SET @UPDATESTRING = 'UPDATE COUNTER SET LAST_VALUE = (SELECT CASE WHEN MAX(SEQN) IS NULL THEN 1 ELSE MAX(SEQN) END FROM '+@COUNTER_NAME + ') WHERE COUNTER_NAME = ''' + @COUNTER_NAME + ''''
	PRINT @UPDATESTRING
	EXEC sp_executesql @UPDATESTRING

    Delete #Temp Where COUNTER_NAME = @COUNTER_NAME

End

DROP TABLE #TEMP


UPDATE COUNTER
SET LAST_VALUE = (SELECT MAX(CAST(ADDRESS_NUM AS INT))+1 FROM Name_Address)
WHERE COUNTER_NAME = 'NAME_ADDRESS'

UPDATE COUNTER
SET LAST_VALUE = (SELECT MAX(CAST(ID AS INT))+1 FROM NAME)
WHERE COUNTER_NAME = 'NAME'


