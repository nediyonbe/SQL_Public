create or replace procedure INSIDESALES_5(giorno IN NUMBER) is
       campy NUMBER(8);
       campaign_id NUMBER(8);
       campaign_pc NUMBER(8);
       campaign_pc2 NUMBER(8);
       campaign_pc3 NUMBER(8);
       campaign_pc4 NUMBER(8);
       campaign_pc5 NUMBER(8);
       campaign_pc9 NUMBER(8);
       campaign_pc26 NUMBER(8);
       campaign_nxt NUMBER(8);
       daytoday NUMBER(8); -- day of campaign

begin
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
      campaign_pc4 := get_campaign(campaign_id, -4);
      campaign_pc5 := get_campaign(campaign_id, -5);
      campaign_pc9 := get_campaign(campaign_id, -9);
      campaign_pc26 := get_campaign(campaign_id, -26);
      campaign_nxt := get_campaign(campaign_id, 1);

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS0';

      INSERT INTO IS0
      SELECT ACCT_KEY AS ACCOUNT_KEY,
           UPLN_ACCT_KEY AS UPLINE_ACCOUNT_KEY,
          cmp.inactv_cmpgn_cnt inactive_campaigns,
          nvl(cmp.awrd_sls_amt, 0) QV,
          nvl(cmp.sbmtd_awrd_sls_amt, 0) Potential_QV,
          nvl(cmp.ctd_awrd_sls_amt, 0) CTD_QV,
          nvl(cmp.prev_ctd_awrd_sls_amt , 0) PY_CTD_QV,
          nvl(cmp.rturn_awrd_sls_amt, 0) Return_QV,
          nvl(cmp.sbmtd_rturn_awrd_sls_amt, 0) Potential_Return_QV,
          nvl(cmp.avlbl_crdt_amt, 0) Available_Credit
      FROM  cdw.sum_mrkt_acct_sls@cdw.prod.sap.lnk cmp
      WHERE (cmp.inactv_cmpgn_cnt BETWEEN 7 AND 25 
            OR cmp.inactv_cmpgn_cnt IS NULL 
            OR cmp.inactv_cmpgn_cnt BETWEEN 2 AND 4 
            OR cmp.inactv_cmpgn_cnt = 0)
          AND cmp.mrkt_id = 34
          AND (cmp.awrd_sls_amt <= 0 OR cmp.awrd_sls_amt IS NULL)
          AND to_number(substr(cmp.fld_sls_cmpgn_perd_id,1,4) || substr(cmp.fld_sls_cmpgn_perd_id,7,2)) =  campy ;
      
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS1';
      INSERT INTO IS1
      SELECT i0.*,
             c.ACCOUNT_TYPE,
             c.ACCOUNT_NUMBER,
             c.DISTRICT_NO AS DISTRICT,
             c.DELIVERY_TERR_CD AS TRANSPZ,
             c.LOA,
             c.NAME_FIRST, c.NAME_MIDDLE, c.NAME_LAST,
             c.TIER, c.TIER_KEY,
             c.DUNNG_LVL_KEY,
             c.BIRTH_DT, c.GENDER,
             c.LEGAL_AGREEMENT_DT, c.APPOINTMENT_DT,
             c.APPOINTMENT_CAMPAIGN, c.REMOVAL_CAMPAIGN, c.REINSTATEMENT_CAMPAIGN,
             c.HOME_ADDRESS1, c.DEL_ADDRESS1,
             c.HOME_CITY, c.HOME_POSTAL_CODE, c.HOME_PROVINCE,
             c.DEL_CITY, c.DEL_PROVINCE, c.DEL_POSTAL_CODE,
             c.EMAIL, c.LANGUAGE, c.STATUS, c.STATUS_CODE,
             c.DAYTIME_PHONE, c.EVENING_PHONE, c.MOBILE_PHONE,
             c.TIME_ZONE_TXT,
             c.UPLINE_ACCOUNT_NUMBER
      FROM IS0 i0
      LEFT JOIN cdw_rep@sre_prod.lnk c
      ON c.ACCOUNT_KEY = i0.ACCOUNT_KEY
      WHERE c.ACCOUNT_NUMBER > 500
            AND c.ACCOUNT_TYPE = 'Representative'
            AND c.STATUS NOT IN ('Removed', 'Restricted');

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS0';

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS_Deliveries';
      INSERT INTO IS_Deliveries
      SELECT DISTRICT, TRANSPZ, SCHED_SBMT_DT, ALT_SBMT_DT,
             YYYYCC AS CAMPAIGN
      FROM TRANSPORT_MANAGEMENT_TOOL@SRE_PROD.LNK
      WHERE YYYYCC = campy;

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS2';
      INSERT INTO IS2
      SELECT uffa.*,
             DIVS.DIVISION_NAME AS DIVISION,
             DUNN.DUNNG_LVL_CD, DUNN.DUNNG_LVL_DESC_TXT
      FROM
      (SELECT i1.*,
             d.SCHED_SBMT_DT, d.ALT_SBMT_DT, campy AS CAMPAIGN
      FROM IS1 i1
      LEFT JOIN IS_Deliveries d
      ON i1.DISTRICT = d.DISTRICT
         AND i1.TRANSPZ = d.TRANSPZ) uffa
      LEFT JOIN (SELECT DIVISION_NAME, DISTRICT_NUMBER
                FROM IS_DIV_DIS) DIVS
      ON uffa.district = DIVS.DISTRICT_NUMBER
      LEFT JOIN (SELECT DUNNG_LVL_KEY, DUNNG_LVL_CD, DUNNG_LVL_DESC_TXT
                FROM CDW_DIM_DUNNG_LVL@sre_prod.lnk) DUNN
      ON uffa.dunng_lvl_key = DUNN.DUNNG_LVL_KEY;

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS1';

-- BRING DRAFT QV - NOTE THAT THIS BRINGS DRAFT QV FROM BOTH CURRENT AND NEXT CAMPAIGNS
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS_CurrentCampB';
      INSERT INTO IS_CurrentCampB
      select to_number(substr(draft.fld_sls_cmpgn_perd_id,1,4) || substr(draft.fld_sls_cmpgn_perd_id,7,2)) yyyycc,
            draft.acct_key,
            sum(draft.ord_amt) draft_qv
      from cdw.fact_ord_hdr@cdw.prod.sap.lnk draft
      where mrkt_id = 34
       and draft.ord_amt <> 0
       and to_number(substr(draft.fld_sls_cmpgn_perd_id,1,4) || substr(draft.fld_sls_cmpgn_perd_id,7,2)) >= campaign_pc 
      group by draft.fld_sls_cmpgn_perd_id, draft.acct_key;

-- JOIN FIRST SET OF TABLES
-- BRING COMMUNICATION PREFERENCES
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS3';
      INSERT INTO IS3
      SELECT i2.*,
             order_block, -- 01 or any other NON NULL means there is order block
             decode(nvl(tag.sap_trmeco_sms, '{NULL}'), 'X', 1, 0) allow_dsm_sms,
             decode(nvl(tag.sap_trmeco_email, '{NULL}'), 'X', 1, 0) allow_dsm_email,
             decode(nvl(tag.sap_trmeco_phone, '{NULL}'), 'X', 1, 0) allow_dsm_phone,
             decode(nvl(tag.sap_prminc_email, '{NULL}'), 'X', 1, 0) allow_promoinc_email
      FROM IS2 i2
      LEFT JOIN consent_tag@sre_prod.lnk tag
      ON i2.ACCOUNT_NUMBER = tag.account_number;

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS2';

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS5';
      INSERT INTO IS5
              (ACCOUNT_KEY, UPLINE_ACCOUNT_KEY, INACTIVE_CAMPAIGNS, QV, POTENTIAL_QV, CTD_QV, PY_CTD_QV, RETURN_QV, POTENTIAL_RETURN_QV,
              AVAILABLE_CREDIT, ACCOUNT_TYPE, ACCOUNT_NUMBER, DISTRICT, TRANSPZ, LOA, NAME_FIRST, NAME_MIDDLE, NAME_LAST, TIER, TIER_KEY,
              DUNNG_LVL_KEY, BIRTH_DT, GENDER, LEGAL_AGREEMENT_DT, APPOINTMENT_DT, APPOINTMENT_CAMPAIGN, REMOVAL_CAMPAIGN, REINSTATEMENT_CAMPAIGN,
              HOME_ADDRESS1, DEL_ADDRESS1, HOME_CITY, HOME_POSTAL_CODE, HOME_PROVINCE, DEL_CITY, DEL_PROVINCE, DEL_POSTAL_CODE, EMAIL, LANGUAGE,
              STATUS, STATUS_CODE, DAYTIME_PHONE, EVENING_PHONE, MOBILE_PHONE, TIME_ZONE_TXT, UPLINE_ACCOUNT_NUMBER, SCHED_SBMT_DT, ALT_SBMT_DT,
              CAMPAIGN, DIVISION, DUNNG_LVL_CD, DUNNG_LVL_DESC_TXT, ORDER_BLOCK, ALLOW_DSM_SMS, ALLOW_DSM_EMAIL, ALLOW_DSM_PHONE,
              ALLOW_PROMOINC_EMAIL, DRAFT_QV, DRAFT_QV_NEXT, DRAFT_QV_PC)
      SELECT i3.*,
             CB.draft_qv AS DRAFT_QV,
             CB_NEXT.draft_qv AS DRAFT_QV_NEXT,
             CB_PC.draft_qv AS DRAFT_QV_PC
      FROM IS3 i3
      LEFT JOIN (SELECT ACCT_KEY, YYYYCC, draft_qv
                 FROM IS_CurrentCampB
                 WHERE YYYYCC = campy
                 ) CB
      ON i3.ACCOUNT_KEY = CB.ACCT_KEY
      LEFT JOIN (SELECT ACCT_KEY, YYYYCC, draft_qv
                 FROM IS_CurrentCampB
                 WHERE YYYYCC = campaign_nxt
                 ) CB_NEXT
      ON i3.ACCOUNT_KEY = CB_NEXT.ACCT_KEY
      LEFT JOIN (SELECT ACCT_KEY, YYYYCC, draft_qv
                 FROM IS_CurrentCampB
                 WHERE YYYYCC = campaign_pc
                 ) CB_PC
      ON i3.ACCOUNT_KEY = CB_PC.ACCT_KEY;

      UPDATE IS5
      SET CAMPAIGN_PRIOR1 = campaign_pc,
      CAMPAIGN_PRIOR2 = campaign_pc2,
      CAMPAIGN_PRIOR3 = campaign_pc3,
      CAMPAIGN_PRIOR4 = campaign_pc4,
      CAMPAIGN_PRIOR5 = campaign_pc5;

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS3';
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS_CurrentCampB';

-- BRING PAST CAMPAIGN DATA: IT IS OK TO EXCLUDE PENDING REPS AS THEY WON'T HAVE HISTORY
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS6';
      INSERT INTO IS6
      SELECT i5.*,
             f.QV AS QV_PRIOR1,
             f2.QV AS QV_PRIOR2,
             f3.QV AS QV_PRIOR3,
             f4.QV AS QV_PRIOR4,
             f5.QV AS QV_PRIOR5
      FROM IS5 i5
      LEFT JOIN (SELECT ACCOUNT_KEY, QV
                FROM cdw_campaign@sre_prod.lnk
                WHERE YYYYCC = campaign_pc) f
      ON i5.ACCOUNT_KEY = f.ACCOUNT_KEY
      LEFT JOIN (SELECT ACCOUNT_KEY, QV
                FROM cdw_campaign@sre_prod.lnk
                WHERE YYYYCC = campaign_pc2) f2
      ON i5.ACCOUNT_KEY = f2.ACCOUNT_KEY
      LEFT JOIN (SELECT ACCOUNT_KEY, QV
                FROM cdw_campaign@sre_prod.lnk
                WHERE YYYYCC = campaign_pc3) f3
      ON i5.ACCOUNT_KEY = f3.ACCOUNT_KEY
      LEFT JOIN (SELECT ACCOUNT_KEY, QV
                FROM cdw_campaign@sre_prod.lnk
                WHERE YYYYCC = campaign_pc4) f4
      ON i5.ACCOUNT_KEY = f4.ACCOUNT_KEY
      LEFT JOIN (SELECT ACCOUNT_KEY, QV
                FROM cdw_campaign@sre_prod.lnk
                WHERE YYYYCC = campaign_pc5) f5
      ON i5.ACCOUNT_KEY = f5.ACCOUNT_KEY;

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS5';

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS7';
      INSERT INTO IS7
      SELECT i6.*,
             Amt26Camp.QV_26CampSum,
             Amt9Camp.QV_9CampSum,
             ActiveCount26Camp.Active_26Camp,
             ActiveCount9Camp.Active_9Camp,
             0 AS AVG_ORDER_26C, -- insert 0 to whole filed. It will be calculated further below
             0 AS AVG_ORDER_9C -- insert 0 to whole filed. It will be calculated further below
      FROM IS6 i6
      -- Total order amount of Campaigns Rep was active within the past 26 campaigns
      LEFT JOIN (SELECT ACCOUNT_KEY, SUM(QV) AS QV_26CampSum
                 FROM cdw_campaign@sre_prod.lnk
                 WHERE YYYYCC BETWEEN campaign_pc26 AND campaign_pc
                 GROUP BY ACCOUNT_KEY) Amt26Camp
      ON i6.ACCOUNT_KEY = Amt26Camp.ACCOUNT_KEY
      -- Total order amount of Campaigns Rep was active within the past 9 campaigns
      LEFT JOIN (SELECT ACCOUNT_KEY, SUM(QV) AS QV_9CampSum
                 FROM cdw_campaign@sre_prod.lnk
                 WHERE YYYYCC BETWEEN campaign_pc9 AND campaign_pc
                 GROUP BY ACCOUNT_KEY) Amt9Camp
      ON i6.ACCOUNT_KEY = Amt9Camp.ACCOUNT_KEY
      -- Number of Campaigns Rep was active within the past 26 campaigns
      LEFT JOIN (SELECT ACCOUNT_KEY, COUNT(*) AS Active_26Camp
                 FROM cdw_campaign@sre_prod.lnk
                 WHERE QV > 0
                       AND YYYYCC BETWEEN campaign_pc26 AND campaign_pc
                 GROUP BY ACCOUNT_KEY) ActiveCount26Camp
      ON i6.ACCOUNT_KEY = ActiveCount26Camp.ACCOUNT_KEY
      -- Number of Campaigns Rep was active within the past 9 campaigns
      LEFT JOIN (SELECT ACCOUNT_KEY, COUNT(*) AS Active_9Camp
                 FROM cdw_campaign@sre_prod.lnk
                 WHERE QV > 0
                       AND YYYYCC BETWEEN campaign_pc9 AND campaign_pc
                 GROUP BY ACCOUNT_KEY) ActiveCount9Camp
      ON i6.ACCOUNT_KEY = ActiveCount9Camp.ACCOUNT_KEY
      ORDER BY i6.ACCOUNT_KEY;

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS6';

      --Replace NULLs with 0 to avoid messing up average calculations
      UPDATE IS7
            SET QV_26CampSum = 0
            WHERE QV_26CampSum IS NULL;

      UPDATE IS7
            SET QV_9CampSum = 0
            WHERE QV_9CampSum IS NULL;

      UPDATE IS7
            SET Active_26Camp = 0
            WHERE Active_26Camp IS NULL;

      UPDATE IS7
            SET Active_9Camp = 0
            WHERE Active_9Camp IS NULL;

      UPDATE IS7
            SET AVG_ORDER_26C =
                CASE
                  WHEN Active_26Camp > 0 THEN QV_26CampSum / Active_26Camp
                    ELSE 0
                      END;

      UPDATE IS7
            SET AVG_ORDER_9C =
                CASE
                  WHEN Active_9Camp > 0 THEN QV_9CampSum / Active_9Camp
                    ELSE 0
                      END;

-- BRING BROCHURE SALES DATA 
/*This section is omitted. In the future it may be necessary again. The required tables are kept
Should the info is required again, past versions have the necessary code --*/
/*      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS_BrochureSales1';
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS_BrochureSales2';
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS_BrochureSales1';
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS_BrochureSales2_FREE';
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS_BrochureSales2_PAID';
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS_BrochureSales2';*/
      
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS8';
      INSERT INTO IS8
      SELECT   i7.*,
               b.BROCHURE_UNIT AS PAID_BROCHURE_CURRENT_CAMP
      FROM IS7 i7
      LEFT JOIN IS_BrochureSales2_PAID b
      ON b.ACCT_NR = i7.ACCOUNT_NUMBER
         AND i7.CAMPAIGN = b.BROCHURE_CAMPAIGN;

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS7';

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS9';
      INSERT INTO IS9
      SELECT i8.*, b.BROCHURE_UNIT AS PAID_BROCHURE_NEXT_CAMP
      FROM IS8 i8
      LEFT JOIN (SELECT ACCT_NR, BROCHURE_UNIT, BROCHURE_CAMPAIGN
                FROM IS_BrochureSales2_PAID
                WHERE BROCHURE_CAMPAIGN = campaign_nxt
                ) b
      ON b.ACCT_NR = i8.ACCOUNT_NUMBER;

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS8';
      
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS10';
      INSERT INTO IS10
      SELECT i9.*, b.BROCHURE_UNIT AS FREE_BROCHURE_CURRENT_CAMP
      FROM IS9 i9
      LEFT JOIN IS_BrochureSales2_FREE b
      ON b.ACCT_NR = i9.ACCOUNT_NUMBER
         AND i9.CAMPAIGN = b.BROCHURE_CAMPAIGN;

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS9';

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS11';

      INSERT INTO IS11
      (
        ACCOUNT_KEY,
        UPLINE_ACCOUNT_KEY,
        INACTIVE_CAMPAIGNS,
        QV,
        POTENTIAL_QV,
        CTD_QV,
        PY_CTD_QV,
        RETURN_QV,
        POTENTIAL_RETURN_QV,
        AVAILABLE_CREDIT,
        ACCOUNT_TYPE,
        ACCOUNT_NUMBER,
        DISTRICT,
        TRANSPZ,
        LOA,
        NAME_FIRST,
        NAME_MIDDLE,
        NAME_LAST,
        TIER,
        TIER_KEY,
        DUNNG_LVL_KEY,
        BIRTH_DT,
        GENDER,
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
        SCHED_SBMT_DT,
        ALT_SBMT_DT,
        CAMPAIGN,
        DIVISION,
        DUNNG_LVL_CD,
        DUNNG_LVL_DESC_TXT,
        ORDER_BLOCK,
        ALLOW_DSM_SMS,
        ALLOW_DSM_EMAIL,
        ALLOW_DSM_PHONE,
        ALLOW_PROMOINC_EMAIL,
        DRAFT_QV,
        DRAFT_QV_NEXT,
        DRAFT_QV_PC,
        CAMPAIGN_PRIOR1,
        CAMPAIGN_PRIOR2,
        CAMPAIGN_PRIOR3,
        CAMPAIGN_PRIOR4,
        CAMPAIGN_PRIOR5,
        QV_PRIOR1,
        QV_PRIOR2,
        QV_PRIOR3,
        QV_PRIOR4,
        QV_PRIOR5,
        QV_26CAMPSUM,
        QV_9CAMPSUM,
        ACTIVE_26CAMP,
        ACTIVE_9CAMP,
        AVG_ORDER_26C,
        AVG_ORDER_9C,
        PAID_BROCHURE_CURRENT_CAMP,
        PAID_BROCHURE_NEXT_CAMP,
        FREE_BROCHURE_CURRENT_CAMP,
        DAY_OF_CAMPAIGN,
        INITIATIVE,
        RECORD_DATE
      )
      SELECT i10.ACCOUNT_KEY,
            i10.UPLINE_ACCOUNT_KEY,
            i10.INACTIVE_CAMPAIGNS,
            i10.QV,
            i10.POTENTIAL_QV,
            i10.CTD_QV,
            i10.PY_CTD_QV,
            i10.RETURN_QV,
            i10.POTENTIAL_RETURN_QV,
            i10.AVAILABLE_CREDIT,
            i10.ACCOUNT_TYPE,
            i10.ACCOUNT_NUMBER,
            i10.DISTRICT,
            i10.TRANSPZ,
            i10.LOA,
            i10.NAME_FIRST,
            i10.NAME_MIDDLE,
            i10.NAME_LAST,
            i10.TIER,
            i10.TIER_KEY,
            i10.DUNNG_LVL_KEY,
            i10.BIRTH_DT,
            i10.GENDER,
            i10.LEGAL_AGREEMENT_DT,
            i10.APPOINTMENT_DT,
            i10.APPOINTMENT_CAMPAIGN,
            i10.REMOVAL_CAMPAIGN,
            i10.REINSTATEMENT_CAMPAIGN,
            i10.HOME_ADDRESS1,
            i10.DEL_ADDRESS1,
            i10.HOME_CITY,
            i10.HOME_POSTAL_CODE,
            i10.HOME_PROVINCE,
            i10.DEL_CITY,
            i10.DEL_PROVINCE,
            i10.DEL_POSTAL_CODE,
            i10.EMAIL,
            i10.LANGUAGE,
            i10.STATUS,
            i10.STATUS_CODE,
            i10.DAYTIME_PHONE,
            i10.EVENING_PHONE,
            i10.MOBILE_PHONE,
            i10.TIME_ZONE_TXT,
            i10.UPLINE_ACCOUNT_NUMBER,
            i10.SCHED_SBMT_DT,
            i10.ALT_SBMT_DT,
            i10.CAMPAIGN,
            i10.DIVISION,
            i10.DUNNG_LVL_CD,
            i10.DUNNG_LVL_DESC_TXT,
            i10.ORDER_BLOCK,
            i10.ALLOW_DSM_SMS,
            i10.ALLOW_DSM_EMAIL,
            i10.ALLOW_DSM_PHONE,
            i10.ALLOW_PROMOINC_EMAIL,
            i10.DRAFT_QV,
            i10.DRAFT_QV_NEXT,
            i10.DRAFT_QV_PC,
            i10.CAMPAIGN_PRIOR1,
            i10.CAMPAIGN_PRIOR2,
            i10.CAMPAIGN_PRIOR3,
            i10.CAMPAIGN_PRIOR4,
            i10.CAMPAIGN_PRIOR5,
            i10.QV_PRIOR1,
            i10.QV_PRIOR2,
            i10.QV_PRIOR3,
            i10.QV_PRIOR4,
            i10.QV_PRIOR5,
            i10.QV_26CAMPSUM,
            i10.QV_9CAMPSUM,
            i10.ACTIVE_26CAMP,
            i10.ACTIVE_9CAMP,
            i10.AVG_ORDER_26C,
            i10.AVG_ORDER_9C,
            i10.PAID_BROCHURE_CURRENT_CAMP,
            i10.PAID_BROCHURE_NEXT_CAMP,
            b.BROCHURE_UNIT AS FREE_BROCHURE_NEXT_CAMP,
            daytoday AS DAY_OF_CAMPAIGN,
            'Inactive' AS INITIATIVE,
            trunc(sysdate) AS RECORD_DATE
      FROM IS10 i10
      LEFT JOIN (SELECT ACCT_NR, BROCHURE_CAMPAIGN, BROCHURE_UNIT
                FROM IS_BrochureSales2_FREE
                WHERE BROCHURE_CAMPAIGN = campaign_nxt
                ) b
      ON b.ACCT_NR = i10.ACCOUNT_NUMBER;

      -- language abreviations cause error at hubspot. Update with its full name
      UPDATE IS11
      SET LANGUAGE =
          CASE
            WHEN LANGUAGE = 'EN' THEN 'ENGLISH'
              WHEN LANGUAGE = 'FR' THEN 'FRENCH'
          END;

      -- QUICK FIX: to tag deactivated Reps with a separate INITIATIVE. 
      -- Note that regardless their status, all other Reps will be tagged INITIATIVE Inactive
      -- However among the records with Initiative Inactive, only the records with status = Inactive 
      -- will be added to the list
      UPDATE IS11
            SET INITIATIVE = 'Deactivated'
            WHERE STATUS = 'Deactivated';

      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS_BrochureSales2_PAID';
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS_BrochureSales2_FREE';
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS10';

      -- ADD your final list to the IS_CAMPAIGN table where you keep the inactive list day by day for the current and previous campaign
      -- Delete records for the 2nd last campaign and before: ather then the day after flip this will be redundant
      -- Delete records for today if any. This may happen in case the user runs the procedure twice within the same day
      DELETE FROM IS_CAMPAIGN
      WHERE CAMPAIGN <= campaign_pc2 
            OR (CAMPAIGN = campy AND DAY_OF_CAMPAIGN = daytoday);

      -- drop the key as it slows down the insert
      EXECUTE IMMEDIATE 'ALTER TABLE IS_CAMPAIGN
                        DROP CONSTRAINT acc';

      INSERT INTO IS_CAMPAIGN
        (ACCOUNT_KEY,
        ACCOUNT_NUMBER,
        CAMPAIGN,
        INITIATIVE,
        DAY_OF_CAMPAIGN,
        RECORD_DATE)
      SELECT
        ACCOUNT_KEY,
        ACCOUNT_NUMBER,
        CAMPAIGN,
        INITIATIVE,
        DAY_OF_CAMPAIGN,
        RECORD_DATE
      FROM IS11
      WHERE (
            (STATUS = 'Inactive'
            AND TIER IN ('New','Bronze','Silver')
            AND INACTIVE_CAMPAIGNS BETWEEN 2 AND 4
            AND (UPLINE_ACCOUNT_NUMBER <= 21 OR UPLINE_ACCOUNT_NUMBER IS NULL))
            OR
            (STATUS = 'Deactivated'
            AND INACTIVE_CAMPAIGNS BETWEEN 7 AND 25) -- CHANGE: AND INACTIVE_CAMPAIGNS BETWEEN 7 AND 10)
            )
            AND QV = 0
            AND POTENTIAL_QV = 0
            AND DRAFT_QV IS NULL
            AND (DUNNG_LVL_CD IS NULL OR DUNNG_LVL_CD BETWEEN 1 AND 2)
            AND ORDER_BLOCK IS NULL
            -- AND (UPLINE_ACCOUNT_NUMBER <= 21 OR UPLINE_ACCOUNT_NUMBER IS NULL) -- CHANGE
            AND ALLOW_PROMOINC_EMAIL = 1
            AND ALLOW_DSM_PHONE = 1;

      -- re-add the key as it is necessary for the join below
      EXECUTE IMMEDIATE 'ALTER TABLE IS_CAMPAIGN
                         ADD CONSTRAINT acc 
                             PRIMARY KEY(ACCOUNT_KEY, DAY_OF_CAMPAIGN, CAMPAIGN)';

      -- ADD ADDIITONAL TABLES TO SPEED UP QV RETRIEVAL
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IS_DISTINCT_ACCOUNTS';

      INSERT INTO IS_DISTINCT_ACCOUNTS
             (ACCOUNT_NUMBER,
             ACCOUNT_KEY,
             CAMPAIGN,
             INITIATIVE
             )
      SELECT DISTINCT ACCOUNT_NUMBER, ACCOUNT_KEY, CAMPAIGN, INITIATIVE
      FROM IS_CAMPAIGN;


      UPDATE IS_DISTINCT_ACCOUNTS
      SET CAMPAIGN_NEXT =
          CASE
            WHEN substr(CAMPAIGN, 5, 2) = 26 THEN CAMPAIGN + 75
              ELSE CAMPAIGN + 1
            END;

      UPDATE IS_DISTINCT_ACCOUNTS
      SET CAMPAIGN = substr(CAMPAIGN, 1, 4) || '03' || substr(CAMPAIGN, 5, 2),
          CAMPAIGN_NEXT = substr(CAMPAIGN_NEXT, 1, 4) || '03' || substr(CAMPAIGN_NEXT, 5, 2);

      -- Delete records within this campaign and the previous one. you will repull data as it can change everyday. People may have placed new orders. Objective is not only to identify actives but also by how much QV they have become active
      DELETE FROM IS_ALL
      WHERE CAMPAIGN > campaign_pc2
            AND (INITIATIVE = 'Inactive'
                OR INITIATIVE = 'Deactivated');
      -- The IS_CAMPAIGN table has only the last 2C's inactives. Bring their QVs
      INSERT INTO IS_ALL
        (ACCOUNT_KEY,
        ACCOUNT_NUMBER,
        CAMPAIGN,
        QV,
        QV_NEXT,
        INITIATIVE)
    SELECT i.ACCOUNT_KEY, i.ACCOUNT_NUMBER, substr(i.CAMPAIGN, 1, 4) || substr(i.CAMPAIGN, 7, 2) AS CAMPAIGN,
           nvl(c.awrd_sls_amt, 0) QV,
           nvl(c_next.awrd_sls_amt, 0) QV_NEXT,
           i.INITIATIVE
    FROM IS_DISTINCT_ACCOUNTS i
    LEFT JOIN cdw.sum_mrkt_acct_sls@cdw.prod.sap.lnk c
         ON i.ACCOUNT_KEY = c.ACCT_KEY
            AND i.CAMPAIGN = c.fld_sls_cmpgn_perd_id
                AND c.mrkt_id = 34
    LEFT JOIN cdw.sum_mrkt_acct_sls@cdw.prod.sap.lnk c_next
         ON i.ACCOUNT_KEY = c_next.ACCT_KEY
            AND i.CAMPAIGN_NEXT = c_next.fld_sls_cmpgn_perd_id
                AND c_next.mrkt_id = 34;
end INSIDESALES_5;
