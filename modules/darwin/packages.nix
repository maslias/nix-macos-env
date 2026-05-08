{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # General CLI/admin tools
    age
    bat
    curl
    fd
    git
    lsof
    ncdu
    openssh
    picocom
    ripgrep
    sops
    tldr
    tmux

    # DNS/network diagnostics
    bind # provides dig and nslookup
    docker-compose
    iperf3
    mtr
    netcat-gnu
    nmap
    tcpdump

    # GUI apps available in nixpkgs
    obsidian

    (writeShellApplication {
      name = "macos-privacy-check";
      text = builtins.readFile ../../scripts/macos-privacy-check.sh;
    })
  ];
}
