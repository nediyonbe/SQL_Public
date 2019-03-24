CREATE OR REPLACE PROCEDURE DROP_TABLE_IFEXISTS(tablename IN VARCHAR2)
IS
CANTIDAD NUMBER(3); 
BEGIN
SELECT COUNT(*) INTO CANTIDAD FROM USER_TABLES WHERE UPPER(TABLE_NAME) = UPPER(tablename);
dbms_output.put_line(CANTIDAD);
IF (CANTIDAD >0) THEN
    execute immediate 'DROP TABLE ' || tablename;
END IF;
END DROP_TABLE_IFEXISTS;
