#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Appearance.h"
#import "Features/Navbar/Navbar.h"
#import "Features/Flags/Flags.h"
#import "Features/NowPlaying/NowPlaying.h"

void SGSetLiquidGlassUI(BOOL on) {
    for (NSString *key in @[SGKeySpotifyGlass, SGKeyTabBar, SGKeySearchField, SGKeyNowPlayingBar, SGKeyPlayer, SGKeyPlayerBackdrop, SGKeyLyricsCard]) {
        SGSetEnabled(key, on);
    }
}

// Going back to Spotify's green is offered only once a colour of the mod's is set, so a stray tap
// cannot wipe it.
static void chooseAccent(void) {
    if (!SGAccentColor()) {
        SGPickAccent();
        return;
    }
    UIViewController *top = SGTopController();
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Accent colour" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Pick a colour" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { SGPickAccent(); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Spotify's green" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { SGSetInt(SGKeyAccent, -1); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = top.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(top.view.bounds), CGRectGetMidY(top.view.bounds), 0, 0);
    sheet.popoverPresentationController.permittedArrowDirections = 0;
    [top presentViewController:sheet animated:YES completion:nil];
}

SGModSection *SGAppearanceSection(void) {
    SGModRow *glass = SGOptionRow(@"Liquid Glass UI", @"Spotify's own glass bars, slider and sheets, and every glass switch of the mod's with it", SGKeySpotifyGlass);
    glass.changed = ^(BOOL on) { SGSetLiquidGlassUI(on); };
    return SGNotedSection(@"Appearance", @[
        SGWithSymbol(glass, @"drop"),
        SGWithSymbol(SGOptionRow(@"AMOLED background", nil, SGKeyAmoled), @"moon"),
        SGWithSymbol(SGStatActionRow(@"Accent colour", nil, ^NSString *{ return SGAccentLabel(); }, ^{ chooseAccent(); }), @"paintpalette"),
    ], @"Liquid Glass UI turns every glass switch of the mod's on or off with it. Changes apply after you restart Spotify.");
}
