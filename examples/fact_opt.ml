let rec fact (n : int) : int =
  if n > 1 then
    n * (fact (n-1))
  else
    1
    in
print_int(fact 5)
