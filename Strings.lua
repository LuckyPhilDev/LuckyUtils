-- Lucky's Utils: User-facing strings.
-- Format strings use Lua's standard %s / %d placeholders; pass through
-- string.format at the call site. Debug and dev-log output stays inline.

if LuckysUtilsSkipLoad then return end

LuckyUtilsStrings = LuckyStrings.New("LuckyUtilsStrings", {
    deps = {
        versionSuffix = " version %s",
        required      = "%s is required for this feature.",
        disabled      = "%s is installed but switched off for this character.",

        standaloneTitle   = "Lucky's Utils",
        standaloneNotice  = "Lucky's Utils does not need installing on its own any more. Every one of my addons now carries its own copy, so you can remove the Lucky's Utils folder from your AddOns and everything keeps working.\n\nKeeping it does no harm, but a copy left behind from an older install can override the one your addons ship with.",
        standaloneDismiss = "Got it",
    },

    profiles = {
        exportTitle    = "Export",
        importTitle    = "Import",
        selectAll      = "Select All",
        exportHint     = "Copy this string (Ctrl+C) and share it. The other player imports it.",
        importHint     = "Paste a Lucky share string below, then click Import.",
        readFailed     = "Could not read that string.",
        nothingToImport = "Nothing to import.",
        notAShareString = "This does not look like a Lucky share string.",
        newerVersion   = "This share string was made by a newer version. Please update the addon.",
        corrupted      = "The share string is corrupted.",
        incomplete     = "The share string is corrupted or incomplete.",
        noProfile      = "The share string did not contain a profile.",
    },

    promo = {
        sectionTitle  = "More from Lucky Phil",
        copyLinkTitle = "Copy the link:",
        getLink       = "Get link",
        clickForLink  = "Click for the link",
        discord = {
            name = "Discord",
            desc = "Get support, report a bug or suggest a feature.",
        },
        grabBag = {
            name = "Lucky's Grab-bag",
            desc = "A collection of small quality-of-life features.",
        },
        lootWishlist = {
            name = "Lucky's Loot Wishlist",
            desc = "Track loot from the Adventure Guide and manage a per-character wishlist.",
        },
        warbankStockist = {
            name = "Lucky's Warbank Stockist",
            desc = "Automatically manages item quantities between your bags and the Warband Bank.",
        },
        characterMount = {
            name = "Lucky's Character Mount",
            desc = "Summons a random racial or class mount. Per-character list, auto-populated.",
        },
        wardrobe = {
            name = "Lucky's Wardrobe",
            desc = "Find the sets you can still finish, and hear about it the moment a piece drops.",
        },
    },

    bugs = {
        prefix          = "LuckyBugs:",
        unknownAddon    = "A Lucky addon",
        windowTitle     = "Report a Lucky Addon Error",
        windowHint      = "Copy the report below with Ctrl+C, then paste it on the Discord so it can be fixed.",
        discordLabel    = "Discord",
        counter         = "Error %d of %d%s",
        earlierSession  = " (earlier session)",
        close           = "Close",
        selectAll       = "Select All",
        newer           = "Newer",
        older           = "Older",
        noneCaptured    = " no Lucky addon errors captured.",
        promptText      = "%s ran into an error.\n\nWould you like to report it on the Discord?",
        promptShow      = "Show Report",
        promptNotNow    = "Not Now",
        promptStop      = "Stop Asking",
        promptsOff      = " error reports will not prompt again. Use /luckybugs on to turn them back on.",
        promptsToggled  = " error report prompts %s.",
        on              = "on",
        off             = "off",
        usage           = " /luckybugs to see captured errors, /luckybugs on or off for the prompt.",
    },

    settings = {
        notRegistered = "Settings panel not registered.",
    },

    richSettings = {
        whatsNew       = "What's New",
        about          = "ABOUT",
        enableAndReload = "Enable and Reload",
        range          = "Range: %s to %s%s",
        unavailable    = "|A:common-icon-redx:12:12|a UNAVAILABLE",
        enabled        = "|A:common-icon-checkmark:12:12|a ENABLED",
        disabled       = "|A:common-icon-redx:12:12|a DISABLED",
        versionTag     = "(v%s)",
        versionTooltip = "Version %s",
        utilsVersion   = "Lucky's Utils v%s",
        devMode        = "Dev Mode",
        minimapButton  = "Minimap Button",
        selectNone     = "None",
        selectAll      = "All",
        selectSome     = "%d of %d",
        warningTitle   = "Warning",
    },
})
