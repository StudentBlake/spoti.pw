// Lyrics from Musixmatch in place of Spotify's. It is the catalogue Spotify licenses, and for part of
// it Musixmatch also has the time of every word (richsync), which Spotify never sends; the karaoke
// page then sweeps real timing instead of an estimate. The token is an anonymous one asked for as
// Musixmatch's iOS app, so Musixmatch learns the track's id and nothing of the Spotify account.
// MusixmatchLyrics.x answers Spotify's color-lyrics requests with what comes back.
#import <Foundation/Foundation.h>
#import "Features/Karaoke/Karaoke.h"

#define SGKeyMusixmatchLyrics @"spotifyglass.musixmatchLyrics"
#define SGKeyMusixmatchAllTracks @"spotifyglass.musixmatchAllTracks"
// Word timing for the karaoke page from NetEase Cloud Music when Musixmatch has none, e.g. for the
// tracks it is not licensed to show. Searched by the title, artist and length Musixmatch matched.
#define SGKeyNetEaseWordTiming @"spotifyglass.neteaseWordTiming"

@interface SGMusixmatchLyrics : NSObject
@property (nonatomic) BOOL synced;
@property (nonatomic) BOOL wordTimed;
// Every line as Spotify's lyrics page takes it: ♪ over a break and an empty last line where the
// singing ends. Starts are in milliseconds, all 0 when not synced. nil when only NetEase had words.
@property (nonatomic, copy) NSArray<NSNumber *> *starts;
@property (nonatomic, copy) NSArray<NSString *> *texts;
@property (nonatomic, copy) NSArray<SGKaraokeLine *> *karaokeLines;   // nil unless synced or word timed
@end

// Calls back on the main queue with nil when Musixmatch has nothing it may show for the track, or
// could not be reached.
void SGMusixmatchFetch(NSString *trackID, void (^done)(SGMusixmatchLyrics *lyrics));
// NO once Musixmatch answered that it has no lyrics for the track; safe from any thread.
BOOL SGMusixmatchMayHave(NSString *trackID);

// NetEase.m. Calls back on the main queue, nil when no recording of about that length has word timing.
// NetEase censors swear words with asterisks.
void SGNetEaseWordLines(NSString *title, NSString *artist, NSInteger seconds, void (^done)(NSArray<SGKaraokeLine *> *lines));
