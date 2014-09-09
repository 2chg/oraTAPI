create or replace package ut_PCK_TAPI_UTIL
is

    -- -------------------------------------------------------------------------------- --
    -- --                     UNIT-TEST-Package für PCK_TAPI_UTIL                    -- --
    -- -------------------------------------------------------------------------------- --
    -- --               Erstellt am 29.8.2014 von Christian Heß-Grünig               -- --
    -- -------------------------------------------------------------------------------- --
    -- -- Dieses Package dient nur als Test-Hilfsmittel für die Entwicklung und muss -- --
    -- -- nicht im Produktivsystem eingespielt werden.                               -- --
    -- -------------------------------------------------------------------------------- --

    procedure ut_setup;
    procedure ut_teardown;

    -- Methoden-Tests
    procedure ut_CREATE_AUDIT_TABLE;
    procedure ut_CREATE_TAPI_TRIGGER;

end ut_PCK_TAPI_UTIL;
/

@@ ut_pck_tapi_util.pkb
