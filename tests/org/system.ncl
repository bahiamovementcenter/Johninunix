# A system whose JDex is one Org file, for tests/org/test.nu
let jd = import "johnny-decimal.ncl" in
jd.project {
  systems = [
    {
      sys = "P76",
      title = "Personal",
      root = "root",
      jdex = { app = "org", path = "jdex.org" },
      default = true,
      standard_zeros = false,
      areas = {
        "10-19" = {
          name = "Life admin",
          categories = {
            "11" = { name = "Me", ids = { "11.11" = "Passport", "11.12" = "Bank" } },
            "12" = { name = "House" },
          },
        },
        "20-29" = { name = "Work", categories = { "21" = { name = "Clients" } } },
      },
    },
  ],
}
