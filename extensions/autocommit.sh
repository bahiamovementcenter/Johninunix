# With JD_AUTOCOMMIT=1, commit the JDex after 'jd new' creates something in
# it, when the JDex is a git repository. Off by default: it writes commits.
jd_wrap _jd_new

_jd_new() {
  local status
  _jd_new__orig "$@"
  status=$?
  # 3 is success too: jd asks the shell to cd into the new folder
  if [ "${JD_AUTOCOMMIT-}" = 1 ] && [ "$_JD_NEW_DRY" != 1 ] && { [ $status = 0 ] || [ $status = 3 ]; } \
    && [ -n "${_JD_NEW_JDEX-}" ] && git -C "$_JD_NEW_JDEX" rev-parse --git-dir >/dev/null 2>&1; then
    # stdout is jd's result, so git only writes to stderr
    git -C "$_JD_NEW_JDEX" add -A >&2 &&
      git -C "$_JD_NEW_JDEX" commit -q -m "jd new: $_JD_NEW_NAME" >&2
  fi
  return $status
}
