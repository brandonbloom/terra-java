return terralib.includecstring [[
  #include <stdio.h>
  #include <stdlib.h>

  FILE *getstderr() { return stderr; }
]]
