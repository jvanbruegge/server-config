{ lib
, pkgs
, buildNpmPackage
, fetchFromGitHub
, fetchPypi
, python3
, nodejs
, nixosTests
# build-time deps
, pkg-config
, makeWrapper
, cmake
# runtime deps
, ffmpeg
, imagemagick
, libraw
, vips
}:
let
  buildNpmPackage' = buildNpmPackage.override { inherit nodejs; };
  sources = lib.importJSON ./sources.json;
  inherit (sources) version;

  src = fetchFromGitHub {
    owner = "immich-app";
    repo = "immich";
    rev = "v${version}";
    inherit (sources) hash;
  };

  openapi = buildNpmPackage' {
    pname = "immich-openapi-sdk";
    inherit version;
    src = "${src}/open-api/typescript-sdk";
    inherit (sources.components."open-api/typescript-sdk") npmDepsHash;

    installPhase = ''
      runHook preInstall

      npm config delete cache
      npm prune --omit=dev --omit=optional

      mkdir -p $out
      mv package.json package-lock.json node_modules build $out/

      runHook postInstall
    '';
  };

  cli = buildNpmPackage' {
    pname = "immich-cli";
    inherit version;
    src = "${src}/cli";
    inherit (sources.components.cli) npmDepsHash;

    nativeBuildInputs = [
      makeWrapper
    ];

    preBuild = ''
      rm node_modules/@immich/sdk
      ln -s ${openapi} node_modules/@immich/sdk
      # Rollup does not find the dependency otherwise
      ln -s node_modules/@immich/sdk/node_modules/@oazapfts node_modules/
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      mv package.json package-lock.json node_modules dist $out/

      ls $out/dist

      makeWrapper ${nodejs}/bin/node $out/bin/immich-cli --add-flags $out/dist/index.js

      runHook postInstall
    '';
  };

  web = buildNpmPackage' {
    pname = "immich-web";
    inherit version;
    src = "${src}/web";
    inherit (sources.components.web) npmDepsHash;

    nativeBuildInputs = [
      makeWrapper
    ];

    inherit (cli) preBuild;

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      mv package.json package-lock.json node_modules build $out/

      makeWrapper ${nodejs}/bin/node $out/bin/immich-web --add-flags $out/build/index.js

      runHook postInstall
    '';
  };

  machine-learning = python3.pkgs.buildPythonApplication {
    pname = "immich-machine-learning";
    inherit version;
    src = "${src}/machine-learning";
    format = "pyproject";

    postPatch = ''
      rm poetry.lock

      # opencv is named differently, also remove development dependencies not needed at runtime
      substituteInPlace pyproject.toml \
        --replace 'opencv-python-headless = ">=4.7.0.72,<5.0"' "" \
        --replace 'setuptools = "^68.0.0"' 'setuptools = "*"' \
        --replace 'pydantic = "^1.10.8"' ""
    '';

    nativeBuildInputs = with python3.pkgs; [
      pythonRelaxDepsHook
      poetry-core
      cython
      makeWrapper
    ];

    propagatedBuildInputs = with python3.pkgs; [
      insightface
      opencv4
      pillow
      fastapi
      uvicorn
      aiocache
      rich
      ftfy
      setuptools
      python-multipart
      orjson
      gunicorn
      huggingface-hub
      tokenizers
    ] ++ python3.pkgs.uvicorn.optional-dependencies.standard;

    /*nativeCheckInputs = with python3.pkgs; [
      pytestCheckHook
      pytest-asyncio
      pytest-mock
      httpx
      pydantic
    ];*/
    doCheck = false;

    postInstall = ''
      mkdir -p $out/share
      cp log_conf.json $out/share
      makeWrapper ${python3.pkgs.gunicorn}/bin/gunicorn $out/bin/machine-learning \
        --prefix PYTHONPATH : "$PYTHONPATH" \
        --add-flags "app.main:app -k uvicorn.workers.UvicornWorker \
          -w \"\$MACHINE_LEARNING_WORKERS\" \
          -b \"\$MACHINE_LEARNING_HOST:\$MACHINE_LEARNING_PORT\" \
          -t \"\$MACHINE_LEARNING_WORKER_TIMEOUT\" \
          --log-config-json $out/share/log_conf.json"
    '';

    preCheck = ''
      export TRANSFORMERS_CACHE=/tmp
    '';

    passthru = {
      inherit python3;
    };
  };
in buildNpmPackage' {
  pname = "immich";
  inherit version;
  src = "${src}/server";
  inherit (sources.components.server) npmDepsHash;

  nativeBuildInputs = [
    pkg-config
    python3
    makeWrapper
  ];

  buildInputs = [
    ffmpeg
    imagemagick
    libraw
    vips # Required for sharp
  ];

  # Required because vips tries to write to the cache dir
  makeCacheWritable = true;
  # TODO not working prePatch = ''
  # TODO not working   export npm_config_libvips_local_prebuilds="/tmp"
  # TODO not working '';

  installPhase = ''
    runHook preInstall

    npm config delete cache
    npm prune --omit=dev --omit=optional

    mkdir -p $out
    mv package.json package-lock.json node_modules dist $out/

    makeWrapper ${nodejs}/bin/node $out/bin/admin-cli --add-flags $out/dist/main --add-flags cli
    makeWrapper ${nodejs}/bin/node $out/bin/microservices --add-flags $out/dist/main --add-flags microservices
    makeWrapper ${nodejs}/bin/node $out/bin/server --add-flags $out/dist/main --add-flags immich

    runHook postInstall
  '';

  passthru = {
    #tests = { inherit (nixosTests) immich; };
    inherit cli web machine-learning;
    updateScript = ./update.sh;
  };

  meta = with lib; {
    description = "Self-hosted photo and video backup solution";
    homepage = "https://immich.app/";
    license = licenses.mit;
    maintainers = with maintainers; [ jvanbruegge oddlama ];
    inherit (nodejs.meta) platforms;
  };
}
