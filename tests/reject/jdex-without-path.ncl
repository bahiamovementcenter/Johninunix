# expect: a jdex needs a path, unless its app is bear
let jd = import "../../nickel/johnny-decimal.ncl" in
jd.project {
  systems = [{ sys = "P76", title = "T", root = ".", jdex = { app = "obsidian" }, areas = { "10-19" = { name = "A" } } }],
  extensions = {},
}
