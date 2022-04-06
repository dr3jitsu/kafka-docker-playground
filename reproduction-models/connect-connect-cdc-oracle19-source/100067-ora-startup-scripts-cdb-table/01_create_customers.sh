#!/bin/sh

echo 'Creating CUSTOMERS table in CDB'

sqlplus C\#\#MYUSER/mypassword@//localhost:1521/ORCLCDB  <<- EOF

  create table CUSTOMERS (
          id NUMBER(10) GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH 42) NOT NULL PRIMARY KEY,
          first_name VARCHAR(50),
          last_name VARCHAR(50),
          email VARCHAR(50),
          gender VARCHAR(50),
          club_status VARCHAR(20),
          comments VARCHAR(90),
          create_ts timestamp DEFAULT CURRENT_TIMESTAMP ,
          update_ts timestamp,
          CREDIT_CARD_NO  VARCHAR2(500 BYTE) DEFAULT 'test'
  );

  CREATE OR REPLACE TRIGGER TRG_CUSTOMERS_UPD
  BEFORE INSERT OR UPDATE ON CUSTOMERS
  REFERENCING NEW AS NEW_ROW
    FOR EACH ROW
  BEGIN
    SELECT SYSDATE
          INTO :NEW_ROW.UPDATE_TS
          FROM DUAL;
  END;
  /

EOF

