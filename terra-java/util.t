local P = {}

local C = require "terra-java/c"

-- Can't just write to stderr because the JVM will swallow it.
local LogName = int8[100]
terra logfile()
  var buf : LogName
  var filename = [&int8](&buf)
  var ret = C.snprintf(filename, sizeof(LogName),
                       "./terra-java_pid%d.log", C.getpid())
  if ret > 0 then
    return C.fopen(filename, "w")
  end
  return nil
end

--TODO: This should be a variadic terra function, not macro.
-- See <https://github.com/zdevito/terra/issues/169>.
P.fatal = macro(function(fmt, ...)
  local args = {...}
  return quote
    var f = logfile()
    C.fprintf(f, ["fatal: " .. fmt:asvalue() .. "\n"], args)
    C.fclose(f)
    C.abort()
  end
end)

function P.errorf(fmt, ...)
  fmt = fmt .. "\n"
  error(fmt:format(...), 2)
end

function P.popl(lst)
  local ret = {}
  for i = 2, #lst do
    ret[i - 1] = lst[i]
  end
  return ret
end

return P
