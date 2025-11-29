

-- view for our dataset to run our algorithms on
create view encounter_patient_info as
select 
	e."Id", 
	(e."duration_hours") as "DURATION_HOURS", 
	e."START",
	(p."Id") as "PATIENTID", 
	p."GENDER", 
	date_part('year', age(e."START"::timestamptz, p."BIRTHDATE"::date)) as "PATIENT_AGE_AT_ENCOUNTER",
	CASE 
  		WHEN EXISTS (
		    SELECT 1
		    FROM seng474_healthcare_tables.allergies a
		    WHERE a."ENCOUNTER" = e."Id"
 		)
  		THEN true
  		ELSE false
	END AS "HAD_ALLERGY",
	e."BASE_ENCOUNTER_COST", 
	(o."NAME") as "ORGNAME", 
	(o."UTILIZATION") as "ORGTRAFFIC", 
	(pr."SPECIALITY") as "ORGSPECIALITY", 
	(o."REVENUE") as "ORGREVENUE",
	o."CITY",
	e."ENCOUNTERCLASS", 
	e."DESCRIPTION", 
	e."REASONDESCRIPTION", 
	medcounts."PATIENT_MEDICATION_COUNT",
	medcosts."TOTAL_MEDICATIONS_BASE_COST",
	immunecounts."PATIENT_IMMUNIZATION_COUNT",
	proc_counts."PREVIOUS_PROCEDURE_COUNT",
	CASE 
	  	WHEN EXISTS (
		    SELECT 1
		    FROM seng474_healthcare_tables.imaging_studies i
		    WHERE i."ENCOUNTER" = e."Id"
	  	)
	  	THEN true
	  	ELSE false
	END AS "HAD_IMAGING"
from encounters as e
join patients as p
on p."Id" = e."PATIENT"
join organizations as o
on e."ORGANIZATION" = o."Id"
join providers as pr
on pr."Id" = e."PROVIDER"
-- getting med counts
LEFT JOIN (
	SELECT
    e_subm."Id" AS "ENCOUNTER_ID",
COUNT(DISTINCT m."CODE") AS "PATIENT_MEDICATION_COUNT"
FROM
    encounters e_subm
LEFT JOIN
    medications as m
    ON e_subm."PATIENT" = m."PATIENT"
-- casting both sides to timestampz
AND m."START"::timestamptz <= e_subm."START"::timestamptz
AND (
  m."STOP" IS NULL 
  OR m."STOP"::timestamptz >= e_subm."START"::timestamptz
    )
  GROUP BY
    e_subm."Id"
) medcounts
ON medcounts."ENCOUNTER_ID" = e."Id"
-- getting immunization counts
LEFT JOIN (
	SELECT
    e_subi."Id" AS "ENCOUNTER_ID",
COUNT(DISTINCT i."CODE") AS "PATIENT_IMMUNIZATION_COUNT"
FROM
    encounters e_subi
LEFT JOIN
    immunizations as i
    ON e_subi."PATIENT" = i."PATIENT"
-- casting both sides to timestampz
AND i."DATE"::timestamptz <= e_subi."START"::timestamptz
  GROUP BY
    e_subi."Id"
) immunecounts
ON immunecounts."ENCOUNTER_ID" = e."Id"
-- getting count of previous procedures a patient has had at time of current encounter
LEFT JOIN (
  SELECT
    e_sub."Id" AS "encounter_id",
    COUNT(*)   AS "PREVIOUS_PROCEDURE_COUNT"
  FROM
    seng474_healthcare_tables.encounters e_sub
  LEFT JOIN
    seng474_healthcare_tables."procedures" proc
    ON proc."PATIENT" = e_sub."PATIENT"
   AND proc."DATE"::timestamptz < e_sub."START"::timestamptz
  GROUP BY
    e_sub."Id"
) proc_counts
  ON proc_counts.encounter_id = e."Id"
-- getting the sum of base costs for a patients medications at time of encounter
LEFT JOIN (
  SELECT
    e_sub."Id" AS "encounter_id",
    SUM(m."BASE_COST") AS "TOTAL_MEDICATIONS_BASE_COST"
  FROM
    seng474_healthcare_tables.encounters e_sub
  LEFT JOIN
    seng474_healthcare_tables.medications m
    ON m."PATIENT" = e_sub."PATIENT"
   AND m."START"::timestamptz <= e_sub."START"::timestamptz
   AND (
     m."STOP" IS NULL
     OR m."STOP"::timestamptz >= e_sub."START"::timestamptz
   )
  GROUP BY
    e_sub."Id"
) medcosts
  ON medcosts.encounter_id = e."Id"
-- getting all encounter 2010 onwards
where e."START"::timestamptz 
       >= '2010-01-01T00:00:00Z'::timestamptz;



-- count of medications a patient has at time of encounter
SELECT
    e_sub."Id" AS "ENCOUNTER_ID",
COUNT(DISTINCT m."CODE") AS "PATIENT_MEDICATION_COUNT"
FROM
    encounters e_sub
LEFT JOIN
    medications m
    ON e_sub."PATIENT" = m."PATIENT"
-- cast both sides to timestamp (or timestamptz if you need timezone)
AND m."START"::timestamptz   <= e_sub."START"::timestamptz
AND (
  m."STOP" IS NULL 
  OR m."STOP"::timestamptz >= e_sub."START"::timestamptz
    )
  GROUP BY
    e_sub."Id";

