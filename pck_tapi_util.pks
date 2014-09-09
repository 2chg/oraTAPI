set define off;

prompt
prompt * Creating Package Specification PCK_TAPI_UTIL ...

create or replace package PCK_TAPI_UTIL
authid current_user
as
    /**
     * Routinen für die Erstellung und Verwendung von Table-API (etwa für Table Auditing).
     *
     * Hinweis: Auf das <pre>get_</pre>-Präfix für Funktionsnamen wird generell verzichtet.
     *
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
     *
     * @headcom
     */

    /**
     * <strong>Konstante</strong>: MAJOR-Versionsnummer ([XX].yy.zz) dieses
     * Packages und damit der erzeugten Table-API.
     *
     * (Semantic Versioning 2.0.0 http://semver.org/)
     */
    k_tapi_version_MAJOR constant pls_integer := 0;

    /**
     * <strong>Konstante</strong>: MINOR-Versionsnummer (xx.[YY].zz) dieses
     * Packages und damit der erzeugten Table-API.
     */
    k_tapi_version_MINOR constant pls_integer := 0;

    /**
     * <strong>Konstante</strong>: PATCH-Stand (xx.yy.[ZZ]) dieses
     * Packages und damit der erzeugten Table-API.
     */
    k_tapi_version_PATCH constant pls_integer := 0;

    /* ******************************************************************** *\
    |* ************************** CONFIGURATION *************************** *|
    \* ******************************************************************** */

    /**
     * <strong>Konstante</strong>: Prefix für die Meta-Daten-Spalten der Audit-Tabellen
     */
    k_audit_column_prefix constant varchar2(30) := 'JN_';

    /**
     * <strong>Konstante</strong>: Maximale Länge des variablen Teils des Namens Meta-Daten-Spalten einer Audit-Tabelle
     */
    k_audit_column_signif_name_len constant integer := 30 - coalesce(length(k_audit_column_prefix), 0);

    /**
     * <strong>Konstante</strong>: Prefix für den Namen der Audit-Tabelle
     */
    k_audit_table_prefix constant varchar2(30) := null;

    /**
     * <strong>Konstante</strong>: Suffix für den Namen der Audit-Tabelle
     */
    k_audit_table_suffix constant varchar2(30) := '_AUD';

    /* ******************************************************************** *\
    |* ************************ CONFIGURATION END ************************* *|
    \* ******************************************************************** */

    /**
     * <strong>Konstante</strong>: Maximale Länge des variablen Teils des Namens einer Audit-Tabelle
     */
    k_audit_table_signif_name_len constant integer := 30 - coalesce(length(k_audit_table_prefix), 0) - coalesce(length(k_audit_table_suffix), 0);

    /**
     * <strong>Konstante</strong>: Zeilenvorschub (Newline)
     */
    NL constant varchar2(2) := chr(10);

    /**
     * Gibt die Versionsnummer der Packages in der Form MAJOR.MINOR.PATCH
     * zurück.
     *
     * @return Versionsnummer der Packages
     */
    function get_version
        return varchar2;

    -- --------------------------------------------------------------------------------

    /**
     * Datentyp für Flags (Ersatz BOOLEAN etwa in SQL: 0 = FALSE, 1 = TRUE).
     */
    subtype t_flag is pls_integer range 0..1;

    /**
     * Datentyp für maximal lange varchar2-Variablen in PL/SQL.
     *
     * Hinweis: So lange Zeichenketten sind nur in <code>PL/SQL</code>, nicht aber in reinem <code>SQL</code> möglich!
     */
    subtype t_max_vc2 is varchar2(32767);

    /**
     * Datentyp für maximal lange varchar2-Variablen in SQL.
     */
    subtype t_max_vc2_sql is varchar2(4000);

    /**
     * Datentyp für ein assozaitives Array aus varchar2.
     */
    type ta_max_vc2_list is table of t_max_vc2
        index by pls_integer;

    -- --------------------------------------------------------------------------------

    /**
     * Führt das übergebene Statement (ohne weitere Fehlerbehandlung!) in einer
     * autonomen Transaktion aus.
     *
     * @param p_statement          Das als autonome Transaktion auszuführende Statement
     * @param p_ignore_exceptions  Sollen auftretende Exceptions stillschweigend ignoriert werden?
     * @param p_do_commit          Soll zum Schluss ein automatisches COMMIT abgesetzt werden?
     * @param p_async_commit       Darf das COMMIT auch im Hintergrund abgeschlossen werden?
     */
    procedure autonomous_execute_immediate(p_statement         in varchar2
                                         , p_ignore_exceptions in boolean default false
                                         , p_do_commit         in boolean default true
                                         , p_async_commit      in boolean default false);

    -- --------------------------------------------------------------------------------

    /**
     * Erzeugt ein CREATE-TABLE-Statement für eine zur angegebenen Grund-Tabelle Audit-Tabelle
     *
     * @param p_base_table_owner  Besiter der Grund-Tabelle
     * @param p_base_table_name   Name der Grund-Tabelle
     * @return Das CREATE-TABLE-Statement für die Audit-Tabelle
     */
    function create_audit_table_statement(p_base_table_owner in varchar2
                                        , p_base_table_name  in varchar2)
        return varchar2;

    /**
     * Erzeugt ein CREATE-Statement für den TAPI-Trigger zur angegebenen Grund-Tabelle
     *
     * @param p_base_table_owner            Besiter der Grund-Tabelle
     * @param p_base_table_name             Name der Grund-Tabelle
     * @param p_id_sequence_name            ...
     * @param p_id_column_name              ...
     * @param p_delete_logs_old_data        ...
     * @param p_audit_bulk_insert_threshold ...
     * @return Das CREATE-TABLE-Statement für den TAPI-Trigger
     */
    function create_tapi_trigger_statement(p_base_table_owner            in varchar2
                                         , p_base_table_name             in varchar2
                                         , p_id_sequence_name            in varchar2       default null
                                         , p_id_column_name              in varchar2       default null
                                         , p_delete_logs_old_data        in boolean        default false
                                         , p_audit_bulk_insert_threshold in simple_integer default 1000)
        return clob;

    /**
     * Hilfsroutine (insbesondere für die Entwicklung) um sich schnell den Inhalt
     * eines assoziativen Arrays vom Typ ta_max_vc2_list ausgeben zu lassen.
     * Dabei kann optional ein Titel ausgegeben und/oder eine maximale Zeilenlänge
     * markiert werden.
     *
     * @param p_vc_list  das auszugebende assoziative Array
     * @param p_label    optionaler Titel/Überschrift der Ausgabe
     * @param p_column   optionale Zeilenlänge, die gekennzeichnet werden soll
     */
    procedure print_max_vc2_list(p_vc_list in ta_max_vc2_list
                               , p_label   in varchar2 default 'Typ: ta_max_vc2_list'
                               , p_column  in number   default 0);

    -- ================================================================================================

end PCK_TAPI_UTIL;
/

-- ====================================================================================================

-- create or replace public synonym PCK_TAPI_UTIL for PCK_TAPI_UTIL;
--
-- -- Kürzerer Alias
-- create or replace public synonym PTU for PCK_TAPI_UTIL;

grant EXECUTE on PCK_TAPI_UTIL to PUBLIC with GRANT OPTION;

-- ====================================================================================================

@@ pck_tapi_util.pkb
