( Test suite )

[UNDEFINED] TESTING [IF]  include test/tester.f  [THEN]

VERBOSE ON
: FAILED [COMPILE] \ ; ( to mark tests that fail )

include test/core.fr
\  include test/coreexttest.fth
\  include test/coreplustest.fth
\  include test/strings.f
\  include test/stringtest.fth
\  include test/localstest.f
\  include ./pathtest.f
\  include test/exceptiontest.fth

decimal
CR .TESTS
#ERRORS @ [IF]  1 0 BIOS  [THEN]
