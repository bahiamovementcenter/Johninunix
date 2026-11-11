# Extensions

Each `*.sh` here is loaded by jd before it runs a command. `jd_wrap FN`
wraps one of jd's functions, and `jd_command NAME FN` adds a command.
Work-package adapters go in `adapters/tasks/` and `adapters/notes/`.

Declare each extension in `system.ncl`. Building jd (`nix build`, or
entering the shell) fails if an extension wraps a function this jd doesn't
have, reuses one of jd's commands, or an adapter misses a function.

Examples: https://github.com/bahiamovementcenter/Johninunix/tree/main/example/extensions
