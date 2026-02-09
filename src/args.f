\ Process command-line arguments
\
\ -e <string>   evaluate string
\ <filename>    include file

: doargs
    1 begin dup argc < while
        dup >r argv
        over c@ '-' = if  1 /string
            over c@ 'e' = if
                r> 1+ dup >r  argc < if
                    r@ argv \ evaluate
                    cr ." evaluate '" type ." '"             
                then
            else
                cr ." unknown option -" over c@ emit cr
            then
            2drop
        else
            cr ." include " type
            \ included
        then
        r> 1+
    repeat drop ;
