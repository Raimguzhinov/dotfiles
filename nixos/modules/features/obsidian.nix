{ ... }:
{
  flake.homeModules.obsidian =
    {
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkForce;

      vaultTarget = "Documents/knowledge";

      system = pkgs.stdenv.hostPlatform.system;

      remotelySavePkg = inputs.obsidian-plugins.packages.${system}.remotely-save;
      remotelySaveId =
        let
          manifest = builtins.fromJSON (builtins.readFile "${remotelySavePkg}/manifest.json");
        in
        manifest.id or manifest.name;

      remotelySaveSettingsTemplateName = "obsidian-remotely_save-settings.json";
    in
    {
      sops.templates.${remotelySaveSettingsTemplateName} = {
        # Stored encrypted in `nixos/secrets.yaml` as `obsidian/remotely_save_settings`.
        content = config.sops.placeholder."obsidian/remotely_save_settings";
        mode = "0400";
      };

      programs.obsidian = {
        enable = true;

        defaultSettings = {
          app = {
            vimMode = true;
            useMarkdownLinks = true;
            newLinkFormat = "relative";
          };
        };

        vaults = {
          "Work/core/docs".enable = true;

          ${vaultTarget} = {
            enable = true;

            settings = {
              app = {
                alwaysUpdateLinks = true;
                newFileLocation = "current";
                attachmentFolderPath = "raw/assets";
              };
              communityPlugins = [
                # <plugin-id> : https://github.com/obsidianmd/obsidian-releases/blob/master/community-plugins.json
                {
                  pkg = inputs.obsidian-plugins.packages.${system}.templater-obsidian;
                  enable = true;
                }
                {
                  pkg = inputs.obsidian-plugins.packages.${system}.omnisearch;
                  enable = true;
                }
                {
                  pkg = inputs.obsidian-plugins.packages.${system}.terminal;
                  enable = true;
                  settings = {
                    addToCommand = true;
                    addToContextMenu = true;
                    createInstanceNearExistingOnes = true;
                    errorNoticeTimeout = 0;
                    exposeInternalModules = true;
                    focusOnNewInstance = true;
                    hideStatusBar = "focused";
                    interceptLogging = true;
                    language = "en";
                    newInstanceBehavior = "newHorizontalSplit";
                    noticeTimeout = 5;
                    openChangelogOnUpdate = true;
                    pinNewInstance = true;
                    preferredRenderer = "webgl";
                    profiles.default = {
                      args = [ "--login" ];
                      executable = "${pkgs.zsh}/bin/zsh";
                      followTheme = true;
                      name = "";
                      platforms = {
                        linux = true;
                      };
                      pythonExecutable = "${pkgs.python3}/bin/python3";
                      restoreHistory = false;
                      rightClickAction = "copyPaste";
                      successExitCodes = [
                        "0"
                        "SIGINT"
                        "SIGTERM"
                      ];
                      terminalOptions = {
                        documentOverride = null;
                      };
                      type = "integrated";
                      useWin32Conhost = false;
                    };
                  };
                }
                {
                  pkg = inputs.obsidian-plugins.packages.${system}.obsidian-excalidraw-plugin;
                  enable = true;
                  settings = {
                    copyLinkToElemenetAnchorTo100 = false;
                    copyFrameLinkByName = false;
                    disableDoubleClickTextEditing = false;
                    folder = "raw/Excalidraw";
                    cropFolder = "";
                    annotateFolder = "";
                    embedUseExcalidrawFolder = false;
                    templateFilePath = "raw/Excalidraw/Template.excalidraw";
                    scriptFolderPath = "raw/Excalidraw/Scripts";
                    fontAssetsPath = "raw/Excalidraw/CJK Fonts";
                    loadChineseFonts = false;
                    loadJapaneseFonts = false;
                    loadKoreanFonts = false;
                    compress = true;
                    decompressForMDView = false;
                    onceOffCompressFlagReset = true;
                    onceOffGPTVersionReset = true;
                    autosave = true;
                    autosaveIntervalDesktop = 60000;
                    autosaveIntervalMobile = 30000;
                    drawingFilenamePrefix = "Drawing ";
                    drawingEmbedPrefixWithFilename = true;
                    drawingFilnameEmbedPostfix = " ";
                    drawingFilenameDateTime = "YYYY-MM-DD HH.mm.ss";
                    useExcalidrawExtension = true;
                    cropSuffix = "";
                    cropPrefix = "cropped_";
                    annotateSuffix = "";
                    annotatePrefix = "annotated_";
                    annotatePreserveSize = false;
                    previewImageType = "SVGIMG";
                    renderingConcurrency = 3;
                    allowImageCache = true;
                    allowImageCacheInScene = true;
                    displayExportedImageIfAvailable = false;
                    previewMatchObsidianTheme = false;
                    width = "400";
                    height = "";
                    overrideObsidianFontSize = false;
                    dynamicStyling = "colorful";
                    isLeftHanded = false;
                    desktopUIMode = "tray";
                    tabletUIMode = "compact";
                    iframeMatchExcalidrawTheme = true;
                    matchTheme = false;
                    matchThemeAlways = false;
                    matchThemeTrigger = false;
                    defaultMode = "normal";
                    defaultPenMode = "never";
                    penModeDoubleTapEraser = true;
                    penModeSingleFingerPanning = true;
                    penModeCrosshairVisible = true;
                    panWithRightMouseButton = false;
                    renderImageInMarkdownReadingMode = false;
                    renderImageInHoverPreviewForMDNotes = false;
                    renderImageInMarkdownToPDF = false;
                    allowPinchZoom = false;
                    allowWheelZoom = false;
                    zoomToFitOnOpen = true;
                    zoomToFitOnResize = false;
                    zoomToFitMaxLevel = 2;
                    zoomStep = 0.05;
                    zoomMin = 0.1;
                    zoomMax = 30;
                    linkPrefix = "📍";
                    urlPrefix = "🌐";
                    parseTODO = false;
                    todo = "☐";
                    done = "🗹";
                    hoverPreviewWithoutCTRL = false;
                    linkOpacity = 1;
                    openInAdjacentPane = true;
                    showSecondOrderLinks = true;
                    focusOnFileTab = true;
                    openInMainWorkspace = true;
                    showLinkBrackets = false;
                    syncElementLinkWithText = false;
                    allowCtrlClick = true;
                    forceWrap = false;
                    pageTransclusionCharLimit = 200;
                    wordWrappingDefault = 0;
                    removeTransclusionQuoteSigns = true;
                    iframelyAllowed = true;
                    pngExportScale = 1;
                    exportWithTheme = true;
                    exportWithBackground = true;
                    exportPaddingSVG = 10;
                    exportEmbedScene = false;
                    keepInSync = false;
                    autoexportSVG = false;
                    autoexportPNG = false;
                    autoExportLightAndDark = false;
                    autoexportExcalidraw = false;
                    embedType = "excalidraw";
                    embedMarkdownCommentLinks = true;
                    embedWikiLink = true;
                    syncExcalidraw = false;
                    experimentalFileType = false;
                    experimentalFileTag = "✏️";
                    experimentalLivePreview = true;
                    fadeOutExcalidrawMarkup = false;
                    loadPropertySuggestions = false;
                    experimentalEnableFourthFont = false;
                    experimantalFourthFont = "Virgil";
                    addDummyTextElement = false;
                    zoteroCompatibility = false;
                    fieldSuggester = true;
                    compatibilityMode = false;
                    drawingOpenCount = 0;
                    library = "deprecated";
                    library2 = {
                      type = "excalidrawlib";
                      version = 2;
                      source = "https://github.com/zsviczian/obsidian-excalidraw-plugin/releases/tag/2.20.3";
                      libraryItems = [ ];
                    };
                    imageElementNotice = true;
                    mdSVGwidth = 500;
                    mdSVGmaxHeight = 800;
                    mdFont = "Virgil";
                    mdFontColor = "Black";
                    mdBorderColor = "Black";
                    mdCSS = "";
                    scriptEngineSettings = { };
                    previousRelease = "2.20.3";
                    showReleaseNotes = true;
                    compareManifestToPluginVersion = true;
                    showNewVersionNotification = true;
                    latexBoilerplate = "\\color{blue}";
                    latexPreambleLocation = "preamble.sty";
                    taskboneEnabled = false;
                    taskboneAPIkey = "";
                    pinnedScripts = [ ];
                    sidepanelTabs = [ ];
                    customPens = [ ];
                    numberOfCustomPens = 0;
                    pdfScale = 4;
                    pdfBorderBox = true;
                    pdfFrame = false;
                    pdfGapSize = 20;
                    pdfGroupPages = false;
                    pdfLockAfterImport = true;
                    pdfNumColumns = 1;
                    pdfNumRows = 1;
                    pdfDirection = "right";
                    pdfImportScale = 0.3;
                    gridSettings = {
                      DYNAMIC_COLOR = true;
                      COLOR = "#000000";
                      OPACITY = 50;
                      GRID_DIRECTION = {
                        horizontal = true;
                        vertical = true;
                      };
                    };
                    laserSettings = {
                      DECAY_LENGTH = 50;
                      DECAY_TIME = 1000;
                      COLOR = "#ff0000";
                    };
                    embeddableMarkdownDefaults = {
                      useObsidianDefaults = false;
                      backgroundMatchCanvas = false;
                      backgroundMatchElement = true;
                      backgroundColor = "#fff";
                      backgroundOpacity = 60;
                      borderMatchElement = true;
                      borderColor = "#fff";
                      borderOpacity = 0;
                      filenameVisible = false;
                    };
                    markdownNodeOneClickEditing = false;
                    canvasImmersiveEmbed = true;
                    startupScriptPath = "";
                    aiEnabled = true;
                    openAIAPIToken = "";
                    openAIDefaultTextModel = "gpt-5-mini";
                    openAIDefaultTextModelMaxTokens = 4096;
                    openAIDefaultVisionModel = "gpt-5-mini";
                    openAIDefaultImageGenerationModel = "gpt-image-1";
                    openAIURL = "https://api.openai.com/v1/chat/completions";
                    openAIImageGenerationURL = "https://api.openai.com/v1/images/generations";
                    openAIImageEditsURL = "https://api.openai.com/v1/images/edits";
                    openAIImageVariationURL = "https://api.openai.com/v1/images/variations";
                    slidingPanesSupport = false;
                    areaZoomLimit = 1;
                    longPressDesktop = 500;
                    longPressMobile = 500;
                    doubleClickLinkOpenViewMode = true;
                    isDebugMode = false;
                    rank = "Bronze";
                    modifierKeyOverrides = [ ];
                    showSplashscreen = true;
                    pdfSettings = {
                      pageSize = "A4";
                      pageOrientation = "portrait";
                      fitToPage = 1;
                      paperColor = "white";
                      customPaperColor = "#ffffff";
                      alignment = "center";
                      margin = "normal";
                    };
                    disableContextMenu = false;
                  };
                }
                {
                  pkg = remotelySavePkg;
                  enable = true;
                  # Do NOT put secrets here (it would end up in nix store). The real settings
                  # are written via `home.file` below from a sops template.
                  settings = { };
                }
              ];
            };
          };
        };
      };

      # Remotely Save settings: write data.json from sops template (out-of-store).
      home.file."${vaultTarget}/.obsidian/plugins/${remotelySaveId}/data.json".source = mkForce (
        config.lib.file.mkOutOfStoreSymlink config.sops.templates.${remotelySaveSettingsTemplateName}.path
      );

      xdg.mimeApps.enable = true;
      xdg.mimeApps.defaultApplications = {
        "text/markdown" = [ "obsidian.desktop" ];
      };
    };
}
