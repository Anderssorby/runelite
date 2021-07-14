{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      inherit (pkgs) stdenv;
      name = "runelite";
      root = ./.;
      dependencies = pkgs.buildMaven ./project-info.json;
      repository = stdenv.mkDerivation {
        name = "maven-repository";
        buildInputs = with pkgs; [ maven ];
        src = root; # or fetchFromGitHub, cleanSourceWith, etc
        buildPhase = ''
          mvn package -Dmaven.repo.local=$out -DskipTests
        '';

        # keep only *.{pom,jar,sha1,nbm} and delete all ephemeral files with lastModified timestamps inside
        installPhase = ''
          find $out -type f \
            -name \*.lastUpdated -or \
            -name resolver-status.properties -or \
            -name _remote.repositories \
            -delete
        '';

        # don't do any fixup
        dontFixup = true;
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        # replace this with the correct SHA256
        outputHash = "sha256-37PV2zDuE3K0pNCmqsqWgpJX1z3LWjwJYe52e1q7euU=";
      };
      jarname = "client";
      jre = pkgs.jre;
      project = stdenv.mkDerivation rec {
        pname = name;
        # This needs to be updated
        version = "1.7.15-SNAPSHOT";

        src = root;
        buildInputs = with pkgs; [ maven makeWrapper ];

        buildPhase = ''
          echo "Using repository ${repository}"
          mvn --offline -Dmaven.repo.local=${repository} package -DskipTests
        '';

        installPhase = ''
          mkdir -p $out/bin

          # create a symbolic link for the repository directory
          ln -s ${repository} $out/repository
          
          install -Dm644 runelite-client/target/${jarname}-${version}.jar $out/share/java/${jarname}-${version}.jar

          # create a wrapper that will automatically set the classpath
          # this should be the paths from the dependency derivation
          makeWrapper ${jre}/bin/java $out/bin/${pname} \
            --add-flags "-jar $out/share/java/${jarname}-${version}.jar"
        '';
      };
      buildInputs = with pkgs; [
        jdk maven
      ];
    in
    {
      packages.${name} = project;

      defaultPackage = self.packages.${system}.${name};

      apps.${name} = flake-utils.mkApp {
        drv = project;
      };

      # `nix develop`
      devShell = pkgs.mkShell {
        inputsFrom = builtins.attrValues self.packages.${system};
        buildInputs = with pkgs; buildInputs ++ [
        ];
      };
    });
}
