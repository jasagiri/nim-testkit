# Override panic for tests

{.push exportc.}

proc rawoutput*(msg: cstring) =
  # For tests, do nothing
  discard

{.pop.}

{.push exportc, noreturn.}

proc panic*(msg: cstring) =
  # For tests, do nothing
  while true: discard
  
proc rawQuit*(code: int) =
  # For tests, do nothing
  while true: discard

{.pop.}