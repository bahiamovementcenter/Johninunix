# expect: is built into jd
let jd = import "../../nickel/johnny-decimal.ncl" in
jd.project {
  systems = [{ sys = "P76", title = "T", root = ".", areas = { "10-19" = { name = "A" } } }],
  extensions = { "x.sh" = { description = "d", commands = ["new"] } },
}
