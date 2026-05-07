{ self, username, ... }:

{
  # Required nix-darwin system basics.
  system.primaryUser = username;
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Keep this stable after the first successful switch.
  # Read `darwin-rebuild changelog` before changing it later.
  system.stateVersion = 4;
}
