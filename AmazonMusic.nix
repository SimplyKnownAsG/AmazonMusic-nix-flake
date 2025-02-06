{ stdenv
, lib
, mkWindowsApp
, wine
, fetchurl
, makeDesktopItem
, makeDesktopIcon   # This comes with erosanix. It's a handy way to generate desktop icons.
, pkgs
}:

let
  # The default settings used if user doesn't already have a settings file.
  # Tabs are disabled because they lead to UI issues when using Wine.
  # defaultSettings = ./SumatraPDF-settings.txt;
in mkWindowsApp rec {
  inherit wine;

  pname = "AmazonMusic";
  version = "1.4";

  # curl 'https://qatgqujbd2.execute-api.us-west-2.amazonaws.com/prod/getCurrentVersion' \
  # -H 'user-agent: (Windows NT 10.0; WOW64)'
  src = builtins.fetchurl {
    url = "https://d2j9xt6n9dg5d3.cloudfront.net/win/24780926_1c962c14fdc55b2e347aeb3c3ffc5ee6/AmazonMusicInstaller.exe";
    sha256 = "sha256:aedf1f32f37f5a0b0be79ae29aebf12f3dd8e9918f9fdaebee107fdf397343a7";
  };

  # By default, when a Wine prefix is first created Wine will produce a warning prompt if Mono is not installed.
  # This doesn't happen with the Wine "full" packages, but it does happen with the "base" packages.
  # When this option is set to 'false', DLL overrides are used when the Wine prefix is created, to bypass the prompt.
  enableMonoBootPrompt = false;

  # In most cases, you'll either be using an .exe or .zip as the src.
  # Even in the case of a .zip, you probably want to unpack with the launcher script.
  dontUnpack = true;

  # You need to set the WINEARCH, which can be either "win32" or "win64".
  # Note that the wine package you choose must be compatible with the Wine architecture.
  wineArch = "win64";

  # Sometimes it can take a while to install an application to generate an app layer.
  # `enableInstallNotification`, which is set to true by default, uses notify-send
  # to generate a system notification so that the user is aware that something is happening.
  # There are two notifications: one before the app installation and one after.
  # The notification will attempt to use the app's icon, if it can find it. And will fallback
  # to hard-coded icons if needed.
  # If an app installs quickly, these notifications can actually be distracting.
  # In such a case, it's better to set this option to false.
  # This package doesn't benefit from the notifications, but I've explicitly enabled them
  # for demonstration purposes.
  enableInstallNotification = true;

  # `fileMap` can be used to set up automatic symlinks to files which need to be persisted.
  # The attribute name is the source path and the value is the path within the $WINEPREFIX.
  # But note that you must ommit $WINEPREFIX from the path.
  # To figure out what needs to be persisted, take at look at $(dirname $WINEPREFIX)/upper,
  # while the app is running.
  fileMap = {
    # "$HOME/.config/${pname}/SumatraPDF-settings.txt" = "drive_c/${pname}/SumatraPDF-settings.txt";
    # "$HOME/.cache/${pname}" = "drive_c/${pname}/${pname}cache";
  };

  # By default, `fileMap` is applied right before running the app and is cleaned up after the app terminates. If the
  # following option is set to "true", then `fileMap` is also applied prior to `winAppInstall`. This is set to "false"
  # by default.
  fileMapDuringAppInstall = false;

  # By default `mkWindowsApp` doesn't persist registry changes made during runtime. Therefore, if an app uses the
  # registry then set this to "true". The registry files are saved to `$HOME/.local/share/mkWindowsApp/$pname/`.
  persistRegistry = true;

  # By default mkWindowsApp creates ephemeral (temporary) WINEPREFIX(es).
  # Setting persistRuntimeLayer to true causes mkWindowsApp to retain the WINEPREFIX, for the short term.
  # This option is designed for apps which can't have their automatic updates disabled.
  # It allows package maintainers to not have to constantly update their mkWindowsApp packages.
  # It is NOT meant for long-term persistance; If the Windows or App layers change, the Runtime layer will be discarded.
  persistRuntimeLayer = true;

  # The method used to calculate the input hashes for the layers.
  # This should be set to "store-path", which is the strictest and most reproduceable method. But it results in many
  # rebuilds of the layers since the slightest change to the package inputs will change the input hashes. An alternative
  # is "version" which is a relaxed method and results in fewer rebuilds but is less reproduceable. If you are
  # considering using "version", contact me first. There may be a better way.
  inputHashMethod = "store-path";

  buildInputs = [
    pkgs.samba # ntlm_auth
  ];

  nativeBuildInputs = [];

  # This code will become part of the launcher script.
  # It will execute if the application needs to be installed,
  # which would happen either if the needed app layer doesn't exist,
  # or for some reason the needed Windows layer is missing, which would
  # invalidate the app layer.
  # WINEPREFIX, WINEARCH, AND WINEDLLOVERRIDES are set
  # and wine, winetricks, and cabextract are in the environment.
  winAppInstall = ''
    # Install fake fonts.
    winetricks fakechinese fakejapanese fakekorean

    # Run the installer.
    wine ${src}

    # Add the update.ini; it complains if it is not there.
    touch "$WINEPREFIX/drive_c/users/$USER/AppData/Local/Amazon Music/update.ini"
  '';


  # This code runs before winAppRun, but only for the first instance.
  # Therefore, if the app is already running, winAppRun will not execute.
  # Use this to do any setup prior to running the app.
  winAppPreRun = ''
  '';

  # This code will become part of the launcher script.
  # It will execute after winAppInstall and winAppPreRun (if needed),
  # to run the application.
  # WINEPREFIX, WINEARCH, AND WINEDLLOVERRIDES are set
  # and wine, winetricks, and cabextract are in the environment.
  # Command line arguments are in $ARGS, not $@
  # DO NOT BLOCK. For example, don't run: wineserver -w
  winAppRun = ''
    wine "$app_layer/wineprefix/drive_c/users/$USER/AppData/Local/Amazon Music/Amazon Music.exe"
  '';

  # This code will run after winAppRun, but only for the first instance.
  # Therefore, if the app was already running, winAppPostRun will not execute.
  # In other words, winAppPostRun is only executed if winAppPreRun is executed.
  # Use this to do any cleanup after the app has terminated
  winAppPostRun = "";

  # This is a normal mkDerivation installPhase, with some caveats.
  # The launcher script will be installed at $out/bin/.launcher
  # DO NOT DELETE OR RENAME the launcher. Instead, link to it as shown.
  installPhase = ''
    runHook preInstall

    ln -s $out/bin/.launcher $out/bin/${pname}

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = pname;
      exec = pname;
      icon = pname;
      desktopName = "Amazon Music";
      genericName = "Music Player";
      categories = ["Audio" "Music" "Player" "AudioVideo"];
    })
  ];

  desktopIcon = makeDesktopIcon {
    name = pname;

    src = fetchurl {
      url = "https://d5fx445wy2wpk.cloudfront.net/icons/amznMusic_favicon.png";
      sha256 = "0fr29f32ri9qn3dmh2jqsdz1bqc8g6z8hh4c8aw5ci9fkd2zyzq4";
    };
  };

  meta = with lib; {
    description = "AmazonMusic";
    homepage = "https://music.amazon.com";
    license = licenses.unfree;
    maintainers = with maintainers; [ simplyknownasg ];
    platforms = [ "x86_64-linux" ];
  };
}

