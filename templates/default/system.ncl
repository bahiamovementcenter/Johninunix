# Your Johnny.Decimal system. In the development shell (`nix develop`),
# start nu, then:
#
#   use jd.nu
#   jd check         compare this file with your folders and extensions/
#   jd scaffold      create the folders and JDex notes declared here
#   jd write-config  write the config.json that jd reads
#
# The root starts in /tmp/johnnydecimal, so you can scaffold and try things
# without touching your real folders. Most systems clear /tmp when they
# restart, so move root and jdex to a lasting folder when you're ready.
# A path that starts with ~ is in your home folder; any other relative path
# is relative to this file. Scaffolding creates what's missing and never
# deletes.
let jd = import "johnny-decimal.ncl" in
jd.project {
  systems = [
    {
      sys = "P76",
      title = "Personal",
      root = "/tmp/johnnydecimal",
      # A folder of notes. For Obsidian, add app = "obsidian" and vault;
      # for a JDex in Bear, use { app = "bear" } and no path.
      jdex = { path = "/tmp/johnnydecimal/00-09 System/00 System/00.00 JDex" },
      default = true,
      areas = {
        "00-09" = {
          name = "System",
          categories = { "00" = { name = "System" } },
        },
        "10-19" = {
          name = "Life admin",
          categories = {
            "11" = { name = "Me" },
            "12" = { name = "House" },
          },
        },
      },
    },
  ],

  # One entry per extensions/*.sh, saying which of jd's functions it wraps
  # and which commands it adds. `jd check` compares them with the files.
  extensions = {},
}
