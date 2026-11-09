# Your Johnny.Decimal system. In nu, after `use nu/jd.nu`:
#
#   jd project       evaluate this file (Nickel checks it first)
#   jd write-config  write the config.json that jd reads
#   jd scaffold      create the folders and JDex notes declared here
#   jd check         compare this file with the folders and extensions/
#
# Relative paths are relative to this file. The contracts are in
# nickel/johnny-decimal.ncl.
let jd = import "nickel/johnny-decimal.ncl" in
jd.project {
  systems = [
    {
      sys = "P76",
      title = "Personal",
      root = ".",
      jdex = { path = "jdex" },
      default = true,
      areas = {
        "10-19" = {
          name = "Life admin",
          categories = {
            "11" = { name = "Me", ids = { "11.11" = "Passport" } },
            "12" = { name = "House" },
          },
        },
      },
    },
  ],

  # One entry per file in extensions/, saying what it touches
  extensions = {
    "stats.sh" = {
      description = "jd stats: how many IDs each area has",
      commands = ["stats"],
    },
    "autocommit.sh" = {
      description = "With JD_AUTOCOMMIT=1, commit the JDex after jd new",
      wraps = ["_jd_new"],
    },
  },
}
