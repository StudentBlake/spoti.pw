#import "Karaoke.h"
#import "Features/AdBlock/Protobuf.h"

@implementation SGKaraokeWord
@end

@implementation SGKaraokeLine
@end

// A line is sung at about this pace and never takes longer than the gap to the next one. A slow
// line gets at least 60 % of its gap, but not more than 1.8x the estimate, so a long instrumental
// after it does not stretch its last word across the break.
static const NSInteger kLineBaseMs = 350, kMsPerLetter = 75;
static const double kMinGapShare = 0.6, kMaxStretch = 1.8;
// Added to every word's letters, for the breath between words and so a one-letter word still shows.
static const NSUInteger kWordWeight = 2;

static NSUInteger lettersIn(NSString *text) {
    NSUInteger count = 0;
    NSCharacterSet *letters = NSCharacterSet.alphanumericCharacterSet;
    for (NSUInteger i = 0; i < text.length; i++) {
        if ([letters characterIsMember:[text characterAtIndex:i]]) count++;
    }
    return count;
}

static BOOL isBreak(NSString *text) {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.length == 0 || [trimmed isEqualToString:@"♪"];
}

// gap is the time to the next line, 0 for the last one.
static SGKaraokeLine *timedLine(NSString *text, NSInteger start, NSInteger gap) {
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    for (NSString *token in [text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]) {
        if (token.length) [tokens addObject:token];
    }
    NSUInteger weight = 0, letters = 0;
    for (NSString *token in tokens) {
        NSUInteger count = lettersIn(token);
        letters += count;
        weight += count + kWordWeight;
    }
    NSInteger estimate = kLineBaseMs + (NSInteger)letters * kMsPerLetter;
    NSInteger sung = estimate;
    if (gap > 0) {
        sung = MAX((NSInteger)(gap * kMinGapShare), estimate);
        sung = MIN(sung, (NSInteger)(estimate * kMaxStretch));
        sung = MIN(sung, gap);
    }

    NSMutableArray<SGKaraokeWord *> *words = [NSMutableArray array];
    double at = start;
    for (NSString *token in tokens) {
        SGKaraokeWord *word = [SGKaraokeWord new];
        word.text = token;
        word.start = (NSInteger)at;
        at += (double)sung * (lettersIn(token) + kWordWeight) / weight;
        word.end = (NSInteger)at;
        [words addObject:word];
    }
    SGKaraokeLine *line = [SGKaraokeLine new];
    line.words = words;
    line.start = start;
    line.end = start + sung;
    return line;
}

NSArray<SGKaraokeLine *> *SGKaraokeEstimatedLines(NSArray<NSNumber *> *starts, NSArray<NSString *> *texts) {
    NSMutableArray<SGKaraokeLine *> *lines = [NSMutableArray array];
    for (NSUInteger i = 0; i < texts.count; i++) {
        if (isBreak(texts[i])) continue;
        NSInteger start = starts[i].integerValue;
        NSInteger gap = i + 1 < starts.count ? starts[i + 1].integerValue - start : 0;
        [lines addObject:timedLine(texts[i], start, MAX(gap, 0))];
    }
    return lines.count ? lines : nil;
}

// Lyrics { 1 data: { 1 time_synchronized, 2 repeated line: { 1 offset_ms, 2 content } }, 2 colors }
static NSArray<SGKaraokeLine *> *fromProtobuf(NSData *body) {
    SGPBField *data = SGPBFirst(SGPBParse(body), 1);
    if (data.wire != 2) return nil;
    NSArray<SGPBField *> *fields = SGPBParse(data.payload);
    if (!SGPBFirst(fields, 1).varint) return nil;
    NSMutableArray<NSNumber *> *starts = [NSMutableArray array];
    NSMutableArray<NSString *> *texts = [NSMutableArray array];
    for (SGPBField *field in fields) {
        if (field.number != 2 || field.wire != 2) continue;
        NSArray<SGPBField *> *line = SGPBParse(field.payload);
        [starts addObject:@((int32_t)SGPBFirst(line, 1).varint)];
        [texts addObject:SGPBText(SGPBFirst(line, 2)) ?: @""];
    }
    return SGKaraokeEstimatedLines(starts, texts);
}

// { "lyrics": { "syncType": "LINE_SYNCED", "lines": [ { "startTimeMs": "1234", "words": "..." } ] } }
static NSArray<SGKaraokeLine *> *fromJSON(NSData *body) {
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:body options:0 error:nil];
    NSDictionary *lyrics = [root isKindOfClass:NSDictionary.class] ? root[@"lyrics"] : nil;
    if (![lyrics isKindOfClass:NSDictionary.class] || ![lyrics[@"syncType"] isEqual:@"LINE_SYNCED"]) return nil;
    NSMutableArray<NSNumber *> *starts = [NSMutableArray array];
    NSMutableArray<NSString *> *texts = [NSMutableArray array];
    for (NSDictionary *line in lyrics[@"lines"]) {
        if (![line isKindOfClass:NSDictionary.class]) continue;
        id words = line[@"words"];
        [starts addObject:@([line[@"startTimeMs"] integerValue])];
        [texts addObject:[words isKindOfClass:NSString.class] ? words : @""];
    }
    return SGKaraokeEstimatedLines(starts, texts);
}

NSArray<SGKaraokeLine *> *SGKaraokeLinesFromBody(NSData *body) {
    if (!body.length) return nil;
    return ((const uint8_t *)body.bytes)[0] == '{' ? fromJSON(body) : fromProtobuf(body);
}
