create or replace procedure TOPLINE_CALCULATOR_AR(campy IN NUMBER) is
gen NUMBER(8);
loopy NUMBER(8);
--toppy NUMBER(10);
cursed_ID NUMBER(10);
--cursed_gen NUMBER(10);
cursed_topline NUMBER(10);

CURSOR CURSOR_TOPLINE(geny IN NUMBER)
IS
SELECT a.ID, t.TOPLINE_ID
FROM AR a
JOIN  TOPLINE_TABLE t
     ON a.SPONSOR_ID = t.ID
WHERE t.GENERATION = geny
      AND a.CAMPAIGN = campy;
     
begin
            DBMS_OUTPUT.ENABLE;
            dbms_output.put_line('Starting '); 
            gen := 1;
            loopy := 0;
       
            DELETE FROM TOPLINE_TABLE;
            
            UPDATE AR
            SET TOPLINE_ID = NULL,
                GENERATION = NULL
            WHERE CAMPAIGN = campy;

            UPDATE AR
            SET TOPLINE_ID = ID,
                GENERATION = 1
            WHERE CAMPAIGN = campy
                  AND (SPONSOR_ID <= 500 OR SPONSOR_ID IS NULL);

-- this is for the G1
            INSERT INTO TOPLINE_TABLE -- ID SPONSOR_ID, TOPLINE_ID
            (ID, SPONSOR_ID, BADGE_TITLE, TOPLINE_ID, GENERATION)
            SELECT ID, SPONSOR_ID, BADGE_TITLE, ID AS TOPLINE_ID, 1 AS GENERATION
            FROM AR
            WHERE CAMPAIGN = campy 
                  AND GENERATION = 1
                  AND ID > 500; -- IDs < 500 are AVON HOUSE
            
WHILE loopy = 0
LOOP

            IF GEN_COUNT_AR(gen, campy) = 0 THEN loopy := 1; 
            END IF;
           
            
            INSERT INTO TOPLINE_TABLE
            (ID, BADGE_TITLE, SPONSOR_ID, TOPLINE_ID, GENERATION)
            SELECT a.ID, a.BADGE_TITLE, a.SPONSOR_ID, t.TOPLINE_ID AS TOPLINE_ID, gen + 1 AS GENERATION
            FROM AR a
            LEFT JOIN TOPLINE_TABLE t
                 ON a.SPONSOR_ID = t.ID
            WHERE a.CAMPAIGN = campy
                  AND t.GENERATION = gen
                  AND a.SPONSOR_ID IN
                    (SELECT ID
                    FROM TOPLINE_TABLE
                    WHERE GENERATION = gen);
                    
            OPEN CURSOR_TOPLINE(gen);
            LOOP
                FETCH CURSOR_TOPLINE INTO cursed_ID, cursed_topline;
                EXIT WHEN CURSOR_TOPLINE%NOTFOUND;
                
                --dbms_output.put_line(' ID being processed: ' || cursed_ID); 
                
                UPDATE AR
                SET GENERATION = gen + 1,
                    TOPLINE_ID = cursed_topline
                WHERE ID = cursed_ID
                      AND campaign = campy;
            END LOOP;
            CLOSE CURSOR_TOPLINE;
            gen := gen + 1;
            
            COMMIT;
END LOOP;
end TOPLINE_CALCULATOR_AR;
