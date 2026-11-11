# Adds one of jd's own commands, a command twice, and a command whose
# function no extension defines
jd_command new _bad_new
jd_command twice _bad_twice
jd_command twice _bad_twice
jd_command orphan _bad_orphan
_bad_new() { :; }
_bad_twice() { :; }
