# The dev-rails checker, packaged.
#
# Exposed as the flake's `check-rails` package. Generated projects consume this
# same derivation from their pythonproject flake input instead of vendoring a
# copy, so there is one definition of the rails across every project.
#
# `${./.}` is this directory, so check_rails.py and rails-spec.toml land in the
# store together -- the script reads the spec from its own directory.

{ pkgs }:

pkgs.writeShellApplication {
  name = "check-rails";
  runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
  text = ''
    exec python3 ${./.}/check_rails.py "$@"
  '';
}
