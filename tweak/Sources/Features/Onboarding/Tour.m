#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"
#import "Onboarding.h"
#import "Features/About/About.h"
#import "Features/AdBlock/AdBlock.h"
#import "Features/Appearance/Appearance.h"
#import "Features/Flags/Flags.h"
#import "Features/Home/Home.h"
#import "Features/Declutter/Declutter.h"
#import "Features/Navbar/Navbar.h"
#import "Features/Privacy/Privacy.h"

static const CGFloat kMargin = 24;
static const CGFloat kCardRadius = 22;
static const CGFloat kRowHeight = 60;

#pragma mark - glass

// A view whose glass pane follows its bounds; the panes in SGGlass.m are laid out by their hosts.
@interface SGGlassView : UIView
@property (nonatomic) CGFloat radius;
@property (nonatomic) BOOL capsule;
@end

@implementation SGGlassView
static char kPaneKey;
- (void)layoutSubviews {
    [super layoutSubviews];
    UIVisualEffectView *pane = SGGlassFor(self, &kPaneKey);
    pane.frame = self.bounds;
    SGShapeGlass(pane, self.radius, self.capsule);
}
@end

#pragma mark - rows

typedef NS_ENUM(NSInteger, SGTourRowKind) { SGTourRowPlain, SGTourRowSwitch, SGTourRowAction };

@interface SGTourRow : NSObject
@property (nonatomic, copy) NSString *symbol, *title, *subtitle, *key, *warning;
@property (nonatomic, copy) void (^changed)(BOOL on);
@property (nonatomic) SGTourRowKind kind;
@property (nonatomic) BOOL defaultOn;
@property (nonatomic, copy) void (^action)(void);
@end
@implementation SGTourRow
@end

static SGTourRow *plainRow(NSString *symbol, NSString *title, NSString *subtitle) {
    SGTourRow *row = [SGTourRow new];
    row.symbol = symbol; row.title = title; row.subtitle = subtitle;
    return row;
}

static SGTourRow *switchRow(NSString *symbol, NSString *title, NSString *subtitle, NSString *key, BOOL defaultOn) {
    SGTourRow *row = plainRow(symbol, title, subtitle);
    row.kind = SGTourRowSwitch; row.key = key; row.defaultOn = defaultOn;
    return row;
}

static SGTourRow *actionRow(NSString *symbol, NSString *title, NSString *subtitle, void (^action)(void)) {
    SGTourRow *row = plainRow(symbol, title, subtitle);
    row.kind = SGTourRowAction; row.action = action;
    return row;
}

@interface SGTourRowView : UIControl
- (instancetype)initWithRow:(SGTourRow *)row owner:(UIViewController *)owner;
@end

@implementation SGTourRowView {
    SGTourRow *_row;
    __weak UIViewController *_owner;
    UISwitch *_toggle;
}

- (instancetype)initWithRow:(SGTourRow *)row owner:(UIViewController *)owner {
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    _row = row;
    _owner = owner;

    UIImageView *icon = SGSymbolView(row.symbol, 17, UIImageSymbolWeightSemibold, 36);
    icon.tintColor = row.kind == SGTourRowAction ? SGGreen() : UIColor.whiteColor;
    icon.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    icon.layer.cornerRadius = 10;
    icon.layer.cornerCurve = kCACornerCurveContinuous;

    UILabel *title = [UILabel new];
    title.text = row.title;
    title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    title.textColor = UIColor.whiteColor;
    UILabel *subtitle = [UILabel new];
    subtitle.text = row.subtitle;
    subtitle.font = [UIFont systemFontOfSize:12];
    subtitle.textColor = SGGrey();
    subtitle.numberOfLines = 2;
    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2;

    UIView *trailing = nil;
    if (row.kind == SGTourRowSwitch) {
        _toggle = [UISwitch new];
        _toggle.onTintColor = SGGreen();
        _toggle.on = SGFlag(row.key, row.defaultOn);
        [_toggle addTarget:self action:@selector(toggled) forControlEvents:UIControlEventValueChanged];
        trailing = _toggle;
    } else if (row.kind == SGTourRowAction) {
        trailing = SGSymbolView(@"arrow.up.right", 13, UIImageSymbolWeightSemibold, 20);
        ((UIImageView *)trailing).tintColor = SGGrey();
        [self addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    }

    UIStackView *line = [[UIStackView alloc] initWithArrangedSubviews:trailing ? @[icon, text, trailing] : @[icon, text]];
    line.alignment = UIStackViewAlignmentCenter;
    line.spacing = 14;
    line.translatesAutoresizingMaskIntoConstraints = NO;
    line.userInteractionEnabled = row.kind == SGTourRowSwitch;
    // The text gives way, so a long subtitle wraps instead of squeezing the switch.
    [text setContentHuggingPriority:UILayoutPriorityDefaultLow - 1 forAxis:UILayoutConstraintAxisHorizontal];
    [text setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh - 1 forAxis:UILayoutConstraintAxisHorizontal];
    [self addSubview:line];
    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:36],
        [icon.heightAnchor constraintEqualToConstant:36],
        [line.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [line.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [line.topAnchor constraintEqualToAnchor:self.topAnchor constant:11],
        [line.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-11],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:kRowHeight],
    ]];
    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    if (_row.kind == SGTourRowAction) self.alpha = highlighted ? 0.5 : 1;
}

- (void)tapped {
    if (_row.action) _row.action();
}

- (void)toggled {
    SGSetEnabled(_row.key, _toggle.on);
    if (_row.changed) _row.changed(_toggle.on);
    if (!_toggle.on || !_row.warning) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:_row.title
                                                                   message:_row.warning
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Keep it on" style:UIAlertActionStyleDestructive handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Turn it off" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self->_toggle setOn:NO animated:YES];
        SGSetEnabled(self->_row.key, NO);
    }]];
    [_owner presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - pages

@interface SGTourPage : UIViewController <UINavigationControllerDelegate>
@property (nonatomic, copy) NSString *symbol, *heading, *body;
@property (nonatomic, copy) NSArray<SGTourRow *> *rows;
// In place of the card: a page of the mod's own, filling the rest of the screen and scrolling
// itself. Its navigation bar shows only for what it pushes.
@property (nonatomic, strong) UIViewController *embedded;
@property (nonatomic) NSInteger index;
@property (nonatomic, weak) UIViewController *owner;
@end

@implementation SGTourPage {
    UIImageView *_hero;
    BOOL _shown;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    SGGlassView *halo = [SGGlassView new];
    halo.capsule = YES;
    _hero = SGSymbolView(self.symbol, 34, UIImageSymbolWeightMedium, 88);
    _hero.translatesAutoresizingMaskIntoConstraints = NO;
    [halo addSubview:_hero];

    UILabel *heading = [UILabel new];
    heading.text = self.heading;
    heading.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    heading.textColor = UIColor.whiteColor;
    heading.numberOfLines = 0;
    UILabel *body = [UILabel new];
    body.text = self.body;
    body.font = [UIFont systemFontOfSize:15];
    body.textColor = SGGrey();
    body.numberOfLines = 0;

    SGGlassView *card = [SGGlassView new];
    card.radius = kCardRadius;
    card.clipsToBounds = YES;
    card.layer.cornerRadius = kCardRadius;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    UIStackView *list = [UIStackView new];
    list.axis = UILayoutConstraintAxisVertical;
    list.translatesAutoresizingMaskIntoConstraints = NO;
    for (SGTourRow *row in self.rows) {
        if (list.arrangedSubviews.count) {
            UIView *line = [UIView new];
            line.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
            [line.heightAnchor constraintEqualToConstant:1 / UIScreen.mainScreen.scale].active = YES;
            [list addArrangedSubview:line];
        }
        [list addArrangedSubview:[[SGTourRowView alloc] initWithRow:row owner:self.owner]];
    }
    [card addSubview:list];

    // The column stretches its children to its width; the halo keeps its square inside a strip.
    UIView *strip = [UIView new];
    halo.translatesAutoresizingMaskIntoConstraints = NO;
    [strip addSubview:halo];

    UIStackView *column = [[UIStackView alloc] initWithArrangedSubviews:self.embedded ? @[strip, heading, body] : @[strip, heading, body, card]];
    column.axis = UILayoutConstraintAxisVertical;
    column.spacing = 10;
    [column setCustomSpacing:28 afterView:strip];
    [column setCustomSpacing:28 afterView:body];
    column.translatesAutoresizingMaskIntoConstraints = NO;

    if (self.embedded) {
        [self.view addSubview:column];
        [self addChildViewController:self.embedded];
        UIView *inner = self.embedded.view;
        inner.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:inner];
        [self.embedded didMoveToParentViewController:self];
        [NSLayoutConstraint activateConstraints:@[
            [column.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:24],
            [column.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kMargin],
            [column.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kMargin],
            [inner.topAnchor constraintEqualToAnchor:column.bottomAnchor constant:8],
            [inner.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [inner.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [inner.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        ]];
    } else {
        UIScrollView *scroll = [UIScrollView new];
        scroll.alwaysBounceVertical = YES;
        scroll.showsVerticalScrollIndicator = NO;
        scroll.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:scroll];
        [scroll addSubview:column];
        UILayoutGuide *frame = scroll.frameLayoutGuide, *content = scroll.contentLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
            [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [column.topAnchor constraintEqualToAnchor:content.topAnchor constant:24],
            [column.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-24],
            [column.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:kMargin],
            [column.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-kMargin],
            [column.widthAnchor constraintEqualToAnchor:frame.widthAnchor constant:-2 * kMargin],
        ]];
    }

    [NSLayoutConstraint activateConstraints:@[
        [halo.leadingAnchor constraintEqualToAnchor:strip.leadingAnchor],
        [halo.topAnchor constraintEqualToAnchor:strip.topAnchor],
        [halo.bottomAnchor constraintEqualToAnchor:strip.bottomAnchor],
        [halo.widthAnchor constraintEqualToConstant:88],
        [halo.heightAnchor constraintEqualToConstant:88],
        [_hero.centerXAnchor constraintEqualToAnchor:halo.centerXAnchor],
        [_hero.centerYAnchor constraintEqualToAnchor:halo.centerYAnchor],
        [list.topAnchor constraintEqualToAnchor:card.topAnchor],
        [list.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [list.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [list.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
    ]];
}

- (void)navigationController:(UINavigationController *)nav willShowViewController:(UIViewController *)page animated:(BOOL)animated {
    [nav setNavigationBarHidden:page == nav.viewControllers.firstObject animated:animated];
}

// The symbol bounces the first time the page lands; the page is already on screen during the
// swipe that brings it in, so nothing else animates. iOS 16 has no symbol effects and skips it.
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_shown) return;
    _shown = YES;
    if (@available(iOS 17.0, *)) [_hero addSymbolEffect:[NSClassFromString(@"NSSymbolBounceEffect") effect]];
}

@end

#pragma mark - the tour

@interface SGOnboardingController : UIViewController <UIPageViewControllerDataSource, UIPageViewControllerDelegate>
@end

@implementation SGOnboardingController {
    UIPageViewController *_pager;
    NSArray<SGTourPage *> *_pages;
    UIPageControl *_dots;
    UIButton *_primary;
    NSDictionary<NSString *, NSNumber *> *_before;   // every switch as the tour found it
}

- (instancetype)init {
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    return self;
}

- (SGTourPage *)pageWithSymbol:(NSString *)symbol heading:(NSString *)heading body:(NSString *)body rows:(NSArray<SGTourRow *> *)rows {
    SGTourPage *page = [SGTourPage new];
    page.symbol = symbol; page.heading = heading; page.body = body; page.rows = rows;
    page.owner = self;
    page.index = (NSInteger)_pages.count;
    return page;
}

// The tab editor of the Navbar page, over the scrim instead of its own black, in a navigation
// controller of its own so Add a tab has somewhere to push.
- (SGTourPage *)navbarPage {
    SGTourPage *page = [self pageWithSymbol:@"dock.rectangle" heading:@"Your tabs." body:@"Drag to reorder, tap to hide, add any Spotify link as a tab of its own. The bar follows straight away." rows:@[]];
    UIViewController *editor = SGNavbarEditorPage();
    editor.view.backgroundColor = UIColor.clearColor;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editor];
    nav.navigationBarHidden = YES;
    nav.delegate = page;
    nav.view.backgroundColor = UIColor.clearColor;
    page.embedded = nav;
    return page;
}

- (NSArray<SGTourPage *> *)buildPages {
    __weak typeof(self) weakSelf = self;
    SGTourRow *glass = switchRow(@"drop.fill", @"Liquid Glass UI", @"Spotify's own glass bars and sheets, the tab bar, search field, now playing bar, artwork background and lyrics", SGKeySpotifyGlass, NO);
    glass.changed = ^(BOOL on) { SGSetLiquidGlassUI(on); };
    SGTourRow *premium = switchRow(@"crown.fill", @"Spoof Premium", @"Free accounts only", SGKeyFakePremium, NO);
    premium.warning = SGFakePremiumWarning;
    NSMutableArray *pages = [NSMutableArray array];
    _pages = pages;
    [pages addObject:[self pageWithSymbol:@"music.note" heading:@"Spotify, in glass." body:@"Spotify with a Liquid Glass rebuild on top. Every piece sits behind its own switch; the pages that follow are the ones worth choosing now." rows:@[
        plainRow(@"play.circle.fill", @"Glass player and now playing bar", @"The header, the bar, search and lyrics in glass"),
        plainRow(@"moon.fill", @"Pure black AMOLED", @"With a Home gradient in any of eight colours"),
        plainRow(@"dock.rectangle", @"A tab bar you compose", @"Reorder, hide, add any Spotify link"),
        plainRow(@"flag.fill", @"Every flag Spotify ships", @"Searchable, with the features it never released"),
    ]]];
    [pages addObject:[self pageWithSymbol:@"circle.lefthalf.filled" heading:@"Your look." body:@"Everything starts off. Switch on what you like now, change any time in Mod Settings." rows:@[
        glass,
        switchRow(@"moon.fill", @"AMOLED background", @"Pure black instead of Spotify's dark grey", SGKeyAmoled, NO),
        switchRow(@"paintpalette.fill", @"Home gradient", @"A wash of colour behind the top of Home", SGKeyHomeGradient, NO),
    ]]];
    [pages addObject:[self pageWithSymbol:@"eye.slash.fill" heading:@"Premium and ads." body:@"The ad switches come from EeveeSpotify, off until switched on and not needed on a Premium account. Telemetry blocking is on from the start." rows:@[
        premium,
        switchRow(@"speaker.slash.fill", @"Hide ads", @"Ad services never start, ad slots leave Home and Search", SGKeyHideAds, NO),
        switchRow(@"hand.raised.fill", @"Hide upsells", @"Premium prompts, banners and sheets dropped", SGKeyHideUpsells, NO),
        switchRow(@"antenna.radiowaves.left.and.right.slash", @"Block telemetry", @"Analytics requests answered empty instead of let out", SGKeyBlockTelemetry, YES),
    ]]];
    SGTourRow *lyricsOnly = switchRow(@"rectangle.compress.vertical", @"Only the lyrics", @"Hides every card under the player except lyrics: about the artist, videos, song DNA, credits, merch and the rest", SGKeyPlayerLyricsOnly, NO);
    lyricsOnly.changed = ^(BOOL on) { SGSetPlayerLyricsOnly(on); };
    [pages addObject:[self pageWithSymbol:@"rectangle.compress.vertical" heading:@"Declutter." body:@"The player, down to the music. Every piece has a switch of its own under Player in Mod Settings." rows:@[lyricsOnly]]];
    [pages addObject:[self navbarPage]];
    [pages addObject:[self pageWithSymbol:@"slider.horizontal.3" heading:@"Everything lives in Mod Settings." body:@"Hold Home on the tab bar to open it from anywhere. It is also the first row of the side drawer behind your avatar, and the last row of Spotify's Settings. Every switch, the tab bar editor and all of Spotify's flags.\n\nFree and open source. A star is what keeps it going." rows:@[
        actionRow(@"star.fill", @"Star on GitHub", @"skopevoj/spoti.pw", ^{ SGOpenURL(SGRepoURL); }),
        actionRow(@"square.and.arrow.up", @"Share spoti.pw", @"Send the site to someone", ^{ [weakSelf share]; }),
    ]]];
    return pages;
}

static UIButton *glassButton(NSString *title, BOOL prominent) {
    UIButtonConfiguration *config;
    if (@available(iOS 26.0, *)) {
        config = prominent ? [UIButtonConfiguration prominentGlassButtonConfiguration] : [UIButtonConfiguration glassButtonConfiguration];
    } else {
        config = prominent ? [UIButtonConfiguration filledButtonConfiguration] : [UIButtonConfiguration grayButtonConfiguration];
    }
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.baseBackgroundColor = prominent ? SGGreen() : nil;
    config.baseForegroundColor = prominent ? UIColor.blackColor : UIColor.whiteColor;
    config.contentInsets = prominent ? NSDirectionalEdgeInsetsMake(15, 20, 15, 20) : NSDirectionalEdgeInsetsMake(9, 16, 9, 16);
    UIFont *font = [UIFont systemFontOfSize:prominent ? 17 : 15 weight:UIFontWeightSemibold];
    config.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{NSFontAttributeName: font}];
    UIButton *button = [UIButton buttonWithConfiguration:config primaryAction:nil];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];

    _pager = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                             navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                           options:nil];
    _pager.dataSource = self;
    _pager.delegate = self;
    [self buildPages];
    NSMutableDictionary *before = [NSMutableDictionary dictionary];
    for (SGTourRow *row in self.switches) before[row.key] = @(SGFlag(row.key, row.defaultOn));
    _before = before;
    [_pager setViewControllers:@[_pages.firstObject] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
    [self addChildViewController:_pager];
    _pager.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_pager.view];
    [_pager didMoveToParentViewController:self];

    UIButton *skip = glassButton(@"Skip", NO);
    [skip addTarget:self action:@selector(finish) forControlEvents:UIControlEventTouchUpInside];
    _dots = [UIPageControl new];
    _dots.numberOfPages = (NSInteger)_pages.count;
    _dots.currentPageIndicatorTintColor = UIColor.whiteColor;
    _dots.pageIndicatorTintColor = [UIColor colorWithWhite:1 alpha:0.3];
    _dots.userInteractionEnabled = NO;
    _dots.translatesAutoresizingMaskIntoConstraints = NO;
    _primary = glassButton(@"Continue", YES);
    [_primary addTarget:self action:@selector(advance) forControlEvents:UIControlEventTouchUpInside];
    for (UIView *v in @[skip, _dots, _primary]) [self.view addSubview:v];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_pager.view.topAnchor constraintEqualToAnchor:safe.topAnchor constant:52],
        [_pager.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_pager.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_pager.view.bottomAnchor constraintEqualToAnchor:_dots.topAnchor constant:-4],
        [skip.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [skip.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kMargin],
        [_dots.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_dots.bottomAnchor constraintEqualToAnchor:_primary.topAnchor constant:-8],
        [_primary.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kMargin],
        [_primary.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kMargin],
        [_primary.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16],
    ]];
}

- (NSArray<SGTourRow *> *)switches {
    NSMutableArray *rows = [NSMutableArray array];
    for (SGTourPage *page in _pages) {
        for (SGTourRow *row in page.rows) if (row.kind == SGTourRowSwitch) [rows addObject:row];
    }
    return rows;
}

- (NSInteger)current {
    return ((SGTourPage *)_pager.viewControllers.firstObject).index;
}

// The hooks read every switch here at launch, so a changed one ends the tour in a restart.
- (BOOL)changed {
    for (SGTourRow *row in self.switches) {
        if (SGFlag(row.key, row.defaultOn) != _before[row.key].boolValue) return YES;
    }
    return NO;
}

- (void)refresh {
    NSInteger index = self.current;
    _dots.currentPage = index;
    BOOL last = index == (NSInteger)_pages.count - 1;
    NSString *title = !last ? @"Continue" : self.changed ? @"Restart Spotify" : @"Start listening";
    UIButtonConfiguration *config = _primary.configuration;
    config.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]}];
    _primary.configuration = config;
}

- (void)advance {
    NSInteger next = self.current + 1;
    if (next >= (NSInteger)_pages.count) {
        [self finish];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [_pager setViewControllers:@[_pages[(NSUInteger)next]] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:^(BOOL done) {
        [weakSelf refresh];
    }];
    [self refresh];
}

// A switch the hooks read at launch only shows after one: the tour saves and quits, and the next
// tap on the icon comes up the chosen way.
- (void)finish {
    SGSetEnabled(SGKeyOnboardingSeen, YES);
    if (self.changed) {
        SGRestartSpotify();
        return;
    }
    [self dismissViewControllerAnimated:YES completion:^{ SGShowSigningFixIfPending(); }];
}

- (void)share {
    UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[@"Spotify, in glass.", [NSURL URLWithString:SGSiteURL]] applicationActivities:nil];
    sheet.popoverPresentationController.sourceView = self.view;
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark paging

- (UIViewController *)pageViewController:(UIPageViewController *)pager viewControllerBeforeViewController:(SGTourPage *)page {
    return page.index > 0 ? _pages[(NSUInteger)page.index - 1] : nil;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pager viewControllerAfterViewController:(SGTourPage *)page {
    return page.index + 1 < (NSInteger)_pages.count ? _pages[(NSUInteger)page.index + 1] : nil;
}

- (void)pageViewController:(UIPageViewController *)pager didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previous transitionCompleted:(BOOL)completed {
    [self refresh];
}

@end

#pragma mark - entry

static __weak SGOnboardingController *sg_tour;

BOOL SGOnboardingShowing(void) {
    return sg_tour != nil;
}

void SGShowOnboarding(void) {
    if (sg_tour) return;
    UIViewController *top = SGTopController();
    // Presenting from an alert lands nowhere; the tour waits for it to go.
    if (!top || [top isKindOfClass:UIAlertController.class]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ SGShowOnboarding(); });
        return;
    }
    SGOnboardingController *tour = [SGOnboardingController new];
    sg_tour = tour;
    [top presentViewController:tour animated:YES completion:nil];
}
