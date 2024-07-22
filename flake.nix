{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # nixos 23.05
        pkgs = import nixpkgs {
          system = system;
          config.allowUnfree = false;
        };

        export_templates_tpz =pkgs.fetchurl {
          url = "https://github.com/godotengine/godot/releases/download/4.2.2-stable/Godot_v4.2.2-stable_export_templates.tpz";
          hash = "sha256-HbmM6B83xhO5SJGlr6pnoHX9GkN0UbRwglGKwrGCtjE=";
        };

        export_templates = pkgs.stdenv.mkDerivation {
          name = "Godot 4.2.2-stable export templates";
          src = export_templates_tpz;
          nativeBuildInputs = [pkgs.unzip];
          dontUnpack = true;
          buildPhase = ''
            unzip $src
          '';
          installPhase = ''
            cp -r ./templates $out
          '';
        };

        game = pkgs.stdenv.mkDerivation {
          name = "Bornhack 2024 Gamejam";
          src = ./.;
          nativeBuildInputs = [ pkgs.unzip pkgs.godot_4 ];
          buildPhase = ''
            # set up fake home for godot
            mkdir -p fakehome
            HOME=./fakehome

            # make dirs that need to be here
            # otherwise godot just crashes
            mkdir -p ./fakehome/.config/godot/feature_profiles
            mkdir -p ./fakehome/.cache/godot

            # move in export templates
            mkdir -p ./fakehome/.local/share/godot/export_templates/
            cp -r ${export_templates} ./fakehome/.local/share/godot/export_templates/4.2.2.stable

            # build game
            mkdir -p ./build
            godot4 --headless --export-debug "Web" ./build/index.html
          '';
          installPhase = ''
            mv ./build $out
          '';
        };

        caddyFile = httpPort: httpsPort: pkgs.writeText "Caddyfile" ''
          {
              http_port ${httpPort}
              https_port ${httpsPort}
          }

          https:// {
              tls internal {
                  on_demand
              }
              header {
                  Cross-Origin-Opener-Policy same-origin
                  Cross-Origin-Embedder-Policy require-corp
              }
              root * ${game}
              file_server
          }
        '';

        serve_command = httpPort: httpsPort: ''
          ${pkgs.caddy}/bin/caddy run --adapter caddyfile --config ${caddyFile httpPort httpsPort}
        '';

        serve = pkgs.writeShellScriptBin "serve" (serve_command "8080" "1337");

      in {
        packages.default = game;
        apps.default = flake-utils.lib.mkApp { drv = serve; };
        checks = {inherit game;};
      });
}
