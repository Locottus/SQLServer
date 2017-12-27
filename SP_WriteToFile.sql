USE [ACS_MCP3_MT]
GO

if exists (select * from sysobjects where id = object_id(N'[dbo].[SP_WriteToFile]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SP_WriteToFile]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_WriteToFile]
 
@File        VARCHAR(2000),
@Text        VARCHAR(2000)
 
AS 
 
BEGIN 
 
DECLARE @OLE            INT 
DECLARE @FileID         INT 
 
 
EXECUTE sp_OACreate 'Scripting.FileSystemObject', @OLE OUT 
       
EXECUTE sp_OAMethod @OLE, 'OpenTextFile', @FileID OUT, @File, 8, 1 
     
EXECUTE sp_OAMethod @FileID, 'WriteLine', Null, @Text
 
EXECUTE sp_OADestroy @FileID 
EXECUTE sp_OADestroy @OLE 
 
END 