# The official Johnny.Decimal command-line tool (jd). It isn't packaged in
# Nixpkgs, so it's fetched at a pinned revision and wrapped so that jq is
# always on its PATH.
#
# `jd.withExtensions ./extensions` adds your own extensions: every
# `extensions/*.sh` is loaded by jd before it runs a command (see jd-ext.sh),
# and `extensions/adapters/{tasks,notes}/*.sh` are installed as work-package
# adapters.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  jq,
}:

let
  upstream = {
    owner = "johnnydecimal";
    repo = "cli.johnnydecimal.com";
    rev = "863d2e6412b70c385db8bdbcd6e1b3e28e6048f4";
    hash = "sha256-jM0nlEJACeE+5Ojluwpd4Hwkfyvn1Ppnzhqc85PFqtA=";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "jd";
  version = "4.4.0";

  src = fetchFromGitHub upstream;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  # A folder of extensions; set by withExtensions
  extensions = null;

  installPhase = ''
    runHook preInstall

    cli=$out/share/johnnydecimal/cli
    mkdir -p $cli $out/bin
    cp -r . $cli

    # Load extensions once jd's own functions are defined, just before it
    # runs the command. --replace-fail stops the build if upstream changes
    # that line.
    install -m 644 ${./jd-ext.sh} $cli/lib/ext.sh
    substituteInPlace $cli/bin/jd \
      --replace-fail '_jd_nav "$_jd_sys" "$@"' '. "$_JD_CLI_DIR/lib/ext.sh"; _jd_nav "$_jd_sys" "$@"'

    ${lib.optionalString (finalAttrs.extensions != null) ''
      mkdir -p $cli/lib/ext
      for f in ${finalAttrs.extensions}/*.sh; do
        [ -e "$f" ] && install -m 644 "$f" $cli/lib/ext/
      done
      if [ -d ${finalAttrs.extensions}/adapters ]; then
        cp -r ${finalAttrs.extensions}/adapters/. $cli/lib/adapters/
        chmod -R u+w $cli/lib/adapters
      fi
    ''}

    makeWrapper $cli/bin/jd $out/bin/jd \
      --prefix PATH : ${lib.makeBinPath [ jq ]}

    runHook postInstall
  '';

  passthru = {
    inherit upstream;
    withExtensions = extensions: finalAttrs.finalPackage.overrideAttrs { inherit extensions; };
  };

  meta = {
    description = "The Johnny.Decimal command-line tool";
    homepage = "https://github.com/johnnydecimal/cli.johnnydecimal.com";
    license = lib.licenses.mit;
    mainProgram = "jd";
  };
})
