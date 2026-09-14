// Spotify's /color-lyrics/v2/track/<id> answered with Musixmatch's lyrics. An NSURLProtocol, put into
// every session the app makes, takes the request over, sends it on itself and gives Spotify one reply:
// timed lines from Musixmatch first, then Spotify's timed ones, then untimed ones from Musixmatch. A
// request Spotify's server has no lyrics for (404) becomes a 200 when Musixmatch has some. Whichever
// lines win go to the karaoke page as well.
//
// It is a protocol and not a rewrite in the URLSession delegates: a 200 handed to
// Connectivity_HttpClientKit's delegate in place of a 404 still showed no lyrics, so the task's own
// response has to be the 200.
#import "Core/SGCore.h"
#import "Musixmatch.h"
#import "Features/AdBlock/Protobuf.h"
#import "Headers/SPTPlayer.h"

static NSString *const kHandledKey = @"spotifyglass.lyricsHandled";

// The page's colours when Spotify sent none to keep, ARGB.
static const uint32_t kBackground = 0xFF535353, kLine = 0xFF000000, kActiveLine = 0xFFFFFFFF;

// A protocol sees the request without its session's HTTPAdditionalHeaders, so the ones of Spotify's
// sessions are kept and put back on the request it sends.
static NSMutableDictionary<NSString *, NSString *> *sg_sessionHeaders;

static NSString *lyricsTrack(NSURL *url) {
    NSString *path = url.path;
    NSRange marker = [path rangeOfString:@"/color-lyrics/v2/track/"];
    if (marker.location == NSNotFound) return nil;
    NSString *track = [[path substringFromIndex:NSMaxRange(marker)] componentsSeparatedByString:@"/"].firstObject;
    return track.length ? track : nil;
}

static NSInteger statusOf(NSURLResponse *response) {
    return [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
}

// Lyrics { 1 data: { 1 time_synchronized, 2 repeated line { 1 offset_ms, 2 content }, 5 provided_by },
//          2 colors { 1 background, 2 line, 3 active_line } }
static NSData *lyricsBody(SGMusixmatchLyrics *lyrics, NSData *spotify) {
    NSMutableArray<SGPBField *> *data = [NSMutableArray array];
    if (lyrics.synced) [data addObject:SGPBVarint(1, 1)];
    for (NSUInteger i = 0; i < lyrics.texts.count; i++) {
        NSData *line = SGPBSerialize(@[SGPBVarint(1, (uint64_t)MAX(lyrics.starts[i].integerValue, 0)), SGPBString(2, lyrics.texts[i])]);
        [data addObject:SGPBBytes(2, line)];
    }
    [data addObject:SGPBString(5, @"Musixmatch")];
    SGPBField *colors = SGPBFirst(SGPBParse(spotify), 2);
    if (colors.wire != 2) colors = SGPBBytes(2, SGPBSerialize(@[SGPBVarint(1, kBackground), SGPBVarint(2, kLine), SGPBVarint(3, kActiveLine)]));
    return SGPBSerialize(@[SGPBBytes(1, SGPBSerialize(data)), colors]);
}

// Musixmatch's body, or nil to hand Spotify's reply on as it came.
static NSData *chosenBody(NSString *track, SGMusixmatchLyrics *lyrics, NSData *spotify) {
    NSArray<SGKaraokeLine *> *spotifyLines = SGKaraokeLinesFromBody(spotify);
    BOOL ours = lyrics.texts.count && (lyrics.synced || !spotifyLines);
    NSArray<SGKaraokeLine *> *karaoke = lyrics.wordTimed || ours ? lyrics.karaokeLines : spotifyLines;
    if (karaoke) SGKaraokeKeepLines(track, karaoke);
    SGLog(@"musixmatch: lyrics page of %@ gets %@, %@ word timing", track, ours ? @"Musixmatch's lines" : spotify.length ? @"Spotify's own lines" : @"no lyrics",
          lyrics.wordTimed ? @"real" : @"estimated");
    return ours ? lyricsBody(lyrics, spotify) : nil;
}

@interface SGLyricsURLProtocol : NSURLProtocol
@end

@implementation SGLyricsURLProtocol {
    NSURLSessionDataTask *_inner;
    NSThread *_thread;
    NSArray<NSString *> *_modes;
    BOOL _stopped;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return lyricsTrack(request.URL) && ![NSURLProtocol propertyForKey:kHandledKey inRequest:request];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (NSURLSession *)innerSession {
    static NSURLSession *session;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        configuration.URLCache = nil;
        session = [NSURLSession sessionWithConfiguration:configuration];
    });
    return session;
}

// The client is told things only on the thread that started the load, in its run loop mode.
- (void)onLoadingThread:(void (^)(void))block {
    [self performSelector:@selector(runOnLoadingThread:) onThread:_thread withObject:[block copy] waitUntilDone:NO modes:_modes];
}

- (void)runOnLoadingThread:(void (^)(void))block {
    if (!_stopped) block();
}

- (void)replyWith:(NSURLResponse *)response data:(NSData *)data {
    [self onLoadingThread:^{
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        if (data.length) [self.client URLProtocol:self didLoadData:data];
        [self.client URLProtocolDidFinishLoading:self];
    }];
}

- (void)startLoading {
    _thread = NSThread.currentThread;
    NSString *mode = NSRunLoop.currentRunLoop.currentMode;
    _modes = mode && ![mode isEqualToString:NSDefaultRunLoopMode] ? @[NSDefaultRunLoopMode, mode] : @[NSDefaultRunLoopMode];

    NSMutableURLRequest *request = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:kHandledKey inRequest:request];
    @synchronized (sg_sessionHeaders) {
        [sg_sessionHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
            if (![request valueForHTTPHeaderField:name]) [request setValue:value forHTTPHeaderField:name];
        }];
    }
    NSString *track = lyricsTrack(request.URL);
    _inner = [[SGLyricsURLProtocol innerSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self onLoadingThread:^{ [self.client URLProtocol:self didFailWithError:error]; }];
            return;
        }
        NSInteger status = statusOf(response);
        BOOL json = data.length && ((const uint8_t *)data.bytes)[0] == '{';
        SGLog(@"musixmatch: Spotify answered %ld with %lu bytes for %@", (long)status, (unsigned long)data.length, track);
        if ((status != 200 && status < 400) || (status == 200 && json)) {
            [self replyWith:response data:data];
            return;
        }
        SGMusixmatchFetch(track, ^(SGMusixmatchLyrics *lyrics) {
            NSData *body = chosenBody(track, lyrics, status == 200 ? data : nil);
            if (!body) {
                [self replyWith:response data:data];
                return;
            }
            NSHTTPURLResponse *ok = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:@"HTTP/1.1"
                                                              headerFields:@{@"Content-Type": @"application/protobuf", @"Content-Length": @(body.length).stringValue}];
            [self replyWith:ok data:body];
        });
    }];
    [_inner resume];
}

- (void)stopLoading {
    _stopped = YES;
    [_inner cancel];
}

@end

%hook NSURLSession
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    if (!configuration) return %orig;
    NSURLSessionConfiguration *withProtocol = [configuration copy];
    NSArray *classes = withProtocol.protocolClasses ?: @[];
    if (![classes containsObject:SGLyricsURLProtocol.class]) withProtocol.protocolClasses = [@[SGLyricsURLProtocol.class] arrayByAddingObjectsFromArray:classes];
    NSString *owner = delegate ? NSStringFromClass([delegate class]) : @"";
    if (configuration.HTTPAdditionalHeaders.count && ([owner isEqualToString:@"SPTDataLoaderService"] || [owner containsString:@"HttpClientURLSession"])) {
        @synchronized (sg_sessionHeaders) {
            [configuration.HTTPAdditionalHeaders enumerateKeysAndObjectsUsingBlock:^(id name, id value, BOOL *stop) {
                if ([name isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class]) sg_sessionHeaders[name] = value;
            }];
        }
    }
    return %orig(withProtocol, delegate, queue);
}
%end

// The player offers the lyrics card by the track's has_lyrics.
%group AllTracks
%hook SPTPlayerTrack
- (NSDictionary *)metadata {
    NSDictionary *metadata = %orig;
    if ([metadata[@"has_lyrics"] isEqual:@"true"]) return metadata;
    id uri = self.URI;
    NSString *text = [uri isKindOfClass:NSURL.class] ? [(NSURL *)uri absoluteString] : [uri description];
    if (![text hasPrefix:@"spotify:track:"] || !SGMusixmatchMayHave([text substringFromIndex:@"spotify:track:".length])) return metadata;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"musixmatch: marking tracks without Spotify lyrics as having some, first %@", text); });
    NSMutableDictionary *marked = [metadata mutableCopy] ?: [NSMutableDictionary dictionary];
    marked[@"has_lyrics"] = @"true";
    return marked;
}
%end
%end

%ctor {
    if (!SGFlag(SGKeyMusixmatchLyrics, NO)) return;
    sg_sessionHeaders = [NSMutableDictionary dictionary];
    %init;
    BOOL allTracks = SGFlag(SGKeyMusixmatchAllTracks, NO);
    if (allTracks) %init(AllTracks);
    SGLog(@"musixmatch: on, every track %@", allTracks ? @"on" : @"off");
    SGRequireClasses(@[@"SPTPlayerTrack"]);
}
