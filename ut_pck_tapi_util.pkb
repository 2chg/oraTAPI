create or replace package body ut_PCK_TAPI_UTIL
is

    -- -------------------------------------------------------------------------------- --
    -- --                     UNIT-TEST-Package für PCK_TAPI_UTIL                    -- --
    -- -------------------------------------------------------------------------------- --
    -- --               Erstellt am 29.8.2014 von Christian Heß-Grünig               -- --
    -- -------------------------------------------------------------------------------- --
    -- -- Dieses Package dient nur als Test-Hilfsmittel für die Entwicklung und muss -- --
    -- -- nicht im Produktivsystem eingespielt werden.                               -- --
    -- -------------------------------------------------------------------------------- --

    -- k_null_as_string  constant varchar2(10) := '#<NULL>#';
    -- k_null_as_int     constant integer      := -987654321;
    -- k_null_as_date    constant date         := date '0001-01-01';

    -- Name of the test table
    k_test_table_name     constant varchar2(25) := 'T_UT_PCK_TAPI_UTIL_TEST';
    k_test_aud_table_name constant varchar2(30) := PCK_TAPI_UTIL.k_audit_table_prefix
                                                   || k_test_table_name
                                                   || PCK_TAPI_UTIL.k_audit_table_suffix;
    k_test_table_seq_name constant varchar2(30) := k_test_table_name
                                                   || '_SEQ';

    -- ----------------------------------------------------------------------

    e_insuf_privs exception;
    pragma exception_init(e_insuf_privs, -1031);

    -- ======================================================================

    procedure assertBool(p_msg_in        in varchar2
                       , p_check_this_in in boolean
                       , p_expected_bool in varchar2 default 'TRUE')
    is
    begin
        case p_expected_bool
          when 'TRUE'
            then
              utAssert.this(MSG_IN          => p_msg_in || ' (should be TRUE)'
                          , CHECK_THIS_IN   => p_check_this_in
              );
          when 'FALSE'
            then
              utAssert.this(MSG_IN          => p_msg_in || ' (should be FALSE)'
                          , CHECK_THIS_IN   => not(p_check_this_in)
              );
          when 'NULL'
            then
              utAssert.isNull(MSG_IN        => p_msg_in || ' (should be NULL)'
                            , CHECK_THIS_IN => p_check_this_in
              );
          end case;
    end assertBool;

    -- ----------------------------------------------------------------------

    procedure assertFail(p_msg_in in varchar2)
    is
    begin
        utAssert.this(msg_in          => p_msg_in
                    , check_this_in   => false);
    end assertFail;

    -- ======================================================================

    procedure remove_test_tables
    is
        pragma autonomous_transaction;
    begin

        begin
            execute immediate 'drop table ' || k_test_table_name;
            -- dbms_output.put_line('ut_PCK_TAPI_UTIL.remove_test_tables => drop table ' || k_test_table_name || ' successful.');
        exception
            when e_insuf_privs
            then
                assertFail('[CRITICAL] UnitTest prerequisites failed: User is not allowed to DROP TABLEs (in PL/SQL)!');
            when others
            then
                null;
        end;

        begin
            execute immediate 'drop table ' || k_test_aud_table_name;
            -- dbms_output.put_line('ut_PCK_TAPI_UTIL.remove_test_tables => drop table ' || k_test_aud_table_name || ' successful.');
        exception
            when e_insuf_privs
            then
                assertFail('[CRITICAL] UnitTest prerequisites failed: User is not allowed to DROP TABLEs (in PL/SQL)!');
            when others
            then
                null;
        end;

        begin
            execute immediate 'drop sequence ' || k_test_table_seq_name;
            -- dbms_output.put_line('ut_PCK_TAPI_UTIL.remove_test_tables => drop sequence ' || k_test_table_seq_name || ' successful.');
        exception
            when e_insuf_privs
            then
                assertFail('[CRITICAL] UnitTest prerequisites failed: User is not allowed to DROP SEQEUENCEs (in PL/SQL)!');
            when others
            then
                null;
        end;

        commit;

    end remove_test_tables;

    -- ----------------------------------------------------------------------

    procedure create_test_tables
    is
        pragma autonomous_transaction;
    begin

        remove_test_tables;

        begin
            execute immediate 'create sequence ' || k_test_table_seq_name;
            -- dbms_output.put_line('ut_PCK_TAPI_UTIL.create_test_tables => create sequence ' || k_test_table_seq_name || ' successful.');
        exception
            when e_insuf_privs
            then
                assertFail('[CRITICAL] UnitTest prerequisites failed: User misses (direct) CREATE SEQEUENCE privilege! Cannot run UnitTests.');
        end;

        begin
            execute immediate 'create table ' || k_test_table_name || ' (
                                   ID     integer       not null primary key
                                 , VALUTA date
                                 , AMOUNT number(8,2)   not null
                                 , TEXT   varchar2(10)
                               )';
            -- dbms_output.put_line('ut_PCK_TAPI_UTIL.create_test_tables => create table ' || k_test_table_name || ' successful.');
        exception
            when e_insuf_privs
            then
                assertFail('[CRITICAL] UnitTest prerequisites failed: User misses (direct) CREATE TABLE privilege! Cannot run UnitTests.');
        end;

        commit;

    end create_test_tables;

    -- ======================================================================

    procedure ut_setup
    is
    begin
        -- Tidy up before starting the first test
        rollback;
    end ut_setup;

    -- ----------------------------------------------------------------------

    procedure ut_teardown
    is
    begin
        -- Tidy up after finishing the last test
        rollback;
        remove_test_tables;
    end ut_teardown;

    -- ======================================================================

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

    -- ======================================================================

    -- ----------
    -- Unit Tests

    procedure ut_CREATE_AUDIT_TABLE
    is

        l_text PCK_TAPI_UTIL.t_max_vc2;

        cursor c_aud_cols is
            with AUD_COLS
                 as (select case
                              when (c.column_name like 'JN_' || '%' escape '\')
                                then 'JN'
                              when (c.nullable = 'N')
                                then 'PK'
                              else 'XX'
                            end
                                          as GRP
                          , c.column_name as COLUMN_NAME
                       from user_tab_cols c
                       where c.table_name = k_test_aud_table_name)
            select   grp                                 as GRP
                   , count(*)                            as CNT
                   , listagg(case
                               when grp = 'JN'
                                 then regexp_replace(column_name, '^' || PCK_TAPI_UTIL.k_audit_column_prefix, null)
                               else
                                 column_name
                             end
                           , ', ')
                     within group (order by column_name) as COLS
            from     AUD_COLS
            group by GRP;

        r_aud_cols c_aud_cols%ROWTYPE;

    begin

        create_test_tables;

        utAssert.objNotExists('ut_CREATE_AUDIT_TABLE: Audit Table is initially not existent'
                            , k_test_aud_table_name);

        -- Create Audit Table
        l_text := PCK_TAPI_UTIL.create_audit_table_statement(user, k_test_table_name);
        l_text := clean_for_execute_immediate(l_text);
        begin
            PCK_TAPI_UTIL.autonomous_execute_immediate(p_statement => l_text);
        exception
            when e_insuf_privs
            then
                assertFail('[CRITICAL] UnitTest prerequisites failed: User is not allowed to CREATE TABLEs (in PL/SQL)!');
                raise;
        end;

        utAssert.objExists('ut_CREATE_AUDIT_TABLE: Audit Table created'
                         , k_test_aud_table_name);

        open c_aud_cols;
        fetch c_aud_cols into r_aud_cols;
        utAssert.eq('ut_CREATE_AUDIT_TABLE: Meta-Columns', r_aud_cols.COLS, 'DB_USER, NOTES, OP, SESSION_ID, TS');
        fetch c_aud_cols into r_aud_cols;
        utAssert.eq('ut_CREATE_AUDIT_TABLE: PK-Columns',   r_aud_cols.COLS, 'ID');
        fetch c_aud_cols into r_aud_cols;
        utAssert.eq('ut_CREATE_AUDIT_TABLE: Data-Columns', r_aud_cols.COLS, 'AMOUNT, TEXT, VALUTA');
        close c_aud_cols;

        remove_test_tables;

    end ut_CREATE_AUDIT_TABLE;

    -- ======================================================================

    procedure ut_CREATE_TAPI_TRIGGER
    is

        k_trigger_count_sql constant PCK_TAPI_UTIL.t_max_vc2 := 'select count(*) as CNT
                                                                   from user_triggers t
                                                                   where t.table_name = ''' || k_test_table_name || '''';
        l_text PCK_TAPI_UTIL.t_max_vc2;

    begin

        create_test_tables;

        utAssert.eqqueryvalue('ut_CREATE_TAPI_TRIGGER: TAPI trigger is initially not existent'
                            , k_trigger_count_sql
                            , 0);

        -- Create Audit Table
        l_text := PCK_TAPI_UTIL.create_audit_table_statement(user, k_test_table_name);
        l_text := clean_for_execute_immediate(l_text);
        begin
            PCK_TAPI_UTIL.autonomous_execute_immediate(p_statement => l_text);
        exception
            when e_insuf_privs
            then
                assertFail('[CRITICAL] UnitTest prerequisites failed: User is not allowed to CREATE TABLEs (in PL/SQL)!');
                raise;
        end;

        -- Create TAPI Trigger
        l_text := PCK_TAPI_UTIL.create_tapi_trigger_statement(p_base_table_owner     => user
                                                            , p_base_table_name      => k_test_table_name
                                                            , p_id_sequence_name     => k_test_table_seq_name
                                                            , p_id_column_name       => 'ID'
                                                            , p_delete_logs_old_data => true
                                                            );
        l_text := clean_for_execute_immediate(l_text);
        begin
            PCK_TAPI_UTIL.autonomous_execute_immediate(p_statement => l_text);
        exception
            when e_insuf_privs
            then
                assertFail('[CRITICAL] UnitTest prerequisites failed: User is not allowed to CREATE TRIGGERSs (in PL/SQL)!');
                raise;
        end;

        utAssert.eqqueryvalue('ut_CREATE_TAPI_TRIGGER: TAPI trigger created'
                            , k_trigger_count_sql
                            , 1);

        remove_test_tables;

    end ut_CREATE_TAPI_TRIGGER;

    -- ======================================================================

end ut_PCK_TAPI_UTIL;
/
