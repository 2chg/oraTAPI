/*
 * Copyright 2014 Christian Heß-Grünig
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

set define off;

rollback;

/* ************************** *\
\* ** TEST ** TEST ** TEST ** */

create sequence STEST_DATA_ID;

create table TTEST_DATA (
    ID     integer       not null primary key
  , VALUTA date
  , AMOUNT number(8,2)   not null
  , TEXT   varchar2(10)
);

/* ** TEST ** TEST ** TEST ** *\
\* ************************** */

-- ====================================================================================================

@@ pck_tapi_util.pks
-- @@ pck_tapi_util.pkb

-- ====================================================================================================

/* ************************** *\
\* ** TEST ** TEST ** TEST ** */

-- select PCK_TAPI_UTIL.get_version "TAPI-Version" from dual;

set serveroutput on

declare
    l_text PCK_TAPI_UTIL.t_max_vc2;
    function clean_for_execute_immediate(p_text in clob)
        return clob
    is
    begin
        return regexp_replace(
               regexp_replace(
               regexp_replace(p_text, '^/\*.*?\*/[\r\n]*',             null)
                                    , 'comment on table[^;]+;[\r\n]*', null)
                                    , '[\r\n;/]*$',                    null);
    end clean_for_execute_immediate;
begin
    DBMS_OUTPUT.enable;
    l_text := PCK_TAPI_UTIL.create_audit_table_statement(user, 'TTEST_DATA');
    dbms_output.put_line(chr(10) || '<CREATE_AUDIT_TABLE>' || chr(10) || l_text || chr(10) || '</CREATE_AUDIT_TABLE>' || chr(10));
    l_text := clean_for_execute_immediate(l_text);
    pku.autonomous_execute_immediate(l_text);
    --
    l_text := PCK_TAPI_UTIL.create_tapi_trigger_statement(p_base_table_owner     => user
                                                        , p_base_table_name      => 'TTEST_DATA'
                                                        , p_id_sequence_name     => 'STEST_DATA_ID'
                                                        , p_id_column_name       => 'ID'
                                                        , p_delete_logs_old_data => true
                                                        );
    dbms_output.put_line(chr(10) || '<CREATE_TAPI_TRIGGER>' || chr(10) || l_text || chr(10) || '</CREATE_TAPI_TRIGGER>' || chr(10));
    l_text := clean_for_execute_immediate(l_text);
    pku.autonomous_execute_immediate(l_text);
end;
/

insert into TTEST_DATA (VALUTA, AMOUNT, TEXT) values (trunc(sysdate-7), 123, 'DS 1');
insert into TTEST_DATA (VALUTA, AMOUNT, TEXT) values (trunc(sysdate-6), -23, 'DS 2');
insert into TTEST_DATA (VALUTA, AMOUNT, TEXT) values (trunc(sysdate-5), 234, 'DS 3');
insert into TTEST_DATA (VALUTA, AMOUNT, TEXT) values (trunc(sysdate-4), -34, 'DS 4');

update TTEST_DATA set amount = amount * 2, text = 'DS 5' where amount > 0;
delete TTEST_DATA where amount = -23;

set line 200

select *
  from TTEST_DATA;

column JN_NOTES   format a45
column JN_DB_USER format a15
column TEXT       format a10

select *
  from TTEST_DATA_AUD
  order by JN_TS;

commit;

drop table TTEST_DATA_AUD;
drop table TTEST_DATA;
drop sequence STEST_DATA_ID;

/* ** TEST ** TEST ** TEST ** *\
\* ************************** */
