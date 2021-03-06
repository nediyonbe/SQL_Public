create or replace procedure TRUNCATE_IFEXISTS(tablename IN VARCHAR2)
IS
CANTIDAD NUMBER(3);
BEGIN
SELECT COUNT(*) INTO CANTIDAD FROM USER_TABLES WHERE UPPER(TABLE_NAME) = UPPER(tablename);
IF (CANTIDAD >0) THEN
    execute immediate 'TRUNCATE TABLE ' || tablename;
END IF;
end TRUNCATE_IFEXISTS;
