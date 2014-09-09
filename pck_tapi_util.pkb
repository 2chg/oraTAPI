set define off;

prompt
prompt * Creating Package Body PCK_TAPI_UTIL ...

create or replace package body PCK_TAPI_UTIL
as

    /*
     * ========================================================================
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
     * ========================================================================
     */

    -- ================================================================================================

    k_tapi_version        constant varchar2(30) := k_tapi_version_MAJOR || '.' || k_tapi_version_MINOR || '.' || k_tapi_version_PATCH;
    k_tapi_version_string constant varchar2(30) := '[TAPI v' || k_tapi_version || ']';

    -- ================================================================================================

    cursor c_infer_audit_table_columns(pc_base_table_owner in varchar2
                                     , pc_base_table_name  in varchar2
                                     , pc_pk_columns_only  in t_flag   default 0)
    is
        select c.column_name                                            as COLUMN_NAME
             , c.data_type
               || case
                    when c.data_type in ('VARCHAR2', 'VARCHAR', 'CHAR')
                      then '(' || c.data_length || ')'
                  end                                                   as DATA_TYPE
               , case
                   when pk.position is not null
                     then 'NOT NULL'
                 end                                                    as NOT_NULL
               , max(length(c.column_name))
                 over (partition by c.table_name)                       as MAX_COL_NAME_LENGTH
          from all_tab_cols c
            left join (select owner
                            , ac.table_name
                            , acc.column_name
                            , acc.position
                         from   all_constraints  ac
                           join all_cons_columns acc using (constraint_name, owner)
                         where ac.constraint_type = 'P') pk
              on     pk.owner = c.owner
                 and pk.table_name = c.table_name
                 and pk.column_name = c.column_name
          where c.owner = upper(pc_base_table_owner)
            and c.table_name = upper(pc_base_table_name)
            and c.hidden_column = 'NO'
            and c.data_type not in ('LONG', 'BLOB')
            and c.column_id is not null
            and (   pc_pk_columns_only = 0
                 or pk.position is not null)
          order by pk.position, c.column_id;

    type t_audit_column_meta_data is table of c_infer_audit_table_columns%ROWTYPE
                                     index by simple_integer;

    -- ================================================================================================

    function get_version
        return varchar2
    is
    begin
        return k_tapi_version;
    end get_version;

    -- ================================================================================================

    -- private function: (A)dd(L)ine
    procedure al(l_variable in out varchar2
               , p_new_line in     varchar2)
    is
    begin
        l_variable := l_variable || NL || p_new_line;
    end al;

    -- private function: (P)rint
    procedure p(p_text in varchar2)
    is
    begin
        dbms_output.put_line(p_text);
    end p;

    -- ================================================================================================

    -- Generiert aus dem Namen der Grund-Tabelle den Namen der korrespondierenden Audit-Tabelle
    function audit_table(p_base_table in varchar2)
        return varchar2
    is
    begin
        return upper(k_audit_table_prefix || substr(p_base_table, 1, k_audit_table_signif_name_len) || k_audit_table_suffix);
    end audit_table;

    -- ------------------------------------------------------------------------------------------------

    -- Generiert aus dem (signifikanten Teil des) Namen(s) der Meta-Daten-Spalte den tatsächlichen Spalten-Namen in der Audit-Tabelle
    function audit_column(p_audit_column_name_base in varchar2)
        return varchar2
    is
    begin
        return upper(k_audit_column_prefix || substr(p_audit_column_name_base, 1, k_audit_column_signif_name_len));
    end audit_column;

    -- ================================================================================================

    function audit_column_meta_data(p_base_table_owner in varchar2
                                  , p_base_table_name  in varchar2
                                  , p_pk_columns_only  in t_flag   default 0)
        return t_audit_column_meta_data
    is
        l_audit_column_meta_data t_audit_column_meta_data;
    begin
        open c_infer_audit_table_columns(p_base_table_owner
                                       , p_base_table_name
                                       , p_pk_columns_only);
        fetch c_infer_audit_table_columns bulk collect
          into l_audit_column_meta_data;
        close c_infer_audit_table_columns;
        return l_audit_column_meta_data;
    end audit_column_meta_data;

    -- ------------------------------------------------------------------------------------------------

    function template_applied_columns(p_template                 in varchar2
                                    , p_audit_column_meta_data   in t_audit_column_meta_data
                                    , p_add_newline_between_cols in boolean                  default true)
        return varchar2
    is
        v_text   t_max_vc2;
        v_line   t_max_vc2;
        l_index  binary_integer;
        l_column c_infer_audit_table_columns%ROWTYPE;
    begin
        l_index := p_audit_column_meta_data.first;
        <<AUDIT_COLUMNS>>
        while (l_index is not null)
        loop
            l_column := p_audit_column_meta_data(l_index);
            l_index := p_audit_column_meta_data.next(l_index);
            v_line := p_template || case
                                      when (    p_add_newline_between_cols
                                            and (l_index is not null))
                                      then NL
                                    end;
            v_line := replace(v_line, '%COLUMN_NAME:RPAD%', rpad(l_column.COLUMN_NAME
                                                               , l_column.MAX_COL_NAME_LENGTH));
            v_line := replace(v_line, '%COLUMN_NAME%'     , l_column.COLUMN_NAME);
            v_line := replace(v_line, '%DATA_TYPE%'       , l_column.DATA_TYPE);
            v_line := replace(v_line, '%NOT_NULL%'        , l_column.NOT_NULL);
            v_text := v_text || v_line;
        end loop AUDIT_COLUMNS;
        return v_text;
    end template_applied_columns;

    -- ================================================================================================
    -- ================================================================================================

    procedure autonomous_execute_immediate(p_statement         in varchar2
                                         , p_ignore_exceptions in boolean default false
                                         , p_do_commit         in boolean default true
                                         , p_async_commit      in boolean default false)
    is
        pragma autonomous_transaction;
    begin
        $IF $$output_autonomous_statements $THEN
            dbms_output.put_line('<STATEMENT function="PCK_TAPI_UTIL.autonomous_execute_immediate">' || chr(10)
                || rtrim(rtrim(replace(p_statement, chr(10), chr(10) || '  ')), chr(10))
                || chr(10) || '</STATEMENT>');
        $END
        execute immediate p_statement;
        if (p_do_commit) then
            if (p_async_commit) then
                -- Die Commit-Parameter gibt es erst seit Oracle 10g Database Release 2
                $IF DBMS_DB_VERSION.ver_le_10_1 $THEN
                    commit;
                $ELSE
                    commit write batch nowait;
                $END
            else
                commit;
            end if;
        end if;
    exception
        when others then
            if (not p_ignore_exceptions) then
                raise;
            end if;
    end autonomous_execute_immediate;

    -- ================================================================================================

    function create_audit_table_statement(p_base_table_owner in varchar2
                                        , p_base_table_name  in varchar2)
        return varchar2
    is
        l_create_statement       t_max_vc2;
        l_base_table             varchar2(61)             := upper(p_base_table_owner) || '.' || upper(p_base_table_name);
        l_audit_table            varchar2(61)             := upper(p_base_table_owner) || '.' || audit_table(p_base_table_name);
        l_audit_column_meta_data t_audit_column_meta_data;
    begin
        l_audit_column_meta_data := audit_column_meta_data(p_base_table_owner
                                                         , p_base_table_name);

        l_create_statement := '/* Audit-Table for ' || l_base_table || ' ' || k_tapi_version_string || ' */';
        al(l_create_statement, 'create table ' || l_audit_table || ' (');
        al(l_create_statement, '    /* Meta-Data */');
        al(l_create_statement, '    ' || audit_column('TS') || '         TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL');
        al(l_create_statement, '  , ' || audit_column('OP') || '         CHAR(1) NOT NULL');
        al(l_create_statement, '  , ' || audit_column('DB_USER') || '    VARCHAR2(30) NOT NULL');
        al(l_create_statement, '  , ' || audit_column('SESSION_ID') || ' NUMBER');
        al(l_create_statement, '  , ' || audit_column('NOTES') || '      VARCHAR2(250)');
        al(l_create_statement, '    /* Table-Data */');
        al(l_create_statement
         , template_applied_columns('  , %COLUMN_NAME:RPAD% %DATA_TYPE% %NOT_NULL%'
                                  , l_audit_column_meta_data));
        al(l_create_statement, ');');

        al(l_create_statement, 'comment on table ' || l_audit_table || ' is ''Audit-Table for table ' || l_base_table || ' ' || k_tapi_version_string || ''';');

        return l_create_statement;

    end create_audit_table_statement;

    -- ================================================================================================

    function create_tapi_trigger_statement(p_base_table_owner            in varchar2
                                         , p_base_table_name             in varchar2
                                         , p_id_sequence_name            in varchar2       default null
                                         , p_id_column_name              in varchar2       default null
                                         , p_delete_logs_old_data        in boolean        default false
                                         , p_audit_bulk_insert_threshold in simple_integer default 1000)
        return clob
    is
        l_index                  binary_integer;
        l_column                 c_infer_audit_table_columns%ROWTYPE;
        l_create_statement       t_max_vc2;
        l_base_table             varchar2(61)             := upper(p_base_table_owner) || '.' || upper(p_base_table_name);
        l_audit_table            varchar2(61)             := upper(p_base_table_owner) || '.' || audit_table(p_base_table_name);
        l_audit_trigger          varchar2(61)             := l_audit_table;
        l_audit_trigger_end      varchar2(30)             := audit_table(p_base_table_name);
        l_audit_column_meta_data t_audit_column_meta_data;
    begin
        l_audit_column_meta_data := audit_column_meta_data(p_base_table_owner
                                                         , p_base_table_name);

        l_create_statement := '/* Audit-Trigger for ' || l_base_table || '/' || l_audit_table || ' ' || k_tapi_version_string || ' */';

        al(l_create_statement, 'create or replace trigger ' || l_audit_trigger);
        al(l_create_statement, 'for insert or update or delete');
        al(l_create_statement, 'on ' || l_base_table);
        al(l_create_statement, 'compound trigger');
        al(l_create_statement, '');
        al(l_create_statement, '    /* ' || k_tapi_version_string || ' */');
        al(l_create_statement, '');
        al(l_create_statement, '    type t_audit_data         is table of ' || l_audit_table || '%ROWTYPE');
        al(l_create_statement, '                                 index by simple_integer;');
        al(l_create_statement, '    l_audit_data              t_audit_data;');
        al(l_create_statement, '');
        al(l_create_statement, '    k_bulk_threshold constant simple_integer := ' || p_audit_bulk_insert_threshold || ';');
        al(l_create_statement, '    l_index                   simple_integer := 0;');
        al(l_create_statement, '');
        al(l_create_statement, '    l_session        constant number         := sys_context(''USERENV'', ''SID'');');
        al(l_create_statement, '    l_db_user        constant varchar2(30)   := sys_context(''USERENV'', ''SESSION_USER'');');
        -- al(l_create_statement, ' l_auth_id        constant varchar2(30)   := sys_context(''USERENV'', ''AUTHENTICATED_IDENTITY'');');
        al(l_create_statement, '');
        al(l_create_statement, '    procedure flush_log');
        al(l_create_statement, '    is');
        al(l_create_statement, '    begin');
        al(l_create_statement, '        forall i in 1..l_audit_data.count()');
        al(l_create_statement, '            insert into ' || l_audit_table);
        al(l_create_statement, '              values l_audit_data(i);');
        al(l_create_statement, '        l_audit_data.delete();');
        al(l_create_statement, '        l_index := 0;');
        al(l_create_statement, '    end flush_log;');
        al(l_create_statement, '');
        al(l_create_statement, '    procedure write_log(p_operation in char');
        al(l_create_statement
         , template_applied_columns('                      , %COLUMN_NAME:RPAD% in ' || l_audit_table || '.%COLUMN_NAME%%type'
                                  , l_audit_column_meta_data));
        al(l_create_statement, '                      , p_notes in varchar2 default null');
        al(l_create_statement, '                       )');
        al(l_create_statement, '    is');
        al(l_create_statement, '    begin');
        al(l_create_statement, '        l_index := l_index + 1;');
        al(l_create_statement, '        l_audit_data(l_index).' || audit_column('TS') || '         := systimestamp;');
        al(l_create_statement, '        l_audit_data(l_index).' || audit_column('OP') || '         := p_operation;');
        al(l_create_statement, '        l_audit_data(l_index).' || audit_column('DB_USER') || '    := l_db_user;');
        al(l_create_statement, '        l_audit_data(l_index).' || audit_column('SESSION_ID') || ' := l_session;');
        al(l_create_statement, '        l_audit_data(l_index).' || audit_column('NOTES') || '      := p_notes;');
        al(l_create_statement, '');
        al(l_create_statement
         , template_applied_columns('        l_audit_data(l_index).%COLUMN_NAME:RPAD% := %COLUMN_NAME%;'
                                  , l_audit_column_meta_data));
        al(l_create_statement, '');
        al(l_create_statement, '        if (l_index >= k_bulk_threshold)');
        al(l_create_statement, '        then');
        al(l_create_statement, '            flush_log;');
        al(l_create_statement, '        end if;');
        al(l_create_statement, '    end write_log;');
        al(l_create_statement, '');
        if (    (p_id_sequence_name is not null)
            and (p_id_column_name   is not null))
        then
            al(l_create_statement, '    -- BEFORE EACH ROW');
            al(l_create_statement, '    before each row');
            al(l_create_statement, '    is');
            al(l_create_statement, '    begin');
            al(l_create_statement, '        if INSERTING');
            al(l_create_statement, '        then');
            al(l_create_statement, '            -- Autogenerate key/id column');
            al(l_create_statement, '            if (:new.' || p_id_column_name || ' is null)');
            al(l_create_statement, '            then');
            al(l_create_statement, '                :new.' || p_id_column_name || ' := ' || p_id_sequence_name || '.nextval;');
            al(l_create_statement, '            end if;');
            al(l_create_statement, '        end if;');
            al(l_create_statement, '    end before each row;');
            al(l_create_statement, '');
        end if;
        al(l_create_statement, '    -- AFTER EACH ROW');
        al(l_create_statement, '    after each row');
        al(l_create_statement, '    is');
        al(l_create_statement, '    begin');
        al(l_create_statement, '        if INSERTING');
        al(l_create_statement, '        then');
        al(l_create_statement, '            write_log(p_operation => ''I''');
        al(l_create_statement
         , template_applied_columns('                    , %COLUMN_NAME:RPAD% => :new.%COLUMN_NAME%'
                                  , l_audit_column_meta_data));
        al(l_create_statement, '                     );');
        al(l_create_statement, '        elsif UPDATING');
        al(l_create_statement, '        then');
        al(l_create_statement, '            write_log(p_operation => ''U''');
        al(l_create_statement
         , template_applied_columns('                    , %COLUMN_NAME:RPAD% => :new.%COLUMN_NAME%'
                                  , l_audit_column_meta_data));
        al(l_create_statement, '                     );');
        al(l_create_statement, '        elsif DELETING');
        al(l_create_statement, '        then');
        al(l_create_statement, '            write_log(p_operation => ''D''');

        l_index := l_audit_column_meta_data.first;
        <<AUDIT_COLUMNS_FOR_DEL_TRIGGER>>
        while (l_index is not null)
        loop
            l_column := l_audit_column_meta_data(l_index);
            if (   p_delete_logs_old_data
                or l_column.not_null is not null /* = PK-Column */)
            then
                al(l_create_statement, '                    , ' || rpad(l_column.column_name, l_column.max_col_name_length) || ' => :old.' || l_column.column_name);
            else
                al(l_create_statement, '                    , ' || rpad(l_column.column_name, l_column.max_col_name_length) || ' => null');
            end if;
            l_index := l_audit_column_meta_data.next(l_index);
        end loop AUDIT_COLUMNS_FOR_DEL_TRIGGER;

        if (p_delete_logs_old_data)
        then
            al(l_create_statement, '                    , p_notes => ''TAPI: Data representing the pre-delete-state!''');
        end if;
        al(l_create_statement, '                     );');
        al(l_create_statement, '        end if;');
        al(l_create_statement, '    end after each row;');
        al(l_create_statement, '');
        al(l_create_statement, '    -- AFTER STATEMENT');
        al(l_create_statement, '    after statement');
        al(l_create_statement, '    is');
        al(l_create_statement, '    begin');
        al(l_create_statement, '        flush_log;');
        al(l_create_statement, '    end after statement;');
        al(l_create_statement, '');
        al(l_create_statement, 'END ' || l_audit_trigger_end || ';');
        al(l_create_statement, '/');

        return l_create_statement;

    end create_tapi_trigger_statement;

    -- ================================================================================================
    -- ================================================================================================

    procedure print_max_vc2_list(p_vc_list in ta_max_vc2_list
                               , p_label   in varchar2 default 'Typ: ta_max_vc2_list'
                               , p_column  in number   default 0)
    is
        l_index  pls_integer;
    begin
        dbms_output.put_line(p_label);
        l_index := p_vc_list.first;
        while (l_index is not null)
        loop
            dbms_output.put_line('(' || to_char(l_index, 'FM00') || ')> ' ||
                case
                    when p_column is null or p_column < 1
                        then
                            '[' || p_vc_list(l_index) || ']'
                        else
                            '|' || rpad(p_vc_list(l_index), p_column) || '|' || substr(p_vc_list(l_index), p_column+1)
                end
                );
            l_index := p_vc_list.next(l_index);
        end loop;
    end print_max_vc2_list;

    -- ====================================================================================================
    -- ====================================================================================================

end PCK_TAPI_UTIL;
/

-- ====================================================================================================

set linesize 150
set pagesize 1000

column SEQUENCE format  990       heading SQ
column LINE     format 9990
column POSITION format  990       heading POS
column TEXT     format  a70 wrap
column MESSAGE_NUMBER format 00000 heading MSGNR

select ue.NAME, ue.TYPE, ue.SEQUENCE, ue.LINE, ue.POSITION, ue.TEXT, ue.ATTRIBUTE, ue.MESSAGE_NUMBER
  from user_errors ue
  where ue.name in ('PCK_TAPI_UTIL');
