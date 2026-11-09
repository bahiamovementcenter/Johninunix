# expect: reserved by the standard zeros
let jd = import "../../nickel/johnny-decimal.ncl" in
jd.project {
  systems = [{ sys = "P76", title = "T", root = ".", areas = { "10-19" = { name = "A", categories = { "11" = { name = "C", ids = { "11.07" = "X" } } } } } }],
  extensions = {},
}
