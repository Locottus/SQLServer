
--for ftp using sql
EXEC sp_configure 'show advanced options', 1
GO
RECONFIGURE
GO
-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 1
GO
RECONFIGURE
GO



--for text file creation using sql
sp_configure 'show advanced options', 1; 
GO 
RECONFIGURE; 
GO 
sp_configure 'Ole Automation Procedures', 1; 
GO 
RECONFIGURE; 
GO 