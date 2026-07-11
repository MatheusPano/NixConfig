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
  androidSdkRoot = "${androidSdk}/libexec/android-sdk";
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

  home.sessionVariables = {
    ANDROID_HOME = androidSdkRoot;
    ANDROID_SDK_ROOT = androidSdkRoot;
    JAVA_HOME = "${pkgs.jdk17}/lib/openjdk";

    # Faz o Gradle usar o aapt2 do SDK do Nix em vez de baixar um
    # (o baixado é um binário FHS que não roda no NixOS).
    GRADLE_OPTS =
      "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdkRoot}/build-tools/${buildToolsVersion}/aapt2";
  };
}
