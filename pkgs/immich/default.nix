{ lib
, pkgs
, buildNpmPackage
, fetchFromGitHub
, python3
, nodejs
, nixosTests
, runCommand
# build-time deps
, pkg-config
, makeWrapper
, cmake
, crane
# runtime deps
, ffmpeg
, imagemagick
, libraw
, vips
, perl
}:
let
  buildNpmPackage' = buildNpmPackage.override { inherit nodejs; };
  sources = lib.importJSON ./sources.json;
  inherit (sources) version;

  meta = with lib; {
    description = "Self-hosted photo and video backup solution";
    homepage = "https://immich.app/";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [ jvanbruegge ];
    inherit (nodejs.meta) platforms;
  };

  # The geodata website is not versioned,
  # so we have to extract it from the container
  geodata = runCommand "immich-geodata" {
    outputHash = sources.geodata_hash;
    outputHashMode = "recursive";
  } ''
    mkdir $out
    echo "Downloading immich container image"
    ${crane}/bin/crane export ghcr.io/immich-app/base-server-prod:${sources.container_tag} - \
      | tar -xv -C "$out" --strip-components=3 usr/src/resources
  '';

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
    inherit version meta;
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

      makeWrapper ${nodejs}/bin/node $out/bin/immich --add-flags $out/dist/index.js

      runHook postInstall
    '';

    meta.mainProgram = "immich";
  };

  web = buildNpmPackage' {
    pname = "immich-web";
    inherit version;
    src = "${src}/web";
    inherit (sources.components.web) npmDepsHash;

    inherit (cli) preBuild;

    installPhase = ''
      runHook preInstall

      cp -r build $out

      runHook postInstall
    '';
  };

  python = python3;

  machine-learning = python.pkgs.buildPythonApplication {
    pname = "immich-machine-learning";
    inherit version;
    src = "${src}/machine-learning";
    format = "pyproject";

    postPatch = ''
      rm poetry.lock

      # opencv is named differently
      substituteInPlace pyproject.toml \
        --replace-fail 'opencv-python-headless = ">=4.7.0.72,<5.0"' "" \
        --replace-fail 'setuptools = "^68.0.0"' 'setuptools = "*"' \
        --replace-fail 'fastapi-slim' 'fastapi' \
        --replace-fail 'pydantic = "^1.10.8"' 'pydantic = "*"'

      # Allow immich to use pydantic v2
      substituteInPlace app/schemas.py --replace-fail 'pydantic' 'pydantic.v1'
      substituteInPlace app/main.py --replace-fail 'pydantic' 'pydantic.v1'
      substituteInPlace app/config.py \
        --replace-fail 'pydantic' 'pydantic.v1' \
        --replace-fail '/cache' '/var/cache/immich'
    '';

    nativeBuildInputs = with python.pkgs; [
      pythonRelaxDepsHook
      poetry-core
      cython
      makeWrapper
    ];

    propagatedBuildInputs = with python.pkgs; [
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
      pydantic
    ] ++ python3.pkgs.uvicorn.optional-dependencies.standard;

    doCheck = false;

    postInstall = ''
      mkdir -p $out/share
      cp log_conf.json $out/share

      cp -r ann $out/${python.sitePackages}/

      makeWrapper ${python3.pkgs.gunicorn}/bin/gunicorn $out/bin/machine-learning \
        --prefix PYTHONPATH : "$out/${python.sitePackages}:$PYTHONPATH" \
        --set-default MACHINE_LEARNING_WORKERS 1 \
        --set-default MACHINE_LEARNING_WORKER_TIMEOUT 120 \
        --set-default IMMICH_HOST 127.0.0.1 \
        --set-default IMMICH_PORT 3003 \
        --add-flags "app.main:app -k app.config.CustomUvicornWorker \
          -w \"\$MACHINE_LEARNING_WORKERS\" \
          -b \"\$IMMICH_HOST:\$IMMICH_PORT\" \
          -t \"\$MACHINE_LEARNING_WORKER_TIMEOUT\"
          --log-config-json $out/share/log_conf.json"
    '';

    passthru = {
      inherit python;
    };
  };
in buildNpmPackage' {
  pname = "immich";
  inherit version meta;
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

  installPhase = ''
    runHook preInstall

    npm config delete cache
    npm prune --omit=dev

    mkdir -p $out
    mv package.json package-lock.json node_modules dist resources $out/
    ln -s ${web} $out/www

    makeWrapper ${nodejs}/bin/node $out/bin/admin-cli --add-flags $out/dist/main --add-flags cli
    makeWrapper ${nodejs}/bin/node $out/bin/server --add-flags $out/dist/main --chdir $out \
      --set IMMICH_WEB_ROOT $out/www --set NODE_ENV production --set IMMICH_REVERSE_GEOCODING_ROOT ${geodata} \
      --suffix PATH : "${lib.makeBinPath [ perl ]}"

    runHook postInstall
  '';

  passthru = {
    inherit cli web machine-learning geodata;
    updateScript = ./update.sh;
  };
}
