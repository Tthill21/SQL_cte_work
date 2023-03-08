-- First table
--CREATE VIEW GanttchartCreation AS 

WITH c as (
SELECT * 
FROM BatchScheduleCharacteristics
)

, b as (
SELECT * FROM BatchSchedule
)

, d as ( Select
[SupplierBatchNumber]
      ,[CustomerID]
	  ,r.Country
	  ,r.Name
      ,f.Region
      ,[MaterialID]
      ,[ScenarioID]
      ,[ContractPlannedQuantity]
      ,[ContractActualQuantity]
      ,[ContractSamplesShipped]

FROM PlanningContracts as f
LEFT JOIN Customer as r
ON f.CustomerID = r.ID 
)


, c1 as (
SELECT
ScenarioID,
SupplierID,
SupplierBatchNumber,
SAPBatchNumber,
PONumber,
DemandQtr,
--VariantID,
v.Name as VariantName,
--PresentationID,
p.Name as PresentationName,
PlannedQuantity,
ActualQuantity,
SamplesShipped,
Comments
FROM c
LEFT JOIN Variants as v ON v.ID = c.VariantID
LEFT JOIN Presentations as p ON p.ID = c.PresentationID
)

, date_setup AS (
SELECT
b.SupplierBatchNumber,
b.ScheduleType,
d.Country,
d.Region,
b.MilestoneID,
m.Name as Milestone,
b.ScenarioID,
s.Scenario,
b.StartDate,
b.EndDate,
c1.SupplierID,
c1.SAPBatchNumber,
c1.PONumber,
c1.DemandQtr,
c1.VariantName,
c1.PresentationName,
c1.PlannedQuantity,
c1.ActualQuantity,
c1.SamplesShipped,
c1.Comments,
CASE WHEN ScheduleType = 'Planned' AND MilestoneID = 1 THEN b.StartDate
	END AS POInitiateDate,
CASE WHEN ScheduleType = 'Planned' AND MilestoneID = 2 THEN b.StartDate
	END AS FillStartDate,
CASE WHEN ScheduleType = 'Planned' AND MilestoneID = 3 THEN b.StartDate
	END AS FillCompletionDate,
CASE WHEN ScheduleType = 'Planned' AND MilestoneID = 4 THEN b.StartDate
	END AS PackStartDate,
CASE WHEN ScheduleType = 'Planned' AND MilestoneID = 5 THEN b.StartDate
	END AS PackCompletionDate,
CASE WHEN ScheduleType = 'Planned' AND MilestoneID = 6 THEN b.StartDate
	END AS DispatchDate,
 CASE WHEN ScheduleType = 'Planned' AND MilestoneID = 8 THEN b.StartDate
	END AS ReleaseDate,
CASE WHEN ScheduleType = 'Planned' AND MilestoneID = 9 THEN b.StartDate
	END AS DeliveredtoCustomer
FROM b
-- keys from 'c1' should match 'b'
LEFT JOIN c1 as c1 ON b.SupplierBatchNumber = c1.SupplierBatchNumber AND b.ScenarioID = c1.ScenarioID
LEFT JOIN FPPlanningMilestones AS m ON b.MilestoneID = m.ID
LEFT JOIN FPPlanningScenarios AS s ON b.ScenarioID = s.ID
LEFT JOIN d ON b.SupplierBatchNumber = d.SupplierBatchNumber AND b.ScenarioID = d.ScenarioID 
)

, date_pivot AS (
SELECT
SupplierBatchNumber, 
Scenario,
MAX(POInitiateDate) as POInitiateDate,
MAX(FillStartDate) as FillStartDate,
MAX(FillCompletionDate) as FillCompletionDate,
MAX(PackStartDate) as PackStartDate,
MAX(PackCompletionDate) as PackCompletionDate,
MAX(DispatchDate) as DispatchDate,
MAX(ReleaseDate) as ReleaseDate,
MAX(DeliveredtoCustomer) as DeliveredtoCustomer
From date_setup
GROUP BY SupplierBatchNumber, Scenario
)


, date_calcs as (
SELECT
SupplierBatchNumber, 
Scenario,
POInitiateDate,
FillStartDate,
FillCompletionDate,
PackStartDate,
PackCompletionDate,
DispatchDate,
ReleaseDate,
DeliveredtoCustomer,
-- Do any date math here:
DATEADD(Day, 4, DispatchDate) AS UPSDate,
DATEDIFF(Day, POInitiateDate, FillStartDate) +1 AS POInitiate_toFillStart_Duration,
DATEDIFF(Day, FillStartDate, FillCompletionDate) +1 AS Fill_Duration,
DATEDIFF(Day, FillCompletionDate, PackstartDate) AS FilltoPackStart_Duration,
DATEDIFF(Day, PackStartDate, PackCompletionDate) AS Pack_Duration,
DATEDIFF(Day, PackCompletionDate, DispatchDate) AS Pack_to_Dispatch_Duration,
DATEDIFF(Day, DispatchDate, ReleaseDate) AS Dispatch_to_Release_Duration,
4 AS UPS_Duration,
DATEDIFF(Day, ReleaseDate, DeliveredtoCustomer) AS Release_to_Delivery_Duration
FROM date_pivot
)

, t1 as (
-- Final staging table with all calculated columns:
SELECT
s.SupplierBatchNumber,
s.ScheduleType,
s.Country,
s.Region,
s.MilestoneID,
s.Milestone,
s.ScenarioID,
s.Scenario,
s.StartDate,
s.EndDate,
s.SupplierID,
s.SAPBatchNumber,
s.PONumber,
s.DemandQtr,
s.VariantName,
s.PresentationName,
s.PlannedQuantity,
s.ActualQuantity,
s.SamplesShipped,
s.Comments,
-- Date columns from date_calcs
c.POInitiateDate,
c.FillStartDate,
c.FillCompletionDate,
c.PackStartDate,
c.PackCompletionDate,
c.DispatchDate,
c.ReleaseDate,
c.DeliveredtoCustomer,
c.UPSDate,
c.POInitiate_toFillStart_Duration,
c.Fill_Duration,
c.FilltoPackStart_Duration,
c.Pack_duration,
c.Pack_to_Dispatch_Duration,
c.Dispatch_to_Release_Duration,
c.UPS_Duration,
c.Release_to_Delivery_Duration

FROM date_setup as s
LEFT JOIN date_calcs as c 
ON s.SupplierBatchNumber = c.SupplierBatchNumber 
	AND s.Scenario = c.Scenario
)

Select * from t1






