create or replace procedure Generation_Computer(campy IN NUMBER) IS
  gen NUMBER(8);
  loopy NUMBER(8);
begin
  gen := 1;
  loopy := 0;
  
  UPDATE AR_OFFICIAL
  SET GENERATION = NULL 
  WHERE CAMPAIGN = campy;
  
  UPDATE AR_OFFICIAL 
  SET GENERATION = 0 
  WHERE CAMPAIGN = campy
        AND ID IN (1, 21);
  
  UPDATE AR_OFFICIAL 
  SET GENERATION = gen 
  WHERE CAMPAIGN = campy
        AND GENERATION IS NULL -- Accounts 1 and 21 have null sponsors. They shouldn't get G1 label
        AND SPONSOR_ID IS NULL 
        OR SPONSOR_ID IN (0, 1, 21);
  
  DELETE FROM GEN_TABLE; 

  INSERT INTO GEN_TABLE
  (ID, GENERATION)
  SELECT ID, GENERATION
  FROM AR_OFFICIAL
  WHERE CAMPAIGN = campy
        AND GENERATION IS NOT NULL;
        

  WHILE loopy = 0
  LOOP
    IF GEN_COUNT(gen, campy) = 0 THEN loopy := 1;
    END IF;
  
  UPDATE AR_OFFICIAL 
  SET GENERATION = gen + 1
  WHERE CAMPAIGN = campy
        AND GENERATION IS NULL -- This is for 1-21-NULL sponsors. O/W 1 and 21 get G1 then those with sponsor 1 or 21 get G2.
        AND SPONSOR_ID IN
            (SELECT ID
            FROM GEN_TABLE
            WHERE GENERATION = gen);

  INSERT INTO GEN_TABLE
  (ID, GENERATION)
  SELECT ID, GENERATION
  FROM AR_OFFICIAL
  WHERE CAMPAIGN = campy
        AND GENERATION = gen + 1;
        
  gen := gen + 1;
  END LOOP;

  
end Generation_Computer;
