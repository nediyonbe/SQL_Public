create or replace procedure INSIDESALES_WELCOME_3(giorno IN NUMBER, days_before_today_start IN NUMBER, days_before_today_end IN NUMBER) is

  daytoday NUMBER(8);
  campy NUMBER(8);
  
  campaign_id NUMBER(8);
  campaign_pc NUMBER(8);
  campaign_pc2 NUMBER(8);
  campaign_pc3 NUMBER(8);

begin
  -- in case the list had been pulled within the same day, delete those records first
  DELETE FROM IS_WELCOME
  WHERE RECORD_DATE = trunc(sysdate);
  
  SELECT CMPGN_DAY_NR 
  INTO daytoday 
  FROM CODI.DIM_MRKT_CMPGN_DAY@CDW.PROD.SAP.LNK
  WHERE CLNDR_DT_KEY = giorno;
  
  SELECT (SUBSTR(CMPGN_PERD_ID,1,4) || SUBSTR(CMPGN_PERD_ID,7, 2))
  INTO campy 
  FROM CODI.DIM_MRKT_CMPGN_DAY@CDW.PROD.SAP.LNK
  WHERE CLNDR_DT_KEY = giorno;
  
  campaign_id := get_campaign_id(campy);
  campaign_pc := get_campaign(campaign_id, -1);
  campaign_pc2 := get_campaign(campaign_id, -2);
  campaign_pc3 := get_campaign(campaign_id, -3);
  
  -- ADD your final list to the IS_CAMPAIGN table where you keep the inactive list day by day for the current and previous campaign
  -- Delete records for the 2nd last campaign and before: ather then the day after flip this will be redundant
  -- Delete records for today if any. This may happen in case the user runs the procedure twice within the same day 
  DELETE FROM IS_WELCOME
  WHERE CAMPAIGN <= campaign_pc2 
        OR (CAMPAIGN = campy AND WC = daytoday);
      
  -- drop the key as it slows down the insert
  EXECUTE IMMEDIATE 'ALTER TABLE IS_WELCOME
  DROP CONSTRAINT accw';
   
  INSERT INTO IS_WELCOME
  (   
      ACCOUNT_KEY,      
      ACCOUNT_TYPE,
      IS_ACCOUNT_NUMBER, 
      LEADERSHIP_LINEAGE,
      DIVISION,
      DISTRICT, 
      --DELIVERY_TERR_CD AS TRANSPZ,
      LOA, 
      I_S_FIRST_NAME, 
      IS_MIDDLE_NAME, 
      IS_LAST_NAME, 
      TIER, 
      TIER_KEY,
      DUNNG_LVL_KEY,
      BIRTH_DT, 
      GENDER,
      CREATED_ON,
      LEGAL_AGREEMENT_DT, 
      APPOINTMENT_DT, 
      APPOINTMENT_CAMPAIGN, 
      REMOVAL_CAMPAIGN, 
      REINSTATEMENT_CAMPAIGN,
      HOME_ADDRESS1, 
      DEL_ADDRESS1,
      HOME_CITY, 
      HOME_POSTAL_CODE, 
      HOME_PROVINCE,
      DEL_CITY, 
      DEL_PROVINCE, 
      DEL_POSTAL_CODE,
      EMAIL, 
      LANGUAGE, 
      STATUS, 
      STATUS_CODE,
      DAYTIME_PHONE, 
      EVENING_PHONE, 
      MOBILE_PHONE, 
      TIME_ZONE_TXT,
      UPLINE_ACCOUNT_NUMBER,
      WC,
      INITIATIVE,
      RECORD_DATE,
      CAMPAIGN
  )
  SELECT ACCOUNT_KEY,
        ACCOUNT_TYPE,
        ACCOUNT_NUMBER AS IS_ACCOUNT_NUMBER, 
        0 AS LEADERSHIP_LINEAGE, 
        z.DESCRIPTION AS DISTRICT,
        z.PARENT_ID AS DIVISION,
        --DELIVERY_TERR_CD AS TRANSPZ,
        LOA, 
        NAME_FIRST AS I_S_FIRST_NAME, NAME_MIDDLE AS IS_MIDDLE_NAME, NAME_LAST AS IS_LAST_NAME, 
        TIER, TIER_KEY,
        DUNNG_LVL_KEY,
        BIRTH_DT, GENDER,
        CREATED_ON,
        LEGAL_AGREEMENT_DT, APPOINTMENT_DT, 
        APPOINTMENT_CAMPAIGN, REMOVAL_CAMPAIGN, REINSTATEMENT_CAMPAIGN,
        HOME_ADDRESS1, DEL_ADDRESS1,
        HOME_CITY, HOME_POSTAL_CODE, HOME_PROVINCE,
        DEL_CITY, DEL_PROVINCE, DEL_POSTAL_CODE,
        EMAIL, LANGUAGE, STATUS, STATUS_CODE,
        DAYTIME_PHONE, EVENING_PHONE, MOBILE_PHONE, 
        TIME_ZONE_TXT,
        UPLINE_ACCOUNT_NUMBER,
        daytoday AS WC,
        'Welcome' AS INITIATIVE,
        trunc(sysdate) AS RECORD_DATE,
        campy AS CAMPAIGN
  FROM cdw_rep@sre_prod.lnk c
  LEFT JOIN FIELD_ASSIGNMENTS@SRE_PROD.LNK z
  ON CHANNEL = z.ID
  WHERE c.CREATED_ON >= SYSDATE - 6 
        AND c.CREATED_ON <= SYSDATE - 4 -- Gives the people who signed up 5, 6, 7 days before: Changedupon Cindy's email on Sep 28 2018
        AND c.ACCOUNT_NUMBER > 500
        AND c.ACCOUNT_TYPE = 'Representative'
  ORDER BY STATUS, CREATED_ON DESC;
 
  -- re-add the key as it is necessary for the join below
  EXECUTE IMMEDIATE 'ALTER TABLE is_welcome
  ADD CONSTRAINT accw PRIMARY KEY(ACCOUNT_KEY, WC, CAMPAIGN)';
  
  -- language abreviations cause error at hubspot. Update with its full name
  UPDATE IS_WELCOME
  SET LANGUAGE =
    CASE
      WHEN LANGUAGE = 'EN' THEN 'ENGLISH'
        WHEN LANGUAGE = 'FR' THEN 'FRENCH'
    END;
    
  -- Delete records within this campaign and the previous one. you will repull data as it can change everyday. People may have placed new orders. Objective is not only to identify actives but also by how much QV they have become active
  DELETE FROM IS_ALL
  WHERE CAMPAIGN > campaign_pc2 
        AND INITIATIVE = 'Welcome'; 
  -- The IS_CAMPAIGN table has only the last 2C's inactives. Bring their QVs
  INSERT INTO IS_ALL
    (ACCOUNT_KEY, 
    ACCOUNT_NUMBER,
    CAMPAIGN,
    QV,
    QV_NEXT,
    INITIATIVE)
  SELECT i.ACCOUNT_KEY, i.ACCOUNT_NUMBER, i.CAMPAIGN, 
         nvl(c.awrd_sls_amt, 0) QV,
         nvl(c_next.awrd_sls_amt, 0) QV_NEXT,
         i.INITIATIVE
  FROM
    (SELECT DISTINCT ACCOUNT_KEY, IS_ACCOUNT_NUMBER AS ACCOUNT_NUMBER, CAMPAIGN, INITIATIVE
    FROM IS_WELCOME) i
  LEFT JOIN cdw.sum_mrkt_acct_sls@cdw.prod.sap.lnk c
       ON i.ACCOUNT_KEY = c.ACCT_KEY
          AND i.CAMPAIGN = to_number(substr(c.fld_sls_cmpgn_perd_id,1,4) || substr(c.fld_sls_cmpgn_perd_id,7,2))
          AND c.mrkt_id = 34
  LEFT JOIN cdw.sum_mrkt_acct_sls@cdw.prod.sap.lnk c_next
       ON i.ACCOUNT_KEY = c_next.ACCT_KEY
          AND get_campaign(get_campaign_id(i.CAMPAIGN), 1) = to_number(substr(c_next.fld_sls_cmpgn_perd_id,1,4) || substr(c_next.fld_sls_cmpgn_perd_id,7,2))
          AND c_next.mrkt_id = 34;
  

end INSIDESALES_WELCOME_3;
