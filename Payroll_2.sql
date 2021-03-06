USE [ACS_MCP3_MT]
GO
/****** Object:  StoredProcedure [dbo].[rptPayroll]    Script Date: 4/17/2017 11:27:47 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

if exists (select * from sysobjects where id = object_id(N'[dbo].[rptPayroll]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[rptPayroll]
GO

--Create the procedure
create PROCEDURE [dbo].[rptPayroll]
	@BeginDate	DATETIME,		--Date from which to begin looking at Items
	@EndDate	DATETIME

AS

--Local variables
DECLARE
	@dstOffset		bigint,		--Minutes from local time to Universal
	@bDate			DATETIME,	--Universal start time
	@eDate			DATETIME	--Universal end time
	
	

SET NOCOUNT ON


SET @bDate = CAST(@BeginDate AS DATE)
SET @eDate = @EndDate



create table #tmpSummary  (
	Department		varchar(10),
	Doctype			varchar(50),
	OperatorID		varchar(50),
	Col				varchar(10),
	dateOperation	date,
	timeItem		int
)

create table #tmpSummary2  (
	Department		varchar(10),
	Doctype			varchar(50),
	OperatorID		varchar(50),
	Col				varchar(10),
	dateOperation	date,
	timeItem		int,
	idOrderOutput	int
)

create table #tmpSummary3  (
	id_num int IDENTITY(1,1), 
	Department		varchar(10),
	Doctype			varchar(50),
	OperatorID		varchar(50),
	Col				varchar(10),
	dateOperation	date,
	timeItem		int
	
)


declare @ActionList Table (
	WorkflowID varchar(50),
	ActionID varchar(50),
	ActionName varchar(50)
)

insert into @ActionList (WorkflowID,ActionID,ActionName)
select distinct WorkflowID,ActionID,ActionName
from vrptWorkflowAction (nolock)
where ActionID in (419324019,419324023,419324054,419324025)
/*
419324019	Char Repair
419324023	Field Repair
419324054	QI Verify
419324025	Verify
*/


DECLARE @Workflow TABLE (
	workflowId		varchar(50),
	workflowName	varchar(50),	
	closedInProdActionID varchar(50),
	priority		int
)


insert into @Workflow(workflowId,WorkflowName,closedInProdActionID,priority)
SELECT WorkflowID,WorkflowName,ClosedInProdActionID,CASE WHEN WorkflowName ='claim' then 1 else 2 end
	FROM vrptWorkflow (nolock)



--non batch
insert into #tmpSummary (Department,Doctype,OperatorID,dateOperation,timeItem) 
SELECT 'COCR',b1.Task,b1.Operator
	,CONVERT(VARCHAR(10), b1.EventDateTime, 101) as dateOutput
	,abs(DATEDIFF( SECOND, b1.EventDateTime, b2.EventDateTime)) as timeOutput
FROM WebDELogs.DBO.WebDEEvent b1
	inner join WebDELogs.DBO.WebDEEvent b2 on b1.BatchIdentifier = b2.BatchIdentifier
where b1.eventtype like '%DocumentBegin%'
	--and b2.eventtype  like '%Document%'
	and b1.EventType <> b2.EventType
	and b1.EventId <> b2.EventId
	and b1.DocIdentifier = b2.DocIdentifier
	and b1.Task = b2.Task
	and b1.Operator = b2.Operator
	and b1.Correlator = b2.Correlator
	and CONVERT(VARCHAR(10), b1.EventDateTime, 101) = CONVERT(VARCHAR(10), b2.EventDateTime, 101)
	and abs(DATEDIFF( SECOND, b1.EventDateTime, b2.EventDateTime)) > 0
	and cast(b1.EventDateTime as datetime) between cast(@bDate as datetime) and cast(@eDate as datetime)
order by dateOutput

--batch 
insert into #tmpSummary (Department,Doctype,OperatorID,dateOperation,timeItem)
SELECT 'COCR',b1.Task,b1.Operator
	,CONVERT(VARCHAR(10), b1.EventDateTime, 101) as dateOutput
	,abs(DATEDIFF( SECOND, b1.EventDateTime, b2.EventDateTime)) as timeOutput
FROM WebDELogs.DBO.WebDEEvent b1
	inner join WebDELogs.DBO.WebDEEvent b2 on b1.BatchIdentifier = b2.BatchIdentifier
where b1.eventtype like '%BatchBegin%'
	and b2.eventtype  like '%BatchEnd%'
	and b1.EventId <> b2.EventId
	and b1.Task = b2.Task
	and b1.Operator = b2.Operator
	and b1.Correlator = b2.Correlator
	and CONVERT(VARCHAR(10), b1.EventDateTime, 101) = CONVERT(VARCHAR(10), b2.EventDateTime, 101)
	and abs(DATEDIFF( SECOND, b1.EventDateTime, b2.EventDateTime)) > 0
	and cast(b1.EventDateTime as datetime) between cast(@bDate as datetime) and cast(@eDate as datetime)
order by dateOutput


insert #tmpSummary2(Department,Doctype,OperatorID,col,dateOperation,timeItem,idOrderOutput)
select Department,Doctype,OperatorID,'ITEMS',dateOperation,COUNT(*),'1' --items
	from #tmpSummary
	--where timeItem > 0
	group by Department,Doctype,OperatorID,col,dateOperation
union
select Department,Doctype,OperatorID,'TIME',dateOperation,sum(timeItem),'2' --time
	from #tmpSummary
	--where timeItem > 0
	group by Department,Doctype,OperatorID,col,dateOperation
union

--select 'COCR' as 'Department', a.ActionName as 'Doctype', per.LoginCode as 'Operator','Idle' as 'Col', 
select 'COCR' as 'Department', 'Idle' as 'Doctype', per.LoginCode as 'Operator','TIME' as 'Col', 
CONVERT(VARCHAR(10), procdate, 101) as 'dateOperation',
SUM( datediff(s,mgettime,mgetputtime)) as 'timeItem','0' as 'idOrderOutput'
FROM vrItemActionLog ICH
	--Include the MultiGet name
	INNER JOIN vrptMultiGetName MG ON MG.MGetID = ICH.MGetID
	INNER JOIN vrptWorkflowAction A ON A.ActionID = ICH.ActionID
				AND A.WorkflowID IN (SELECT workflowId FROM @Workflow)	
				and A.ActionID in (select ActionID from @ActionList)
	INNER JOIN ACS_GLOBAL.dbo.vaPerson Per on per.PersonID = ich.PersonID
where cast(ICH.LocalProcDate as datetime) between cast(@bDate as dateTIME) and cast(@eDate as datetime)
GROUP BY per.LoginCode, a.ActionName, ICH.ITypeID, MG.MGetName	,CONVERT(VARCHAR(10), procdate, 101)


/*
select Department,Doctype,OperatorID,col,
CONVERT(VARCHAR(10), dateOperation, 101) as 'dateOperation',timeItem
	from #tmpSummary2
	--where idOrderOutput <> 0
	order by Doctype,OperatorID,dateOperation,idOrderOutput	*/



insert #tmpSummary3(Department,Doctype,OperatorID,col,dateOperation,timeItem)
select Department,Doctype,OperatorID,col,
CONVERT(VARCHAR(10), dateOperation, 101) as 'dateOperation',timeItem
	from #tmpSummary2
	where idOrderOutput = 0
	order by Doctype,OperatorID,dateOperation,idOrderOutput
--union
insert #tmpSummary3(Department,Doctype,OperatorID,col,dateOperation,timeItem)
select Department,Doctype,OperatorID,col,
CONVERT(VARCHAR(10), dateOperation, 101) as 'dateOperation',timeItem
	from #tmpSummary2
	where idOrderOutput <> 0
	order by Doctype,OperatorID,dateOperation,idOrderOutput

select Department,Doctype,OperatorID,Col,dateOperation,timeItem
from #tmpSummary3
order by id_num

--drop tables
drop table #tmpSummary
drop table #tmpSummary2
drop table #tmpSummary3