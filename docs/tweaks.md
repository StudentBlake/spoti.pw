# Working on the mod

## Layout

    tweak/                      the Theos project: Makefile, control, the bundle filter plist
    tweak/Sources/Core/         what every file builds on: logging, preferences, view-tree walking, glass panes,
                                runtime declarations of iOS 26 API (SGCore.h imports all of it)
    tweak/Sources/Headers/      reverse-engineered Spotify classes, one header each, only the selectors used
    tweak/Sources/Settings/     the Mod Settings framework: SGPage (a page on Spotify's stack), SGModPage (sections
                                of rows), SGPageStyle (Spotify's list look), SGModSettings.x (the root page and
                                the row that opens it from Spotify's settings)
    tweak/Sources/Features/     one directory per feature, see below
    tweak/Sources/Diagnostics/  screen dumps and the tree server of FLEX builds
    scripts/                    pipeline.sh (build + inject), install.sh (sign + install), record-trees.py,
                                dump-log.sh, extract-flags.py, publish.sh (release: version bump, site release.json)
    trees/                      recorded view trees, one per screen; the input for every new hook
    plist/                      Info.plist overrides merged into the app (turns UIDesignRequiresCompatibility off)
    vendor/                     AutoFLEX deb
    ipa/, out/                  decrypted Spotify IPA in, built IPAs out (both gitignored)

`tweak/Sources/Features/Flags/SGFlagList.m` is generated from the IPA and gitignored, as are the
recorded trees: both are read out of Spotify's own binary and belong to whoever built them.

## Features

A feature is a directory under `tweak/Sources/Features/` holding everything about one area of the
app:

    <Feature>.h            the keys of its switches, and the functions other files may call
    <Something>.x          the hooks, one file per screen or mechanism, each ending in its own %ctor
    <Feature>Settings.m    its Mod Settings page, or its sections on the page of the part it changes, built from
                           the rows in Settings/SGModPage.h
    <Model>.m              plain Objective-C the hooks and the page share, where there is any

    NowPlaying/   the glass bar (NowPlayingBar.x), the full screen player (Player.x), the lyrics card and page (Lyrics.x)
    Navbar/       the glass tab bar (TabBar.x) and its composition (Navbar.x, NavbarLayout.m), the Navbar and Add a tab pages
    Home/         the Home gradient
    Playlist/     the playlist header and pills, hidden one switch each; its sections sit on the Home & Library page
    Declutter/    cards under the player and sections of Home collapsed, player buttons hidden; rows on the Player, Lyrics and Home & Library pages
    Appearance/   AMOLED (Amoled.x), the glass search field (SearchField.x), the accent colour (Accent.x), and Repaint.x, which keeps stripped areas transparent
    Flags/        Spotify's remote-config flags: the provider hook, the generated table, the All flags page and the Labs page
    Privacy/      telemetry blocking and its counters
    AdBlock/      EeveeSpotify's ad blocking: the ad and upsell services silenced (AdServices.x), ad components out of the
                  Hub JSON (AdHubs.x) and the feeds (Feeds.m), Premium pop-ups dropped (AdPopups.x), and the responses
                  rewritten on the way in (AdNetwork.x, Premium.m over the protobuf walker in Protobuf.m), with crossfade
                  and automix switched on in the player core and crossfade's switch kept in step with its slider (Crossfade.x)
    ArtistBlock/  tracks by blocked artists skipped as they start (ArtistSkip.x), the list and the Blocked artists page under Player
    Karaoke/      Apple Music style lyrics on the full screen page: lines read from color-lyrics and the player's clock (KaraokeSource.x),
                  words timed by estimate inside Spotify's line times (KaraokeTiming.m), drawn by KaraokeView.m over the page (KaraokePage.x)
    Musixmatch/   lyrics from Musixmatch with an anonymous token (Musixmatch.m), word timed where it has richsync; color-lyrics
                  answered with them and has_lyrics forced for every track (MusixmatchLyrics.x); word timing from NetEase's yrc
                  for the karaoke page when Musixmatch has none (NetEase.m); rows on the Lyrics page
    Onboarding/   the welcome tour over Home on the first launch (Onboarding.x, the pages in Tour.m), offered again from the Mod page
    About/        the update check and the Mod page: the build, its updates, the links and the reset

Every key a feature stores starts with `spotifyglass.`, whatever it holds: Reset all settings on
the Mod page removes by that prefix and has no list to keep up to date. It leaves `SGKeyStock` behind,
which makes every unset switch read off, so a reset is stock Spotify whatever switches exist.

A hook reads its switch when it runs (`SGEnabled`, `SGHidden`, `SGFlag` from Core/SGPrefs.h), so a
change shows after Spotify restarts; the tab editor on the Navbar page is the exception and applies as soon as the bar lays
out again, as are the Home gradient's colour, strength and height, but not the switch that turns it on. The root page in `Settings/SGModSettings.x` holds the Appearance card and links the page of each part of Spotify by hand.

## Make targets

    make build      # out/Spotify-<version>-glass.ipa with FLEX in it
    make release    # the same without FLEX
    make install    # build without FLEX, sign with your certificate, install over USB
    make install FLEX=1   # the same with FLEX, which is what make trees reads through
    make trees      # record view trees screen by screen (FLEX build open on the phone, USB)
    make log        # stream [spotifyglass] log lines from the phone
    make flags      # regenerate the flag table from the IPA

## Mod Settings

Mod Settings, opened by holding Home on the tab bar or from the first row of the side drawer and the
last row of Spotify's Settings, sorts every
setting by the part of Spotify it changes, so a part's glass, its hide switches and its flags sit on
one page, the mod's own rows first and Spotify's flags below them or on a sub page named after what
they change. It opens on the Appearance card, the three switches that style the whole app: Liquid
Glass UI, AMOLED and the accent colour (Spotify's green is offered from the colour row once a colour
is set). Then a card of parts. Navbar: the glass tab bar and search field, then the tab editor.
Player: Gestures, Lyrics (Apple Music style, glass lyrics, lyrics from Musixmatch and for every track,
hiding the lyrics card and preview, the lyrics flags), Blocked artists (with the count on the row) and Now playing bar (its glass, its device
button and its flags) as pages; then the player screen (artwork background, glass header buttons,
Disable Canvas and the sheet, header, slider and sticky header flags), the cards under the player and
the player buttons to hide, and Queue & devices and Lock screen widget as flag pages. Home & Library:
the Gradient page (the wash behind the top of Home in one of eight colours, at three strengths and
four heights) and the Home flags, the parts of Home to hide including the DJ button and badge, the
playlist header, buttons and pills to hide, and the Library flags. Then Premium, ads & privacy
(EeveeSpotify's Hide ads and Hide upsells, hiding the video carousel and social proof in Search, and
an Ad and upsell flags page under them, every switch there forcing a flag Spotify ships on to off;
Spoof Premium; Block telemetry; then what the ad
blocking and the telemetry blocking have stopped) and Labs (features Spotify built and did not ship,
AI Chat (Martini) first). Last, All flags, Spotify's remote-config flags with a search field and an
Auto / Off / On control per flag (a text field for the number and text ones), and Mod: the update
check, the build and Spotify's version, the site and the repo, the welcome tour again and Reset all
settings. A flag switch on a page forces that one flag and off leaves Spotify's own value, so the All
flags page is where a flag goes back to Auto. Spotify ships its newer design behind several flags at
once, so Liquid Glass UI owns them (the glass navigation bar, the new player slider, the sheet style
player, the queue and Connect sheets, the redesigned player header, the sleep timer's options sheet):
while it is on it forces each of them, and their rows elsewhere show what it forces and take no
touch, so the group has one switch. `SGGlassOwnsFlag` in Features/Flags/Flags.x holds the list. A
change shows after Spotify restarts.

The tab editor on the Navbar page is the exception and applies as soon as the bar lays out again. It lists the tabs in the order
the bar shows them: drag to reorder, tap to hide or show, and Add a tab puts a page of Spotify's or
any `spotify:` link on the bar with one of Encore's own glyphs. Spotify's own tabs are kept by the
name under their icon, so they can be hidden but never removed, and switching the app's language
starts the order over. A tab of the mod's own opens its link through Spotify's link dispatcher, so it
never lights up as the tab you are on.

## Adding a feature

1. `make trees`, record the screen, read `trees/<screen>.txt` for the classes and frames.
2. Make `tweak/Sources/Features/<Feature>/` with `<Feature>.h` declaring the switch key
   (`#define SGKey<Feature> @"spotifyglass.<feature>"`) and `UIViewController *SG<Feature>SettingsPage(void)`.
3. Add the hooks in `<Screen>.x`: `#import "Core/SGCore.h"` and the feature header, guard on the
   switch, use `SGGlassFor`/`SGGlassAt` + `SGShapeGlass` for glass and `SGStripBackgrounds` to clear
   Spotify's paint, and end with `%ctor { %init; SGRequireClasses(@[...]); }`.
4. Add `<Feature>Settings.m` returning an `SGModPage` of `SGSection`s of `SGSwitchRow`/`SGHideRow`/
   `SGFlagRow` (Settings/SGModPage.h), and link it from the page of the part of Spotify it changes, or from
   `Settings/SGModSettings.x` if it is a part of its own.
5. `make install`. Log lines are prefixed `[spotifyglass]`. A FLEX build serves the visible screen's
   tree on the phone's port 8085, which `make trees` reaches over USB through iproxy.

A class Spotify has renamed shows up in the log as `class X not found, its hooks are inactive`;
declare the classes a feature needs in `Headers/` only when a hook calls into them by type.
