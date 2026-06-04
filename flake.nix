{
  description = "hybrid-ai development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;

      commonPackages = with pkgs; [
        bash
        coreutils
        git
        findutils
        gnused
        ripgrep
        jq
        yq
        just
        curl
      ];

      pythonToolPackages = with pkgs; [
        python311
        poetry
        uv
        libgcc
      ];

      swiftToolPackages = with pkgs; [
        swift
        swiftpm
        swiftPackages.XCTest
        cmake
      ];

      shellLibraryPath = lib.makeLibraryPath [ pkgs.libgcc ];

      sharedShellHook = ''
        export PROJECT_ROOT="$(pwd)"
        export PATH="${pkgs.python311}/bin:$PATH"

        export XDG_CONFIG_HOME="$PROJECT_ROOT/build/xdg/config"
        export XDG_CACHE_HOME="$PROJECT_ROOT/build/xdg/cache"
        export XDG_DATA_HOME="$PROJECT_ROOT/build/xdg/data"
        export XDG_STATE_HOME="$PROJECT_ROOT/build/xdg/state"
        export HOME="$PROJECT_ROOT/build/home"

        export SWIFT_BUILD_PATH="$PROJECT_ROOT/build/swift"
        export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/build/swift/clang-module-cache"
        export SWIFTPM_PACKAGECACHE="$PROJECT_ROOT/build/swift/package-cache"

        export CACTUS_MODEL_PATH="$PROJECT_ROOT/volumes/models/cactus"
        export LITERT_LM_MODELS="$PROJECT_ROOT/volumes/models/litert-lm"
        export HF_HOME="$PROJECT_ROOT/volumes/cache/huggingface"
        export TRANSFORMERS_CACHE="$PROJECT_ROOT/volumes/cache/transformers"

        export HYBRID_AI_DEVSHELL_CACHE="$PROJECT_ROOT/build/flake/cache"
        export PIP_CACHE_DIR="$HYBRID_AI_DEVSHELL_CACHE/pip-cache"
        export POETRY_CACHE_DIR="$HYBRID_AI_DEVSHELL_CACHE/poetry-cache"
        export UV_CACHE_DIR="$HYBRID_AI_DEVSHELL_CACHE/uv-cache"
        export PYTHONPYCACHEPREFIX="$HYBRID_AI_DEVSHELL_CACHE/pycache"
        export PIP_DISABLE_PIP_VERSION_CHECK=1
        export PYTHONDONTWRITEBYTECODE=1
        export POETRY_VIRTUALENVS_CREATE=false
        export LD_LIBRARY_PATH="${shellLibraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

        mkdir -p \
          "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
          "$HOME" \
          "$SWIFT_BUILD_PATH" "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_PACKAGECACHE" \
          "$CACTUS_MODEL_PATH" "$LITERT_LM_MODELS" "$HF_HOME" "$TRANSFORMERS_CACHE" \
          "$PIP_CACHE_DIR" "$POETRY_CACHE_DIR" "$UV_CACHE_DIR" "$PYTHONPYCACHEPREFIX" \
          "$PROJECT_ROOT/build/artifacts" "$PROJECT_ROOT/volumes/logs" "$PROJECT_ROOT/deps/libs" "$PROJECT_ROOT/deps/models"
      '';
    in {
      devShells.${system} = {
        default = pkgs.mkShell {
          packages = commonPackages ++ pythonToolPackages ++ swiftToolPackages;

          shellHook = sharedShellHook + ''
            source "$PROJECT_ROOT/scripts/env/toolchain/swift_env.sh"
            hybrid_ai_activate_swift_env

            echo "Entered hybrid-ai fullstack devShell"
            echo "swift=$(command -v swift)"
            echo "clang=$(command -v clang)"
            echo "python=$(command -v python)"
          '';
        };

        swift = pkgs.mkShell {
          packages = commonPackages ++ swiftToolPackages;

          shellHook = sharedShellHook + ''
            source "$PROJECT_ROOT/scripts/env/toolchain/swift_env.sh"
            hybrid_ai_activate_swift_env

            echo "Entered hybrid-ai Swift devShell"
            echo "swift=$(command -v swift)"
            echo "clang=$(command -v clang)"
          '';
        };

        python = pkgs.mkShell {
          packages = commonPackages ++ pythonToolPackages;

          shellHook = sharedShellHook + ''
            echo "Entered hybrid-ai Python devShell"
            echo "python=$(command -v python)"
            echo "poetry=$(command -v poetry)"
          '';
        };
      };
    };
}