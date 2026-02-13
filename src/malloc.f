( Dynamic memory allocation using BIOS )

: ALLOCATE  ( n -- a ior )      $20 BIOS ;
: RESIZE    ( a n -- a' ior )   $21 BIOS ;
: FREE      ( a -- ior )        $22 BIOS ;
