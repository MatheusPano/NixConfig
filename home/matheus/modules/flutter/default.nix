{ pkgs, ... }:

let
  # SDK do Android reproduzível via androidenv.
  # As licenças já vêm aceitas (nixpkgs.config.android_sdk.accept_license em nix.nix).
  #
  # Obs: no nixpkgs atual só existem build-tools a partir da 36.0.0.
  android = pkgs.androidenv.composeAndroidPackages {
    cmdLineToolsVersion = "latest";
    platformToolsVersion = "latest";
    buildToolsVersions = [ "36.0.0" ];
    platformVersions = [ "34" "35" "36" ];

    includeNDK = true;
    includeCmake = true;

    # Por padrão só a "android-sdk-license" é gravada; o Flutter/Gradle
    # checam outras. Como o SDK fica read-only no /nix/store, não dá pra
    # rodar `flutter doctor --android-licenses`, então declaramos aqui.
    extraLicenses = [
      "android-sdk-preview-license"
      "android-googletv-license"
      "android-sdk-arm-dbt-license"
      "google-gdk-license"
      "intel-android-extra-license"
      "intel-android-sysimage-license"
      "mips-android-sysimage-license"
    ];

    # Emulador + imagem de sistema (pesado, ~1GB+ no /nix/store).
    # Só é preciso para rodar AVD; para device físico via USB pode deixar false.
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = [ "google_apis" ];
    abiVersions = [ "x86_64" ];
  };

  androidSdk = android.androidsdk;
  androidSdkRootRaw = "${androidSdk}/libexec/android-sdk";

  # O androidenv instala o cmdline-tools numa pasta com o número da versão
  # (ex.: cmdline-tools/21.0) e NÃO cria o symlink `latest`. A extensão
  # Dart/Flutter do VS Code procura o avdmanager em cmdline-tools/latest/bin,
  # então ela falha com "avdmanager is missing from the Android SDK" mesmo
  # com o binário existindo. Como o SDK fica read-only no /nix/store, montamos
  # um SDK root espelhado (só symlinks) que acrescenta o `latest`.
  androidSdkRootPkg = pkgs.runCommand "android-sdk-latest-link" { } ''
    mkdir -p "$out"
    for entry in ${androidSdkRootRaw}/*; do
      name=$(basename "$entry")
      if [ "$name" = "cmdline-tools" ]; then
        mkdir -p "$out/cmdline-tools"
        for tool in "$entry"/*; do
          ln -s "$tool" "$out/cmdline-tools/$(basename "$tool")"
        done
        latest=$(ls -d "$entry"/*/ | sort -V | tail -n1)
        ln -s "$latest" "$out/cmdline-tools/latest"
      else
        ln -s "$entry" "$out/$name"
      fi
    done
  '';
  androidSdkRoot = "${androidSdkRootPkg}";
  buildToolsVersion = "36.0.0";
in
{
  home.packages = with pkgs; [
    fvm # gerenciador de versões do Flutter (substitui o flutter padrão)
    jdk17 # JDK usado pelo Gradle/Android
    androidSdk # Android SDK (platform-tools, build-tools, ndk, emulator...)
    android-tools # adb / fastboot direto no PATH
    unzip
  ];

  # O fvm cria o link ~/fvm/default -> versão global; assim `flutter` e
  # `dart` ficam no PATH sem precisar de `fvm flutter ...`.
  home.sessionPath = [ "$HOME/fvm/default/bin" ];

  home.sessionVariables = {
    ANDROID_HOME = androidSdkRoot;
    ANDROID_SDK_ROOT = androidSdkRoot;

    # O avdmanager (cmdline-tools novo) grava os AVDs em
    # ~/.config/.android/avd, mas o emulator procura em ~/.android/avd.
    # Apontamos os dois para o mesmo lugar.
    ANDROID_AVD_HOME = "$HOME/.config/.android/avd";
    JAVA_HOME = "${pkgs.jdk17}/lib/openjdk";

    # Faz o Gradle usar o aapt2 do SDK do Nix em vez de baixar um
    # (o baixado é um binário FHS que não roda no NixOS).
    GRADLE_OPTS =
      "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdkRoot}/build-tools/${buildToolsVersion}/aapt2";
  };
}
