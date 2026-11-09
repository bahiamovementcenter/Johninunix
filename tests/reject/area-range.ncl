# expect: is not a range like 10-19
let jd = import "../../nickel/johnny-decimal.ncl" in
jd.project {
  systems = [{ sys = "P76", title = "T", root = ".", areas = { "10-29" = { name = "A" } } }],
  extensions = {},
}
