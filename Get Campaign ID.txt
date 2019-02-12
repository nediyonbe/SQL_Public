CREATE OR REPLACE FUNCTION get_campaign_id(campaign_origin IN NUMBER)
   RETURN NUMBER
   IS campaign_id_to_find NUMBER(11,2);
   BEGIN
      SELECT campaign_id
      INTO campaign_id_to_find
      FROM IS_Campaigns
      WHERE campaign = campaign_origin;

      RETURN(campaign_id_to_find);
   END;
