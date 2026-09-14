#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "NowPlaying.h"
#import "Features/Declutter/Declutter.h"
#import "Features/Gestures/Gestures.h"
#import "Features/ArtistBlock/ArtistBlock.h"
#import "Features/Karaoke/Karaoke.h"
#import "Features/LockScreenLyrics/LockScreenLyrics.h"
#import "Features/Musixmatch/Musixmatch.h"

static UIViewController *nowPlayingBarPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Now playing bar" intro:SGRestartNote sections:@[
        SGSection(nil, @[
            SGOptionRow(@"Glass now playing bar", @"Glass card with round artwork", SGKeyNowPlayingBar),
            SGHideRow(@"Hide the device button", @"The speaker icon in the bar", SGHideBarConnect),
        ]),
        SGSection(@"Spotify's flags", @[
            SGFlagRow(@"Two lines of track info", @"ios-feature-nowplayingbar.two_lines_information_unit"),
            SGFlagRow(@"Save button", @"ios-feature-nowplayingbar.add_button"),
            SGFlagRow(@"Queue badge", @"ios-feature-nowplayingbar.queue_badge"),
            SGFlagRow(@"Hold and drag to resize", @"ios-feature-nowplayingbar.hold_and_drag_to_resize"),
            SGFlagRow(@"Video in the mini player", @"ios-feature-nowplaying.video_in_miniplayer"),
            SGFlagRow(@"Bar to cover art animation", @"ios-feature-nowplaying.bartocoverart_animation_enabled"),
            SGFlagRow(@"Mini player transition animations", @"ios-feature-nowplaying.miniplayer_transition_animations"),
        ]),
    ] footer:nil];
}

static UIViewController *lyricsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Lyrics" intro:SGRestartNote sections:@[
        SGSection(nil, @[
            SGOptionRow(@"Apple Music style", @"Word by word on the full screen page; timing inside a line is estimated unless Musixmatch has it", SGKeyKaraokeLyrics),
            SGOptionRow(@"Glass lyrics", @"Glass card, and the page it expands into", SGKeyLyricsCard),
            SGOptionRow(@"Lyrics on the lock screen", @"The line being sung in place of the artist, also in the Dynamic Island, Control Center and CarPlay", SGKeyLockScreenLyrics),
        ]),
        SGNotedSection(@"Musixmatch", @[
            SGOptionRow(@"Lyrics from Musixmatch", @"In place of Spotify's, with the time of every word where Musixmatch has it", SGKeyMusixmatchLyrics),
            SGOptionRow(@"Lyrics for every track", @"Offers the lyrics card on tracks Spotify has no lyrics for; needs Lyrics from Musixmatch", SGKeyMusixmatchAllTracks),
            SGOptionRow(@"Word timing from NetEase", @"For Apple Music style when Musixmatch has none, as for most Eminem; needs Lyrics from Musixmatch", SGKeyNetEaseWordTiming),
        ], @"Musixmatch is sent the track's id with an anonymous token, NetEase the title and artist; neither gets anything of your Spotify account."),
        SGSection(@"Hide in the player", @[
            SGHideRow(@"Lyrics card", @"The lyrics card below the player", SGHideLyricsCard),
            SGHideRow(@"Lyrics preview", @"The lyric lines shown under the artwork", SGHideLyricsInline),
        ]),
        SGSection(@"Spotify's flags", @[
            SGFlagRow(@"Translations in the player", @"ios-feature-lyrics.enable_lyrics_multilanguage_npv"),
            SGFlagRow(@"Translations full screen", @"ios-feature-lyrics.enable_lyrics_multilanguage_fullscreen"),
            SGFlagRow(@"Keep lyrics offline", @"ios-feature-lyrics.lyrics_offline_enabled"),
            SGFlagRow(@"Dynamic colours", @"ios-feature-lyrics.enable_dynamic_colors"),
            SGFlagRow(@"Centre a single line", @"ios-feature-lyrics.is_single_line_centering_enabled"),
            SGFlagRow(@"Full screen on track change", @"ios-feature-lyrics.enable_fullscreen_track_change"),
            SGFlagRow(@"Lyrics toggle in the context menu", @"ios-feature-lyrics.lyrics_context_menu_toggle_enabled"),
        ]),
    ] footer:nil];
}

static UIViewController *queuePage(void) {
    return [[SGModPage alloc] initWithTitle:@"Queue & devices" intro:SGRestartNote sections:@[
        SGNotedSection(@"Bottom sheets", @[
            SGFlagRow(@"Queue as a bottom sheet", @"ios-feature-nowplaying.bottom_sheet_queue_enabled"),
            SGFlagRow(@"Connect as a bottom sheet", @"ios-feature-nowplaying-elements.enable_connect_bottom_sheet"),
            SGFlagRow(@"Connect sheet from the video switcher", @"ios-playbackcontrol-audiovideoswitcher-impl.enable_connect_bottom_sheet"),
        ], @"Locked on while Liquid Glass UI is on."),
        SGSection(@"Queue", @[
            SGFlagRow(@"Queue flip transition", @"ios-feature-nowplaying.queue_flip_transition_enabled"),
            SGFlagRow(@"Play next in the context menu", @"ios-feature-queue.is_play_next_context_menu_enabled"),
        ]),
    ] footer:nil];
}

static UIViewController *lockScreenPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Lock screen widget" intro:SGRestartNote sections:@[
        SGSection(@"Controls", @[
            SGFlagRow(@"Like and dislike buttons", @"ios-feature-lockscreen.like_dislike_enabled"),
            SGFlagRow(@"Skip button on podcasts", @"ios-feature-lockscreen.skip_button_on_podcasts"),
            SGFlagRow(@"Chapter skip controls", @"ios-feature-lockscreen.enable_chapter_skip_controls"),
            SGFlagRow(@"Burst skip", @"ios-feature-lockscreen.burst_skip_enabled"),
        ]),
        SGSection(@"Artwork", @[
            SGFlagRow(@"Animated artwork", @"ios-feature-lockscreen.animated_artwork_enabled"),
            SGFlagRow(@"Video artwork", @"ios-feature-lockscreen.vit_artwork_enabled"),
            SGFlagRow(@"Companion content", @"ios-feature-lockscreen.companion_content_enabled"),
        ]),
    ] footer:nil];
}

UIViewController *SGNowPlayingSettingsPage(void) {
    SGModRow *blocked = SGPageRow(@"Blocked artists", ^UIViewController *{ return SGArtistBlockSettingsPage(); });
    blocked.value = ^NSString *{
        return SGFlag(SGKeyArtistBlock, NO) ? @(SGBlockedArtists().count).stringValue : @"Off";
    };

    return [[SGModPage alloc] initWithTitle:@"Player" intro:@"Changes apply after you restart Spotify. Gestures and Blocked artists apply straight away." sections:@[
        SGSection(nil, @[
            SGWithSymbol(SGPageRow(@"Gestures", ^UIViewController *{ return SGGesturesSettingsPage(); }), @"hand.tap"),
            SGWithSymbol(SGPageRow(@"Lyrics", ^UIViewController *{ return lyricsPage(); }), @"quote.bubble"),
            SGWithSymbol(blocked, @"person.crop.circle.badge.xmark"),
            SGWithSymbol(SGPageRow(@"Now playing bar", ^UIViewController *{ return nowPlayingBarPage(); }), @"rectangle.bottomthird.inset.filled"),
        ]),
        SGNotedSection(@"Player screen", @[
            SGOptionRow(@"Artwork background", @"The cover blurred and dimmed behind the player instead of the flat album colour", SGKeyPlayerBackdrop),
            SGOptionRow(@"Glass header buttons", @"Glass circles behind close and more, over the artwork", SGKeyPlayer),
            SGKillRow(@"Disable Canvas", @"ios-feature-canvas.canvas_enabled"),
            SGFlagRow(@"Sheet style player", @"ios-feature-nowplaying.sheet_style_npv"),
            SGFlagRow(@"Redesigned header", @"ios-feature-nowplaying.new_redesign_header_with_context_menu_enabled"),
            SGFlagRow(@"New progress slider", @"ios-feature-encoreexperiments.new_npv_slider_enabled"),
            SGFlagRow(@"Expand the sticky header on tap", @"ios-feature-nowplaying.expand_sticky_header_on_tap"),
        ], @"Liquid Glass UI turns the first two on or off with it, and locks the sheet, header and slider on."),
        SGNotedSection(@"Hide cards below the player", @[
            SGHideRow(@"About the artist", @"Photo, listeners and biography", SGHideAboutArtist),
            SGHideRow(@"Related videos", @"The video carousel", SGHideRelatedVideos),
            SGHideRow(@"SongDNA", @"Discover the people behind the song", SGHideSongDNA),
            SGHideRow(@"Live events", @"Concerts and tickets", SGHideLiveEvents),
            SGHideRow(@"Explore the artist", @"The vertical video cards", SGHideExploreArtist),
            SGHideRow(@"Credits", @"Performers and writers", SGHideCredits),
            SGHideRow(@"Merch", @"The artist's shop", SGHideMerch),
            SGHideRow(@"Recommendations", @"\"Artist: what you might like\", the episode and track rows", SGHideRecommendations),
        ], @"The lyrics card is hidden from the Lyrics page."),
        SGSection(@"Hide player buttons", @[
            SGHideRow(@"Shuffle", @"Left of the playback controls", SGHideShuffle),
            SGHideRow(@"Repeat", @"Right of the playback controls", SGHideRepeat),
            SGHideRow(@"Add to playlist", @"The plus next to the track title", SGHideAddTo),
            SGHideRow(@"Queue", @"The queue button in the bottom row", SGHideQueue),
            SGHideRow(@"Share", @"The share button in the bottom row", SGHideShare),
            SGHideRow(@"Connect to a device", @"The speaker and device name in the bottom row", SGHideConnect),
        ]),
        SGNotedSection(nil, @[
            SGWithSymbol(SGPageRow(@"Queue & devices", ^UIViewController *{ return queuePage(); }), @"text.line.first.and.arrowtriangle.forward"),
            SGWithSymbol(SGPageRow(@"Lock screen widget", ^UIViewController *{ return lockScreenPage(); }), @"lock"),
        ], @"Spotify's own options, some of them only rolled out to some accounts."),
    ] footer:nil];
}
