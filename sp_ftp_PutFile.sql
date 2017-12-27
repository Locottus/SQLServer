USE [ACS_MCP3_MT]
GO

if exists (select * from sysobjects where id = object_id(N'[dbo].[sp_ftp_PutFile]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_ftp_PutFile]
GO

/*
--example of use
DECLARE	@return_value int

EXEC	@return_value = [dbo].[s_ftp_PutFile]
		@FTPServer = N'<ftpserver>',
		@FTPUser = N'<user>',
		@FTPPWD = N'<password>',
		@FTPPath = N'/',
		@FTPFileName = N'doggy.jpg',
		@SourcePath = N'C:\MTPayrollTracking\',
		@SourceFile = N'doggy.jpg',
		@workdir = N'C:\MTPayrollTracking\'

SELECT	'Return Value' = @return_value

GO
*/

Create procedure sp_ftp_PutFile
@FTPServer	varchar(128) ,
@FTPUser	varchar(128) ,
@FTPPWD		varchar(128) ,
@FTPPath	varchar(128) ,
@FTPFileName	varchar(128) ,

@SourcePath	varchar(128) ,
@SourceFile	varchar(128) ,

@workdir	varchar(128)
as
declare	@cmd varchar(1000)
declare @workfilename varchar(128)
	
	select @workfilename = 'ftpcmd.txt'
	
	-- deal with special characters for echo commands
	select @FTPServer = replace(replace(replace(@FTPServer, '|', '^|'),'<','^<'),'>','^>')
	select @FTPUser = replace(replace(replace(@FTPUser, '|', '^|'),'<','^<'),'>','^>')
	select @FTPPWD = replace(replace(replace(@FTPPWD, '|', '^|'),'<','^<'),'>','^>')
	select @FTPPath = replace(replace(replace(@FTPPath, '|', '^|'),'<','^<'),'>','^>')
	
	select	@cmd = 'echo '					+ 'open ' + @FTPServer
			+ ' > ' + @workdir + @workfilename
	exec master..xp_cmdshell @cmd
	select	@cmd = 'echo '					+ @FTPUser
			+ '>> ' + @workdir + @workfilename
	exec master..xp_cmdshell @cmd
	select	@cmd = 'echo '					+ @FTPPWD
			+ '>> ' + @workdir + @workfilename
	exec master..xp_cmdshell @cmd
	select	@cmd = 'echo '					+ 'put ' + @SourcePath + @SourceFile + ' ' + @FTPPath + @FTPFileName
			+ ' >> ' + @workdir + @workfilename
	exec master..xp_cmdshell @cmd
	select	@cmd = 'echo '					+ 'quit'
			+ ' >> ' + @workdir + @workfilename
	exec master..xp_cmdshell @cmd
	
	select @cmd = 'ftp -s:' + @workdir + @workfilename
	
	create table #a (id int identity(1,1), s varchar(1000))
	insert #a
	exec master..xp_cmdshell @cmd
	
	select id, ouputtmp = s from #a
go

