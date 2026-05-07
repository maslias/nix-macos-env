{ ... }:

{
  # This machine uses Determinate Nix, which manages the Nix daemon itself.
  # nix-darwin must not also try to manage the Nix installation.
  nix.enable = false;
}
