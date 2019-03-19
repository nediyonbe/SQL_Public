create or replace function GEN_COUNT_AR(gen IN NUMBER, campy in NUMBER)
   return number
AS
  row_count number;
BEGIN
    SELECT COUNT(*) 
    into row_count
    FROM AR
    WHERE GENERATION = gen
          AND CAMPAIGN = campy;

    return row_count;
END GEN_COUNT_AR;
