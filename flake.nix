{
  description = "Payment Hub Developer Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Pinned nixpkgs commits for specific tool versions
    nixpkgs-python.url = "github:NixOS/nixpkgs/55070e598e0e03d1d116c49b9eff322ef07c6ac6"; # Python 3.10.9
    nixpkgs-nodejs.url = "github:NixOS/nixpkgs/0c19708cf035f50d28eb4b2b8e7a79d4dc52f6bb"; # Node.js 22.0.0
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-python, nixpkgs-nodejs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        pkgs-python = import nixpkgs-python {
          inherit system;
          config.allowUnfree = true;
        };

        pkgs-nodejs = import nixpkgs-nodejs {
          inherit system;
          config.allowUnfree = true;
        };

        python = pkgs-python.python310;
        nodejs = pkgs-nodejs.nodejs_22;

        # System dependencies for Python packages (e.g., psycopg2, bitcoinlib, orjson)
        buildInputs = with pkgs; [
          stdenv.cc.cc.lib
          gmp
          zlib
          postgresql_15
          openssl
          libffi
        ];

        nativeBuildInputs = [
          python
          nodejs
          pkgs.postgresql_15
          pkgs.redis
          pkgs.mosquitto
          pkgs.docker-compose
          pkgs.git
          pkgs.pkg-config
          pkgs.python3Packages.python-lsp-server
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          inherit buildInputs nativeBuildInputs;

          shellHook = ''
            # Create a local directory for service data if using direnv/nix-shell
            mkdir -p .direnv

            # Set up Python virtual environment
            if [ ! -d ".venv" ]; then
              echo "Creating virtual environment..."
              ${python}/bin/python -m venv .venv
            fi
            source .venv/bin/activate

            # Update pip and install requirements
            echo "Checking Python dependencies..."
            pip install --upgrade pip

            # Install dev tools to venv (not in requirements.txt)
            echo "Ensuring dev tools are installed..."
            pip install fabric pylint pylint-django pylint-venv django-types django

            # Node.js dependencies for Tailwind
            if [ -d "theme/static_src" ]; then
              echo "Checking Node.js dependencies..."
              pushd theme/static_src > /dev/null
              if [ ! -d "node_modules" ]; then
                npm install
              fi
              popd > /dev/null
            fi

            # Environment variables for linking libraries
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH"
            
            # Useful aliases for Django development
            alias runserver="./manage.py runserver"
            alias migrate="./manage.py migrate"
            alias makemigrations="./manage.py makemigrations"
            alias tailwind="./manage.py tailwind start"

            echo ""
            echo "Payment Hub Dev Environment Ready!"
            echo "Python: $(python --version)"
            echo "Node.js: $(node --version)"
            echo "PostgreSQL: $(postgres --version)"
            echo "Redis: $(redis-server --version)"
            echo ""
            echo "Run 'runserver' to start Django, or 'tailwind' for frontend assets."
          '';
        };
      }
    );
}

