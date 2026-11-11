# The official Johnny.Decimal command-line tool (jd). It isn't packaged in
# Nixpkgs. Its source is the flake's `jd-src` input, pinned in flake.lock,
# and it's wrapped so that jq is always on its PATH. The wrapper also turns
# off jd's daily check for a newer version: this copy is in the Nix store,
# not a git clone, so `jd update` can't apply one.
#
# The package also holds this repository's Nickel contracts and Nushell
# module, which match this jd:
#
#   share/johnnydecimal/nickel/  johnny-decimal.ncl, for NICKEL_IMPORT_PATH
#   share/johnnydecimal/nu/      jd.nu, for NU_LIB_DIRS
#
# `jd.withExtensions ./extensions` adds your own extensions: every
# `extensions/*.sh` is loaded by jd before it runs a command (see jd-ext.sh),
# and `extensions/adapters/{tasks,notes}/*.sh` are installed as work-package
# adapters. The build fails if one of them doesn't fit this jd (see
# check-extensions.sh).
{
  lib,
  stdenvNoCC,
  makeWrapper,
  applyPatches,
  jq,
  # jd's source: a checkout of johnnydecimal/cli.johnnydecimal.com
  src,
  # Changes to jd's own files, applied to src before anything reads it:
  # jdex-store.patch makes the JDex app pluggable (lib/adapters/jdex/);
  # wp-numbers.patch keeps work packages off W0003 and W0009, and reads
  # workPackages.firstNumber (system.ncl sets it to 11)
  patches ? [
    ./jdex-store.patch
    ./wp-numbers.patch
  ],
}:

let
  upstreamSrc = src;
  # jd's source as this package builds it: the patches, then this
  # repository's own adapters and templates (the Org JDex store and its
  # work package links), so that they're among jd's built-in ones
  patched = applyPatches {
    name = "jd-src-patched";
    src = upstreamSrc;
    inherit patches;
    postPatch = ''
      cp -r ${./adapters}/. lib/adapters/
      cp -r ${./templates}/. templates/
    '';
  };
  # bin/jd sets the version, and nothing else does
  version = lib.head (
    lib.findFirst (m: m != null) (throw "jd: bin/jd sets no _JD_CLI_VERSION") (
      map (builtins.match ''_JD_CLI_VERSION="([^"]+)"'') (
        lib.splitString "\n" (builtins.readFile "${upstreamSrc}/bin/jd")
      )
    )
  );
  upstream = {
    owner = "johnnydecimal";
    repo = "cli.johnnydecimal.com";
    rev = upstreamSrc.rev or "unknown";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "jd";
  inherit version;
  src = patched;

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
      --prefix PATH : ${lib.makeBinPath [ jq ]} \
      --set-default JD_NO_UPDATE_CHECK 1

    # The contracts and the Nushell module, side by side as in the
    # repository: jd.nu finds the contracts at ../nickel
    share=$out/share/johnnydecimal
    mkdir -p $share/nickel $share/nu
    cp -r ${../../nickel}/. $share/nickel/
    cp ${../../nu/jd.nu} $share/nu/jd.nu

    runHook postInstall
  '';

  # Load the extensions into the installed jd and check them against it
  doInstallCheck = finalAttrs.extensions != null;
  installCheckPhase = lib.optionalString (finalAttrs.extensions != null) ''
    runHook preInstallCheck
    bash ${./check-extensions.sh} $out ${finalAttrs.extensions}
    runHook postInstallCheck
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
