( ASCII chart ) decimal

: bar ."   |  " ;
: row ( n -- )
    base @ hex  over 3 .r bar  base !
    dup 128 + swap do  i bl < if  space  else  i emit  then  bar  16 +loop ;

: chart
    cr  3 spaces bar      8 0 do  i 0 .r bar   loop
    cr  3 spaces ."   +"  8 0 do  ." -----+"  loop
    16 0 do  cr i row  loop ;

chart

0 [IF]
     |  0  |  1  |  2  |  3  |  4  |  5  |  6  |  7  |  
     +-----+-----+-----+-----+-----+-----+-----+-----+
  0  |     |     |     |  0  |  @  |  P  |  `  |  p  |  
  1  |     |     |  !  |  1  |  A  |  Q  |  a  |  q  |  
  2  |     |     |  "  |  2  |  B  |  R  |  b  |  r  |  
  3  |     |     |  #  |  3  |  C  |  S  |  c  |  s  |  
  4  |     |     |  $  |  4  |  D  |  T  |  d  |  t  |  
  5  |     |     |  %  |  5  |  E  |  U  |  e  |  u  |  
  6  |     |     |  &  |  6  |  F  |  V  |  f  |  v  |  
  7  |     |     |  '  |  7  |  G  |  W  |  g  |  w  |  
  8  |     |     |  (  |  8  |  H  |  X  |  h  |  x  |  
  9  |     |     |  )  |  9  |  I  |  Y  |  i  |  y  |  
  A  |     |     |  *  |  :  |  J  |  Z  |  j  |  z  |  
  B  |     |     |  +  |  ;  |  K  |  [  |  k  |  {  |  
  C  |     |     |  ,  |  <  |  L  |  \  |  l  |  |  |  
  D  |     |     |  -  |  =  |  M  |  ]  |  m  |  }  |  
  E  |     |     |  .  |  >  |  N  |  ^  |  n  |  ~  |  
  F  |     |     |  /  |  ?  |  O  |  _  |  o  |     |
[THEN]
