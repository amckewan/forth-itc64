( Test suite )

[undefined] testing [if]  include test/tester.f  [then]

VERBOSE ON

include test/core.fr
include test/coreplustest.fth
include test/stringtest.fth
include test/exceptiontest.fth

\  include test/coreexttest.fth
\  include test/localstest.f
\  include ./pathtest.f

decimal
CR .TESTS
#ERRORS @ [IF]  1 0 BIOS  [THEN]
