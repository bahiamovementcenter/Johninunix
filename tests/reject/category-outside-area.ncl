# expect: category '21' is not in area 10-19
let jd = import "../../nickel/johnny-decimal.ncl" in
jd.project {
  systems = [{ sys = "P76", title = "T", root = ".", areas = { "10-19" = { name = "A", categories = { "21" = { name = "C" } } } } }],
  extensions = {},
}
