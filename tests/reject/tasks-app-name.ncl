# expect: an app is a name of a-z, 0-9, _ and -
let jd = import "../../nickel/johnny-decimal.ncl" in
jd.project {
  systems = [{ sys = "P76", title = "T", root = ".", work_packages = { tasks = { app = "Things" } }, areas = { "10-19" = { name = "A" } } }],
  extensions = {},
}
