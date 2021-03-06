USE [database]
GO
/****** Object:  StoredProcedure [dbo].[GetDailyTrackingData]    Script Date: 04/17/2018 09:52:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

if exists (select * from sysobjects where id = object_id(N'[dbo].[GetDailyTrackingData]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetDailyTrackingData]
GO
--test dev smtp 10.235.4.16
--Create the procedure
CREATE PROCEDURE [dbo].[GetDailyTrackingData]
AS

DECLARE
	@bDate			DATETIME,	--Universal start time
	@eDate			DATETIME,	--Universal end time
	@fileName		varchar(50),--name of the file to generate
	@path			varchar(100),--location of the file to be generated 
	@bodyMail1		varchar(max),
	@bodyMail2		varchar(max),
	@bodyMail3		varchar(max),
	@startTime		varchar(50),
	@endTime		varchar(50),
	@linesQuery		int,
	@itemsActionQuery int
	
SET NOCOUNT ON

begin try

	set @startTime = cast(GETDATE() as varchar(50)) --starting process
	--day range configuration, begin and end date
	SET @bDate = CAST(dateadd(DAY,-1,GETDATE()) AS DATE)
	set @bDate =CAST(DATEADD(MINUTE,1140,@bDate)  AS DATETIME)--this fix adds 7:00PM to begin date
	SET @eDate = CAST(DATEADD(MINUTE,1439,@bDate)  AS DATETIME)

	SET @path = 'c:\MTPayrollTracking\'
	SET @fileName =  'MTPayrollTracking' 
		+ cast(replicate('0',2-len(MONTH(GETDATE()))) as varchar(10)) + cast(MONTH(GETDATE()) as varchar(10))
		+ cast(replicate('0',2-len(DAY(GETDATE()))) as varchar(10)) + cast(DAY(GETDATE()) as varchar(10))
		+ cast(YEAR(getdate()) as varchar(10)) 
		+ '.txt'	

	declare @pathFile varchar(100)
	set @pathFile = @path + @fileName

	
	--deletes any previous version if the process must be run once again.
	declare @cmd varchar(100)--data to place in the textfile
	select	@cmd = 'del ' + @pathFile 
	exec master..xp_cmdshell @cmd
	

	--FTP DATA
	DECLARE
		@ftpSERVER VARCHAR(50),--hostname or IP of the FTP server
		@ftpUSER	VARCHAR(50),--ftp usre
		@ftpPASSWD VARCHAR(50),--ftp password
		@ftpPATH	VARCHAR(100)--ftp path "the default is / (root)"

	SET @ftpSERVER = 'MTERMINE'
	SET @ftpUSER = 'cocrftp'
	SET @ftpPASSWD = 'P@55w0rd'
	SET @ftpPATH = '/'


	--EMAIL ADDRESSES
	DECLARE 
		@MAIL1 VARCHAR(max),
		@MAIL2 VARCHAR(max)


--+++++++++++++++++email address must be changed+++++++++++++++++++++++++++++++++++++++
--EMAIL DEV SETTINGS 
	SET @MAIL1 = 'myemail@something.com' --SUCCESS MESSAGE
	SET @MAIL2 = 'myemail@something.com' --ERROR MESSAGE


	--DATA
create table #tmpSummary  (
	Department		varchar(10),
	Doctype			varchar(50),
	OperatorID		varchar(50),
	Col				varchar(10),
	dateOperation	date,
	timeItem		int
)
					
	--extracting the data of the payroll SP				
	insert into #tmpSummary
	EXEC	 [dbo].[rptPayroll]
			@bDate,
			@eDate

	select  @linesQuery = COUNT(*)  from #tmpSummary

	SELECT  @itemsActionQuery =  sum(timeItem)  
                            FROM #tmpSummary
                            where COL like '%ITEMS%'

if (@itemsActionQuery  is null) 
	set @itemsActionQuery  = 0
	
if (@linesQuery  is null) 
	set @linesQuery  = 0	

--:::::::::::::::::::::::::::::::::::WRITE FILE:::::::::::::::::::::::::::::::::::::::::::::::::::::

declare @Header varchar(max)
--set @Header =  'Dept|Part|Page|Col|Date|Data' 

if @itemsActionQuery = 0
begin
	set @Header =  ''  

	EXEC dbo.SP_WriteToFile 
		@pathFile,
		@Header
end
if @itemsActionQuery > 0
begin
	DECLARE @Text AS VARCHAR(max)

	DECLARE @Department varchar(max)
	DECLARE @Doctype varchar(max)
	DECLARE @OperatorID varchar(max)
	DECLARE @col varchar(max)
	declare @dateOperation datetime
	declare @timeItem int
	--------------------------------------------------------
	DECLARE @MyCursor CURSOR
	SET @MyCursor = CURSOR FAST_FORWARD
	FOR
	SELECT Department,Doctype,OperatorID,col,dateOperation,timeItem from #tmpsummary

	OPEN @MyCursor
	FETCH NEXT FROM @MyCursor
	INTO @Department,@Doctype,@OperatorID,@col,@dateOperation,@timeItem
	WHILE @@FETCH_STATUS = 0
	BEGIN
		set @Text =  @Department +'|' + @Doctype + '|' + @OperatorID + '|' + @col + '|' 
		+ CONVERT(VARCHAR(10), @dateOperation, 101)  
		+ '|' + cast(@timeItem as varchar(10))-- +  char(13) + char(10)
		EXEC dbo.SP_WriteToFile 
			@pathFile,
			@Text
		FETCH NEXT FROM @MyCursor
		INTO  @Department,@Doctype,@OperatorID,@col,@dateOperation,@timeItem
	END
	CLOSE @MyCursor
	DEALLOCATE @MyCursor
end

--*******************************************report part************************************************************************

	set @endTime = cast(getdate() as varchar(50))
	set @bodyMail1 = '<!DOCTYPE html> <html> <body>' +
		'<h1> Report Resume </h1></br>' +
		'<div>' +
			'<b>Process start date: </b> '+ @startTime + '</br>'+
			'<b>Process end date: </b> ' + @endTime + '</br> ' +
			'<b>Report start date: </b> '+ cast(@bDate as varchar(50)) + '</br>'+
			'<b>Report end date: </b> ' + cast(@eDate as varchar(50)) + '</br> ' +		
			'<b>Total lines in file: </b> ' + cast(@linesQuery as varchar(20)) + '</br>' +
			'<b>File name: </b>' + @fileName + '</br>' +
			'<b>Total items per action: </b>' + cast(@itemsActionQuery as varchar(20)) + '</br>' +
			'</br>' + 
		'</div>' +
		'</body> </html>'

/*	
-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>sending file to FTP<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
EXEC	[dbo].[sp_ftp_PutFile]
		@FTPServer = @ftpSERVER,--N'locottusftp9249.cloudapp.net',
		@FTPUser = @ftpUSER,--N'herlich',
		@FTPPWD = @ftpPASSWD,--N'Guatemala2017',
		@FTPPath = @ftpPATH,--N'/',
		@FTPFileName = @fileName,--N'doggy.jpg',
		@SourcePath = @path,--N'C:\MTPayrollTracking\',
		@SourceFile = @fileName,--N'doggy.jpg',
		@workdir = @path--N'C:\MTPayrollTracking\'

*/


--/////////////////////////////////////sending success email with attachment\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

	EXEC msdb.dbo.sp_send_dbmail  
		@recipients = @MAIL1,  
		@body = @bodyMail1 ,  
		@body_format = 'HTML',
		@subject = 'COCR MTPayrollTracking Automated Success Message',
		@file_attachments= @pathFile;


--delete 180 days old files
--	select	@cmd = 'forfiles -p ' + @path + ' -s -m *.* -d -180 -c "cmd /c del @file'
--	exec master..xp_cmdshell @cmd


end try

BEGIN CATCH  
	DECLARE @EMSG VARCHAR(max)
	SELECT @EMSG =  '<!DOCTYPE html> <html> <body> ' + 
	'<h1>Process failed</h1></br>' +
	'<div> </br>' + 
	'<b>This process has failed with the following error message: </b></br>' +
	cast(ERROR_MESSAGE() as varchar(max))  + '</br>' +
	'error in line of stored procedure: <b>' + 	cast(ERROR_LINE() as varchar(max))  +'</b> </br>' +
	'</div></body> </html>'


	EXEC msdb.dbo.sp_send_dbmail  
		@recipients = @MAIL1,  
		@body =     @EMSG,  
		@body_format = 'HTML',
		@subject = 'COCR MTPayrollTracking Automated Error Message' ;
		
END CATCH;   
--end of line
