{ ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Matheus";
      user.email = "panomatheus@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
}
