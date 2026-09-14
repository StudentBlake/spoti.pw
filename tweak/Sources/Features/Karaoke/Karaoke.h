// Apple Music style lyrics on the full screen lyrics page: the line being sung lights up word by
// word, the rest dim and blur with distance. Spotify only times whole lines, so the words inside a
// line are timed by an estimate (KaraokeTiming.m), unless Musixmatch times the words. The lines are
// read from the color-lyrics response as it arrives, or handed over by Features/Musixmatch, and the
// position from the player's state (KaraokeSource.x); a track without synced lyrics keeps Spotify's
// own page.
#import <UIKit/UIKit.h>

#define SGKeyKaraokeLyrics @"spotifyglass.karaokeLyrics"

// Times in milliseconds from the start of the track.
@interface SGKaraokeWord : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic) NSInteger start, end;
@end

@interface SGKaraokeLine : NSObject
@property (nonatomic, copy) NSArray<SGKaraokeWord *> *words;
@property (nonatomic) NSInteger start, end;
@end

// A color-lyrics body, protobuf or JSON, as timed lines; nil unless Spotify synced it by line.
NSArray<SGKaraokeLine *> *SGKaraokeLinesFromBody(NSData *body);
// Lines timed only by their starts, the words inside them estimated; a ♪ or empty text is a break.
NSArray<SGKaraokeLine *> *SGKaraokeEstimatedLines(NSArray<NSNumber *> *starts, NSArray<NSString *> *texts);

NSArray<SGKaraokeLine *> *SGKaraokeLinesForTrack(NSString *trackID);   // nil until the lyrics came
void SGKaraokeKeepLines(NSString *trackID, NSArray<SGKaraokeLine *> *lines);
// Asks spclient for a track's lyrics once, with the headers of Spotify's own requests, for when no
// page of Spotify's has asked for them, e.g. with the app in the background.
void SGKaraokeRequestLyrics(NSString *trackID);
NSString *SGKaraokePlayingTrack(void);   // the base62 id, nil before the player reported
NSInteger SGKaraokePositionMs(void);     // negative when unknown
void SGKaraokeSeek(NSInteger ms);
id SGKaraokePlayer(void);                // SPTEsperantoPlayer, nil before the app asked it for its state

@interface SGKaraokeView : UIView
// Hides Spotify's own lyrics next to this view while it has lyrics to show, and brings them back when not.
- (void)syncSiblings;
@end
