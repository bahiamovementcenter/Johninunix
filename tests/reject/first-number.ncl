# expect: first_number is a whole number from 1 to 9999
let jd = import "../../nickel/johnny-decimal.ncl" in
jd.project {
  systems = [{ sys = "P76", title = "T", root = ".", work_packages = { first_number = 0 }, areas = { "10-19" = { name = "A" } } }],
  extensions = {},
}
