{
  description = "A Nix flake for Amazon Music";

  inputs.erosanix.url = "github:emmanuelrosa/erosanix";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/master";

  outputs = { self, nixpkgs, erosanix }: {

    packages.x86_64-linux = let
      pkgs = import "${nixpkgs}" {
        system = "x86_64-linux";
      };

    in with (pkgs // erosanix.packages.x86_64-linux // erosanix.lib.x86_64-linux); {
      default = self.packages.x86_64-linux.AmazonMusic;

      AmazonMusic = callPackage ./AmazonMusic.nix {
        inherit mkWindowsApp makeDesktopIcon pkgs;

        wine = wineWowPackages.base;
      };
    };

    apps.x86_64-linux.AmazonMusic = {
      type = "app";
      program = "${self.packages.x86_64-linux.AmazonMusic}/bin/AmazonMusic";
    };

    apps.x86_64-linux.default = self.apps.x86_64-linux.AmazonMusic;
  };
}
