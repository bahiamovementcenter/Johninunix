# expect: two extensions wrap _jd_new
let jd = import "../../nickel/johnny-decimal.ncl" in
jd.project {
  systems = [{ sys = "P76", title = "T", root = ".", areas = { "10-19" = { name = "A" } } }],
  extensions = { "a.sh" = { description = "d", wraps = ["_jd_new"] }, "b.sh" = { description = "d", wraps = ["_jd_new"] } },
}
