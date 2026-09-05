# The dev-rails checker, packaged.
#
# Lives in its own file so flake.nix references it in a single line, which is
# what create-python-project.sh rewrites: a generated project consumes this
# same derivation from the pythonproject flake input instead of vendoring a
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
