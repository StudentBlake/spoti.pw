// Where the karaoke page gets its lines and its clock. The color-lyrics body is copied as it passes
// the same URLSession delegates AdBlock/AdNetwork.x reads, untouched, and kept per track, since the
// page may open long after the request finished. The clock is SPTEsperantoPlayer's state, asked for on
// every frame: the player is caught the first time the app asks it, and its position runs on by itself.
// With Musixmatch on, the color-lyrics body is Features/Musixmatch's to answer and it hands the lines over.
#import "Core/SGCore.h"
#import "Karaoke.h"
#import "Features/LockScreenLyrics/LockScreenLyrics.h"
#import "Features/Musixmatch/Musixmatch.h"
#import "Headers/SPTPlayer.h"

static const NSUInteger kKeptTracks = 40;
// What spclient needs from a request to answer it as the signed-in app.
static NSString *const kSpclientHeaders[] = {@"authorization", @"client-token", @"app-platform", @"spotify-app-version", @"user-agent", @"accept-language"};

static NSMutableDictionary<NSString *, NSArray<SGKaraokeLine *> *> *sg_lyrics;
static NSMutableSet<NSString *> *sg_requested;
static NSDictionary<NSString *, NSString *> *sg_spclientHeaders;
static __weak id sg_player;
static BOOL sg_musixmatch;
static char kBodyKey;

static NSString *trackInURL(NSURL *url) {
    NSString *path = url.path;
    NSRange marker = [path rangeOfString:@"/color-lyrics/v2/track/"];
    if (marker.location == NSNotFound) return nil;
    NSString *track = [[path substringFromIndex:NSMaxRange(marker)] componentsSeparatedByString:@"/"].firstObject;
    return track.length ? track : nil;
}

static void rememberHeaders(NSURLSession *session, NSURLRequest *request) {
    if (![request.URL.host containsString:@"spclient"]) return;
    NSMutableDictionary<NSString *, NSString *> *all = [NSMutableDictionary dictionary];
    [session.configuration.HTTPAdditionalHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        if ([key isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class]) all[[key lowercaseString]] = value;
    }];
    [request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        all[key.lowercaseString] = value;
    }];
    if (!all[@"authorization"]) return;
    NSMutableDictionary<NSString *, NSString *> *headers = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < sizeof(kSpclientHeaders) / sizeof(*kSpclientHeaders); i++) {
        NSString *name = kSpclientHeaders[i];
        if (all[name]) headers[name] = all[name];
    }
    dispatch_async(dispatch_get_main_queue(), ^{ sg_spclientHeaders = headers; });
}

void SGKaraokeKeepLines(NSString *track, NSArray<SGKaraokeLine *> *lines) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (sg_lyrics.count >= kKeptTracks) [sg_lyrics removeAllObjects];
        sg_lyrics[track] = lines;
    });
}

static void received(NSURLSession *session, NSURLSessionTask *task, NSData *data) {
    rememberHeaders(session, task.currentRequest);
    if (sg_musixmatch || !trackInURL(task.currentRequest.URL)) return;
    NSMutableData *body = objc_getAssociatedObject(task, &kBodyKey);
    if (!body) objc_setAssociatedObject(task, &kBodyKey, (body = [NSMutableData data]), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [body appendData:data];
}

static void completed(NSURLSessionTask *task, NSError *error) {
    NSMutableData *body = objc_getAssociatedObject(task, &kBodyKey);
    if (!body) {
        NSString *path = task.currentRequest.URL.path;
        if (!sg_musixmatch && [path.lowercaseString containsString:@"lyrics"]) SGLog(@"karaoke: lyrics request not read: %@ (error %@)", path, error);
        return;
    }
    objc_setAssociatedObject(task, &kBodyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSString *track = trackInURL(task.currentRequest.URL);
    if (error || !track) return;
    NSArray<SGKaraokeLine *> *lines = SGKaraokeLinesFromBody(body);
    SGLog(@"karaoke: lyrics for %@, %lu bytes, %lu synced lines", track, (unsigned long)body.length, (unsigned long)lines.count);
    if (lines) SGKaraokeKeepLines(track, lines);
}

NSArray<SGKaraokeLine *> *SGKaraokeLinesForTrack(NSString *trackID) {
    return trackID ? sg_lyrics[trackID] : nil;
}

static void requestFromSpotify(NSString *trackID) {
    NSDictionary<NSString *, NSString *> *headers = sg_spclientHeaders;
    if (!headers) return;
    [sg_requested addObject:trackID];
    NSString *address = [NSString stringWithFormat:@"https://spclient.wg.spotify.com/color-lyrics/v2/track/%@?format=json&vocalRemoval=false&market=from_token", trackID];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:address]];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:name];
    }];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *body, NSURLResponse *response, NSError *error) {
        NSArray<SGKaraokeLine *> *lines = SGKaraokeLinesFromBody(body);
        SGLog(@"karaoke: fetched lyrics for %@: status %ld, %lu synced lines, error %@", trackID,
              (long)[(NSHTTPURLResponse *)response statusCode], (unsigned long)lines.count, error);
        if (lines) SGKaraokeKeepLines(trackID, lines);
    }] resume];
}

void SGKaraokeRequestLyrics(NSString *trackID) {
    if (!trackID || sg_lyrics[trackID] || [sg_requested containsObject:trackID]) return;
    if (!sg_musixmatch) {
        requestFromSpotify(trackID);
        return;
    }
    [sg_requested addObject:trackID];
    SGMusixmatchFetch(trackID, ^(SGMusixmatchLyrics *lyrics) {
        if (lyrics.karaokeLines) {
            SGKaraokeKeepLines(trackID, lyrics.karaokeLines);
            return;
        }
        [sg_requested removeObject:trackID];
        requestFromSpotify(trackID);
    });
}

id SGKaraokePlayer(void) {
    return sg_player;
}

static SPTPlayerState *playerState(void) {
    id player = sg_player;
    return [player respondsToSelector:@selector(state)] ? [(id<SPTPlayer>)player state] : nil;
}

NSString *SGKaraokePlayingTrack(void) {
    id uri = playerState().track.URI;
    NSString *text = [uri isKindOfClass:NSURL.class] ? ((NSURL *)uri).absoluteString : [uri description];
    return [text hasPrefix:@"spotify:track:"] ? [text substringFromIndex:@"spotify:track:".length] : nil;
}

NSInteger SGKaraokePositionMs(void) {
    SPTPlayerState *state = playerState();
    if (!state) return -1;
    return (NSInteger)((state.isPaused ? state.positionAsOfTimestamp : state.position) * 1000);
}

void SGKaraokeSeek(NSInteger ms) {
    id player = sg_player;
    if (![player respondsToSelector:@selector(seekTo:)]) return;
    [(id<SPTPlayer>)player seekTo:ms / 1000.0];
}

%hook SPTEsperantoPlayer
- (id)state {
    if (!sg_player) sg_player = self;
    return %orig;
}
%end

%hook SPTDataLoaderService
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    received(session, task, data);
    %orig;
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    completed(task, error);
    %orig;
}
%end

%hook _TtC26Connectivity_HttpClientKit20HttpClientURLSession
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    received(session, task, data);
    %orig;
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    completed(task, error);
    %orig;
}
%end

%ctor {
    if (!SGFlag(SGKeyKaraokeLyrics, NO) && !SGFlag(SGKeyLockScreenLyrics, NO)) return;
    sg_lyrics = [NSMutableDictionary dictionary];
    sg_requested = [NSMutableSet set];
    sg_musixmatch = SGFlag(SGKeyMusixmatchLyrics, NO);
    %init;
    SGLog(@"karaoke: on");
    SGRequireClasses(@[
        @"SPTEsperantoPlayer", @"SPTPlayerState",
        @"SPTDataLoaderService", @"_TtC26Connectivity_HttpClientKit20HttpClientURLSession",
    ]);
}
