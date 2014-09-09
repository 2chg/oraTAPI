set pagesize 100
set line 200
column text format a70 wrap

@@ pck_tapi_util.pks
-- @@ pck_tapi_util.pkb

@@ ut_pck_tapi_util.pks

select *
  from user_errors ue
  where ue.name in ('UT_PCK_TAPI_UTIL');


set serveroutput on size 1000000 format wrapped
set linesize 499
exec utConfig.showfailuresonly(true);
exec utConfig.autocompile (false);
prompt =====================================================================================
prompt ============================ utplsql.test (PCK_TAPI_UTIL) ===========================
exec utplsql.test('PCK_TAPI_UTIL', recompile_in => FALSE);
prompt ============================ utplsql.test (PCK_TAPI_UTIL) ===========================
prompt =====================================================================================

select substr(
         case
           when owner != user
             then owner || '.'
         end
         || name         , 1, 40) NAME
     , substr(last_status, 1, 7)  STATUS
     , to_char(
         last_end
       , 'yyyy-mm-dd hh24:mi')    LAST_END
     , last_run_id
     , executions
     , failures
  from ut_package
  where last_end > sysdate - 1;

drop package UT_PCK_TAPI_UTIL;
