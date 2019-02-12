CREATE OR REPLACE FUNCTION get_campaign(campaign_origin_id IN NUMBER, campaign_diff IN NUMBER)
   RETURN NUMBER
   IS campaign_to_find NUMBER(11,2);
   BEGIN
      SELECT campaign
      INTO campaign_to_find
      FROM IS_Campaigns
      WHERE campaign_id = campaign_origin_id + campaign_diff;

      RETURN(campaign_to_find);
    END;
