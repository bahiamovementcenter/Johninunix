# An example Johnny.Decimal system. The development shell points JD_SYSTEM
# here, so in nu, after `use jd.nu`:
#
#   jd project       evaluate this file (Nickel checks it first)
#   jd write-config  write the config.json that jd reads
#   jd scaffold      create the folders and JDex notes declared here
#   jd check         compare this file with the folders and extensions/
#
# Relative paths are relative to this file, so the system's folders and its
# JDex are created in example/. Its extensions are in example/extensions/.
# The contracts are in nickel/johnny-decimal.ncl: jd.nu, and the shell's
# NICKEL_IMPORT_PATH, tell Nickel where to find them.
let jd = import "johnny-decimal.ncl" in
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

  # One entry per file in example/extensions/, saying what it touches
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
