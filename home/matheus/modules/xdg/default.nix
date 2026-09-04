{ ... }:

{
  # Pastas do usuario em ingles e fixas. Sem isso o locale pt_BR faz cada app
  # inventar a sua: existiam `~/Pictures/Screenshots` E `~/Pictures/Capturas de
  # tela` ao mesmo tempo, com prints espalhados nas duas.
  xdg.userDirs = {
    enable = true;
    createDirectories = true;

    desktop = "$HOME/Desktop";
    documents = "$HOME/Documents";
    download = "$HOME/Downloads";
    music = "$HOME/Music";
    pictures = "$HOME/Pictures";
    publicShare = "$HOME/Public";
    templates = "$HOME/Templates";
    videos = "$HOME/Videos";

    extraConfig = {
      XDG_SCREENSHOTS_DIR = "$HOME/Pictures/Screenshots";
    };
  };

  # O mimeapps.list era editado na mao e ainda apontava pro brave-browser.desktop,
  # que nao esta mais instalado (clicar em link "about:" abria app inexistente).
  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      let
        browser = [ "zen.desktop" ];
        image = [ "org.gnome.Loupe.desktop" ];
        video = [ "mpv.desktop" ];
      in
      {
        "text/html" = browser;
        "x-scheme-handler/http" = browser;
        "x-scheme-handler/https" = browser;
        "x-scheme-handler/about" = browser;
        "x-scheme-handler/unknown" = browser;
        "application/xhtml+xml" = browser;

        "application/pdf" = browser;

        "image/png" = image;
        "image/jpeg" = image;
        "image/gif" = image;
        "image/webp" = image;
        "image/svg+xml" = image;

        "video/mp4" = video;
        "video/x-matroska" = video;
        "video/webm" = video;
        "audio/mpeg" = video;
        "audio/flac" = video;

        "inode/directory" = [ "thunar.desktop" ];
        "text/plain" = [ "code.desktop" ];
      };
  };

  # Faz o `xdg-open` passar pelo portal, entao o "abrir com" de app sandboxed
  # (Flatpak, Electron) respeita as escolhas acima.
  xdg.portal.xdgOpenUsePortal = true;
}
