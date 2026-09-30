#import <AppKit/AppKit.h>
#import "MCData.h"
#import "MCFont.h"
#import "MCCalendarView.h"
#import "MCSettingsWindowController.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat MCWindowWidth = 390;
static const CGFloat MCWindowHeight = 700;

static NSColor *MCSolidPanelBackgroundColor(void) {
    return [NSColor colorWithName:@"MiniCalendarSolidPanelBackground"
                  dynamicProvider:^NSColor *(NSAppearance *appearance) {
        NSAppearanceName match = [appearance bestMatchFromAppearancesWithNames:
            @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]
        ];
        if ([match isEqualToString:NSAppearanceNameDarkAqua]) {
            return [NSColor colorWithSRGBRed:0.110 green:0.110 blue:0.118 alpha:1.0];
        }
        return NSColor.whiteColor;
    }];
}

@interface MCSolidBackgroundView : NSView
@end

@implementation MCSolidBackgroundView

- (BOOL)wantsUpdateLayer {
    return YES;
}

- (void)updateLayer {
    self.layer.backgroundColor = [MCSolidPanelBackgroundColor()
        colorUsingColorSpace:NSColorSpace.sRGBColorSpace].CGColor;
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self setNeedsDisplay:YES];
}

@end

static NSImage *MCStatusImage(NSDate *date) {
    NSInteger day = [MCCalendar() component:NSCalendarUnitDay fromDate:date];
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(21, 19)];
    [image lockFocus];

    [NSColor.labelColor setStroke];
    NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1.5, 1.5, 18, 16)
                                                        xRadius:3
                                                        yRadius:3];
    body.lineWidth = 1.35;
    [body stroke];

    NSBezierPath *line = [NSBezierPath bezierPath];
    [line moveToPoint:NSMakePoint(2.2, 13.1)];
    [line lineToPoint:NSMakePoint(18.8, 13.1)];
    line.lineWidth = 1.25;
    [line stroke];

    NSString *text = [NSString stringWithFormat:@"%ld", (long)day];
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:day >= 10 ? 9 : 10
                                              weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: NSColor.labelColor,
    };
    NSSize textSize = [text sizeWithAttributes:attributes];
    CGFloat textY = day >= 10 ? 2.4 : 1.4;
    [text drawAtPoint:NSMakePoint(10.5 - textSize.width / 2, textY)
       withAttributes:attributes];

    [image unlockFocus];
    image.template = YES;
    return image;
}

static NSView *MCSolidContainerForContent(NSView *content, NSRect frame) {
    content.frame = NSMakeRect(0, 0, NSWidth(frame), NSHeight(frame));
    content.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    MCSolidBackgroundView *container = [[MCSolidBackgroundView alloc] initWithFrame:frame];
    container.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    container.wantsLayer = YES;
    [container addSubview:content];
    return container;
}

static NSView *MCFullWindowSolidContainer(NSView *content, NSRect frame) {
    NSView *stage = [[NSView alloc] initWithFrame:frame];
    stage.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    content.frame = NSMakeRect(0, 0, MCWindowWidth, MCWindowHeight);
    content.autoresizingMask = NSViewWidthSizable;
    [stage addSubview:content];
    return MCSolidContainerForContent(stage, frame);
}

static NSArray<NSNumber *> *MCVersionNumbers(NSString *version) {
    if (![version isKindOfClass:NSString.class]) {
        return nil;
    }
    NSString *number = [version hasPrefix:@"v"] || [version hasPrefix:@"V"]
        ? [version substringFromIndex:1] : version;
    NSArray<NSString *> *parts = [number componentsSeparatedByString:@"."];
    if (parts.count == 0 || parts.count > 4) {
        return nil;
    }
    NSCharacterSet *nonDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    NSMutableArray<NSNumber *> *numbers = [NSMutableArray arrayWithCapacity:parts.count];
    for (NSString *part in parts) {
        if (part.length == 0 || [part rangeOfCharacterFromSet:nonDigits].location != NSNotFound) {
            return nil;
        }
        [numbers addObject:@(part.longLongValue)];
    }
    return numbers;
}

static NSComparisonResult MCCompareVersions(NSString *candidate, NSString *installed) {
    NSArray<NSNumber *> *candidateNumbers = MCVersionNumbers(candidate);
    NSArray<NSNumber *> *installedNumbers = MCVersionNumbers(installed);
    if (!candidateNumbers || !installedNumbers) {
        return NSOrderedSame;
    }
    NSUInteger count = MAX(candidateNumbers.count, installedNumbers.count);
    for (NSUInteger index = 0; index < count; index++) {
        long long left = index < candidateNumbers.count
            ? candidateNumbers[index].longLongValue : 0;
        long long right = index < installedNumbers.count
            ? installedNumbers[index].longLongValue : 0;
        if (left < right) return NSOrderedAscending;
        if (left > right) return NSOrderedDescending;
    }
    return NSOrderedSame;
}

@interface MCAppDelegate : NSObject <NSApplicationDelegate>

@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSPanel *window;
@property(nonatomic, strong) MCCalendarView *calendarView;
@property(nonatomic, strong) NSTimer *midnightTimer;
@property(nonatomic, strong) NSTimer *updateTimer;
@property(nonatomic) BOOL updateCheckInProgress;
@property(nonatomic, copy) NSString *pendingUpdateVersion;
@property(nonatomic, strong) NSURL *pendingUpdateURL;

- (void)checkForUpdates:(id)sender;
- (void)checkForUpdatesAutomatically;
- (void)showUpdateVersion:(NSString *)version URL:(NSURL *)URL;

@end

@implementation MCAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.calendarView = [[MCCalendarView alloc]
        initWithFrame:NSMakeRect(0, 0, MCWindowWidth, MCWindowHeight)
             defaults:NSUserDefaults.standardUserDefaults
    ];

    self.window = [[NSPanel alloc]
        initWithContentRect:NSMakeRect(0, 0, MCWindowWidth, MCWindowHeight)
                  styleMask:NSWindowStyleMaskTitled
                            | NSWindowStyleMaskClosable
                            | NSWindowStyleMaskMiniaturizable
                            | NSWindowStyleMaskResizable
                            | NSWindowStyleMaskFullSizeContentView
                    backing:NSBackingStoreBuffered
                      defer:NO
    ];
    self.window.title = @"极简日历";
    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.titlebarAppearsTransparent = YES;
    self.window.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
    self.window.opaque = YES;
    self.window.backgroundColor = MCSolidPanelBackgroundColor();
    self.window.hasShadow = YES;
    self.window.releasedWhenClosed = NO;
    self.window.hidesOnDeactivate = NO;
    self.window.floatingPanel = NO;
    self.window.level = NSNormalWindowLevel;
    self.window.becomesKeyOnlyIfNeeded = NO;
    self.window.animationBehavior = NSWindowAnimationBehaviorDocumentWindow;
    self.window.collectionBehavior =
        NSWindowCollectionBehaviorCanJoinAllSpaces
        | NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.window.contentMinSize = NSMakeSize(MCWindowWidth, MCWindowHeight);
    self.window.contentMaxSize = NSMakeSize(MCWindowWidth, MCWindowHeight);
    NSRect fullWindowBounds = self.window.contentView.bounds;
    self.window.contentView = MCFullWindowSolidContainer(
        self.calendarView,
        fullWindowBounds
    );
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
    if ([arguments containsObject:@"--week-view"]) {
        [self.calendarView showWeekView];
    }
    NSUInteger appearanceIndex = [arguments indexOfObject:@"--appearance"];
    if (appearanceIndex != NSNotFound && appearanceIndex + 1 < arguments.count) {
        NSString *mode = arguments[appearanceIndex + 1];
        if ([mode isEqualToString:@"dark"]) {
            self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        } else if ([mode isEqualToString:@"light"]) {
            self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        }
    }

    if (![self.window setFrameUsingName:@"MiniCalendarWindowFrame"]) {
        [self.window center];
    }
    [self.window setContentSize:NSMakeSize(MCWindowWidth, MCWindowHeight)];
    [self.window setFrameAutosaveName:@"MiniCalendarWindowFrame"];

    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:32];
    self.statusItem.visible = YES;
    self.statusItem.button.image = MCStatusImage([NSDate date]);
    self.statusItem.button.imagePosition = NSImageOnly;
    self.statusItem.button.toolTip = @"极简日历";
    self.statusItem.button.accessibilityLabel = @"极简日历";
    self.statusItem.button.target = self;
    self.statusItem.button.action = @selector(toggleWindow:);

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(systemDateChanged:)
                  name:NSCalendarDayChangedNotification object:nil];
    [center addObserver:self selector:@selector(systemDateChanged:)
                  name:NSSystemClockDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(systemDateChanged:)
                  name:NSSystemTimeZoneDidChangeNotification object:nil];
    [self scheduleMidnightRefresh];
    [self showWindow];
    [self.calendarView startSystemSync];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self checkForUpdatesAutomatically];
    });
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:24 * 60 * 60
                                                       target:self
                                                     selector:@selector(checkForUpdatesAutomatically)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)toggleWindow:(id)sender {
    if (self.window.visible && self.window.keyWindow) {
        [self.window orderOut:nil];
    } else {
        [self showWindow];
    }
}

- (void)showWindow {
    self.statusItem.visible = YES;
    [self.calendarView refreshToday];
    [self.calendarView refreshSystemData];
    [NSApplication.sharedApplication activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
    if (self.pendingUpdateVersion) {
        NSString *version = self.pendingUpdateVersion;
        NSURL *URL = self.pendingUpdateURL;
        self.pendingUpdateVersion = nil;
        self.pendingUpdateURL = nil;
        [self showUpdateVersion:version URL:URL];
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                    hasVisibleWindows:(BOOL)hasVisibleWindows {
    [self showWindow];
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

- (void)systemDateChanged:(NSNotification *)notification {
    [self.calendarView refreshToday];
    self.statusItem.button.image = MCStatusImage([NSDate date]);
    [self scheduleMidnightRefresh];
}

- (void)scheduleMidnightRefresh {
    [self.midnightTimer invalidate];
    NSCalendar *calendar = MCCalendar();
    NSDate *today = [calendar startOfDayForDate:[NSDate date]];
    NSDate *midnight = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:today options:0];
    self.midnightTimer = [[NSTimer alloc] initWithFireDate:[midnight dateByAddingTimeInterval:0.5]
                                                  interval:0
                                                    target:self
                                                  selector:@selector(midnightReached:)
                                                  userInfo:nil
                                                   repeats:NO];
    [NSRunLoop.mainRunLoop addTimer:self.midnightTimer forMode:NSRunLoopCommonModes];
}

- (void)midnightReached:(NSTimer *)timer {
    [self systemDateChanged:nil];
}

- (void)checkForUpdatesAutomatically {
    [self fetchLatestReleaseManually:NO];
}

- (void)checkForUpdates:(id)sender {
    (void)sender;
    [self fetchLatestReleaseManually:YES];
}

- (void)fetchLatestReleaseManually:(BOOL)manual {
    if (self.updateCheckInProgress) {
        if (manual) {
            [self showUpdateMessage:@"正在检查更新，请稍候。"];
        }
        return;
    }
    self.updateCheckInProgress = YES;
    NSURL *URL = [NSURL URLWithString:
        @"https://api.github.com/repos/nicing/mini-calendar/releases/latest"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:10];
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"MiniCalendar" forHTTPHeaderField:@"User-Agent"];
    NSURLSessionDataTask *task = [NSURLSession.sharedSession
        dataTaskWithRequest:request
         completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.updateCheckInProgress = NO;
            NSInteger status = [(NSHTTPURLResponse *)response statusCode];
            if (error || status != 200) {
                if (manual) {
                    [self showUpdateMessage:status == 404
                        ? @"GitHub 上暂时没有已发布的版本。"
                        : @"检查更新失败，请稍后重试。"];
                }
                return;
            }
            NSDictionary *release = data ? [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:nil] : nil;
            if (![release isKindOfClass:NSDictionary.class]) {
                if (manual) [self showUpdateMessage:@"无法读取 GitHub 的版本信息。"];
                return;
            }
            NSString *tag = release[@"tag_name"];
            NSString *page = release[@"html_url"];
            NSString *installed = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
            NSURL *releaseURL = [page isKindOfClass:NSString.class]
                ? [NSURL URLWithString:page] : nil;
            NSArray *assets = release[@"assets"];
            BOOL hasDMG = NO;
            if ([assets isKindOfClass:NSArray.class]) {
                for (id asset in assets) {
                    if ([asset isKindOfClass:NSDictionary.class]
                        && [asset[@"name"] isKindOfClass:NSString.class]
                        && [asset[@"name"] hasSuffix:@".dmg"]) {
                        hasDMG = YES;
                        break;
                    }
                }
            }
            BOOL validPage = [releaseURL.scheme isEqualToString:@"https"]
                && [releaseURL.host isEqualToString:@"github.com"]
                && [releaseURL.path hasPrefix:@"/nicing/mini-calendar/releases/"];
            if (!MCVersionNumbers(tag) || !validPage) {
                if (manual) [self showUpdateMessage:@"无法读取 GitHub 的版本信息。"];
                return;
            }
            if (!hasDMG) {
                if (manual) [self showUpdateMessage:@"GitHub 上暂时没有可下载的安装包。"];
                return;
            }
            if (MCCompareVersions(tag, installed) != NSOrderedDescending) {
                if (manual) [self showUpdateMessage:@"当前已是最新版本。"];
                return;
            }
            NSString *version = [tag hasPrefix:@"v"] || [tag hasPrefix:@"V"]
                ? [tag substringFromIndex:1] : tag;
            NSString *lastNotified = [NSUserDefaults.standardUserDefaults
                stringForKey:@"MiniCalendarLastNotifiedUpdateVersion"];
            if (!manual && [lastNotified isEqualToString:version]) {
                return;
            }
            [NSUserDefaults.standardUserDefaults setObject:version
                                                    forKey:@"MiniCalendarLastNotifiedUpdateVersion"];
            if (!self.window.visible) {
                self.pendingUpdateVersion = version;
                self.pendingUpdateURL = releaseURL;
                return;
            }
            [self showUpdateVersion:version URL:releaseURL];
        });
    }];
    [task resume];
}

- (void)showUpdateMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"检查更新";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"好"];
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

- (void)showUpdateVersion:(NSString *)version URL:(NSURL *)URL {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"极简日历 %@ 已发布", version];
    NSString *installed = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"未知";
    alert.informativeText = [NSString stringWithFormat:
        @"当前版本 %@。可以前往 GitHub 下载新版本。", installed];
    [alert addButtonWithTitle:@"查看更新"];
    [alert addButtonWithTitle:@"稍后"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) {
            [NSWorkspace.sharedWorkspace openURL:URL];
        }
    }];
}

@end

static NSEvent *MCTestScrollEventAtPoint(int32_t horizontalDelta,
                                         int32_t verticalDelta,
                                         NSPoint point) {
    CGEventRef cgEvent = CGEventCreateScrollWheelEvent(
        NULL,
        kCGScrollEventUnitLine,
        2,
        verticalDelta,
        horizontalDelta
    );
    if (!cgEvent) {
        return nil;
    }
    CGEventSetLocation(cgEvent, CGPointMake(point.x, point.y));
    NSEvent *event = [NSEvent eventWithCGEvent:cgEvent];
    CFRelease(cgEvent);
    return event;
}

static NSEvent *MCTestScrollEvent(int32_t horizontalDelta, int32_t verticalDelta) {
    return MCTestScrollEventAtPoint(horizontalDelta, verticalDelta, NSMakePoint(100, 100));
}

static NSEvent *MCTestMouseEvent(NSView *view, NSPoint point) {
    NSPoint windowPoint = [view convertPoint:point toView:nil];
    return [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
                              location:windowPoint
                         modifierFlags:0
                             timestamp:NSProcessInfo.processInfo.systemUptime
                          windowNumber:view.window.windowNumber
                               context:nil
                           eventNumber:1
                            clickCount:1
                              pressure:1.0];
}

static int MCRunSelfTests(void) {
    [NSApplication sharedApplication];
    if (MCCompareVersions(@"v1.10.0", @"1.9.0") != NSOrderedDescending
        || MCCompareVersions(@"1.1", @"1.1.0") != NSOrderedSame
        || MCCompareVersions(@"v1.0.9", @"1.1.0") != NSOrderedAscending
        || MCVersionNumbers(@"1.2-beta") != nil) return 41;
    if (!MCRegisterBundledFonts()) return 24;
    NSArray<NSString *> *accentIdentifiers = MCAccentColorIdentifiers();
    if (accentIdentifiers.count != 11
        || ![accentIdentifiers.firstObject isEqualToString:@"red"]
        || ![MCAccentColorName(@"violet") isEqualToString:@"亮紫色"]
        || !MCAccentColorForIdentifier(@"blue")) return 38;
    MCSettingsWindowController *settingsController =
        [[MCSettingsWindowController alloc] init];
    NSArray *swatchButtons = [settingsController valueForKey:@"swatchButtons"];
    if (swatchButtons.count != accentIdentifiers.count
        || NSWidth(settingsController.window.contentView.bounds) != 452) return 39;
    NSFont *latinFont = MCLatinFont(16, NSFontWeightSemibold);
    if (![latinFont.fontName containsString:@"MiSansLatin"]) return 25;
    NSArray<NSString *> *figmaIconNames = @[
        @"add", @"chevron-left", @"chevron-right", @"dashed-divider",
        @"date-separator", @"delete", @"divider", @"more", @"today",
        @"todo-complete", @"todo-incomplete"
    ];
    for (NSString *iconName in figmaIconNames) {
        NSURL *iconURL = [NSBundle.mainBundle URLForResource:iconName
                                              withExtension:@"svg"
                                               subdirectory:@"FigmaIcons"];
        if (!iconURL) return 40;
    }
    MCHolidayService *holidays = [[MCHolidayService alloc] init];
    MCHoliday *spring = [holidays holidayForDate:MCDateFromKey(@"2026-02-17")];
    MCHoliday *dayOff = [holidays holidayForDate:MCDateFromKey(@"2026-02-18")];
    MCHoliday *makeUp = [holidays holidayForDate:MCDateFromKey(@"2026-02-28")];
    if (![spring.label isEqualToString:@"春节"] || spring.kind != MCHolidayKindFestival) return 1;
    if (![dayOff.label isEqualToString:@"放假"] || dayOff.kind != MCHolidayKindDayOff) return 2;
    if (![makeUp.label isEqualToString:@"补班"] || makeUp.kind != MCHolidayKindMakeUpWork) return 3;

    NSString *lunar = [[[MCLunarService alloc] init] longTextForDate:MCDateFromKey(@"2026-07-25")];
    if (![lunar isEqualToString:@"农历六月十二"]) return 4;

    NSCalendar *calendar = MCCalendar();
    NSDate *july = MCDateFromKey(@"2026-07-01");
    NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:july];
    NSInteger daysBefore = (weekday - calendar.firstWeekday + 7) % 7;
    NSDate *gridStart = [calendar dateByAddingUnit:NSCalendarUnitDay value:-daysBefore toDate:july options:0];
    if (![MCDateKey(gridStart) isEqualToString:@"2026-06-29"]) return 5;

    NSDate *festivalDate = nil;
    MCHoliday *nextFestival = [holidays nextFestivalOnOrAfterDate:MCDateFromKey(@"2026-07-25")
                                                     festivalDate:&festivalDate];
    if (![nextFestival.label isEqualToString:@"中秋"]
        || ![MCDateKey(festivalDate) isEqualToString:@"2026-09-25"]) return 6;
    NSInteger holidayDays = [calendar components:NSCalendarUnitDay
                                        fromDate:MCDateFromKey(@"2026-07-25")
                                          toDate:festivalDate
                                         options:0].day;
    if (holidayDays != 62) return 7;

    NSString *suiteName = [NSString stringWithFormat:@"MiniCalendarTests.%@", NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    MCTodoStore *store = [[MCTodoStore alloc] initWithDefaults:defaults];
    NSDate *referenceDate = MCDateFromKey(@"2026-07-25");
    [store addTitle:@"完成极简日历" forDate:referenceDate];
    if ([store itemsForDate:referenceDate].count != 1) return 8;
    NSDictionary *item = [store itemsForDate:referenceDate].firstObject;
    [store updateItemWithID:item[@"id"] title:@"更新后的 Todo"];
    if (![[store itemsForDate:referenceDate].firstObject[@"title"]
            isEqualToString:@"更新后的 Todo"]) return 20;
    [store toggleItemWithID:item[@"id"]];
    if (![[store itemsForDate:referenceDate].firstObject[@"done"] boolValue]) return 9;
    [store deleteItemWithID:item[@"id"]];
    if ([store itemsForDate:referenceDate].count != 0) return 10;
    [defaults removePersistentDomainForName:suiteName];

    NSUserDefaults *gestureDefaults = [[NSUserDefaults alloc] initWithSuiteName:
        [NSString stringWithFormat:@"MiniCalendarGestureTests.%@", NSUUID.UUID.UUIDString]
    ];
    MCCalendarView *gestureView = [[MCCalendarView alloc]
        initWithFrame:NSMakeRect(0, 0, MCWindowWidth, MCWindowHeight)
              defaults:gestureDefaults
        systemIntegrationEnabled:NO
    ];
    NSTextField *todoField = [gestureView valueForKey:@"todoField"];
    if (!todoField.isEditable || !todoField.isSelectable || !todoField.isEnabled) return 16;
    if (![todoField acceptsFirstMouse:nil]) return 17;
    if (NSMaxX(todoField.frame) != 356) return 37;
    NSTextField *editTodoField = [gestureView valueForKey:@"editTodoField"];
    if (!editTodoField.isEditable || !editTodoField.isSelectable || !editTodoField.isHidden) return 21;
    NSPoint todoCenter = NSMakePoint(NSMidX(todoField.frame), NSMidY(todoField.frame));
    NSView *gestureRoot = MCFullWindowSolidContainer(
        gestureView,
        NSMakeRect(0, 0, MCWindowWidth, MCWindowHeight)
    );
    NSPoint rootTodoCenter = [gestureView convertPoint:todoCenter toView:gestureRoot];
    if ([gestureRoot hitTest:rootTodoCenter] != todoField) return 18;
    NSWindow *interactionWindow = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, MCWindowWidth, MCWindowHeight)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    interactionWindow.contentView = gestureRoot;
    [interactionWindow makeKeyWindow];
    MCTodoStore *interactionStore = [gestureView valueForKey:@"previewTodoStore"];
    NSDate *interactionDate = [gestureView valueForKey:@"selectedDate"];
    [interactionStore addTitle:@"可编辑的 Todo" forDate:interactionDate];
    NSArray<NSDictionary *> *interactionRows = [interactionStore itemsForDate:interactionDate];
    [gestureView setValue:interactionRows forKey:@"visibleTodos"];
    [gestureView setValue:interactionRows forKey:@"agendaRows"];
    CGFloat interactionRowCenterY = todoField.frame.origin.y
        + (131 - 72.5) + 24;
    NSEvent *editClick = MCTestMouseEvent(
        gestureView,
        NSMakePoint(100, interactionRowCenterY)
    );
    [gestureView mouseDown:editClick];
    NSString *editingTodoID = [gestureView valueForKey:@"editingTodoID"];
    if (![editingTodoID isEqualToString:interactionRows.firstObject[@"id"]]
        || editTodoField.isHidden) return 22;
    if (editTodoField.currentEditor == nil
        || interactionWindow.firstResponder != editTodoField.currentEditor) return 26;
    [gestureView mouseDown:MCTestMouseEvent(
        gestureView,
        NSMakePoint(30, interactionRowCenterY)
    )];
    if (![[interactionStore itemsForDate:interactionDate].firstObject[@"done"] boolValue]) return 23;

    NSDate *gestureToday = [gestureView valueForKey:@"today"];
    NSDate *dayBeforeToday = [calendar dateByAddingUnit:NSCalendarUnitDay
                                                  value:-1
                                                 toDate:gestureToday
                                                options:0];
    [gestureView setValue:dayBeforeToday forKey:@"selectedDate"];
    [gestureView mouseDown:MCTestMouseEvent(gestureView, NSMakePoint(329, 58))];
    if (![calendar isDate:[gestureView valueForKey:@"selectedDate"]
            inSameDayAsDate:gestureToday]) return 27;

    NSDate *initialMonth = [gestureView valueForKey:@"displayedMonth"];
    [gestureView scrollWheel:MCTestScrollEvent(1, 0)];
    NSDate *nextMonth = [gestureView valueForKey:@"displayedMonth"];
    NSInteger monthDelta = [calendar components:NSCalendarUnitMonth
                                        fromDate:initialMonth
                                          toDate:nextMonth
                                         options:0].month;
    if (monthDelta != 1) return 11;
    [gestureView scrollWheel:MCTestScrollEvent(-1, 0)];
    if (![calendar isDate:[gestureView valueForKey:@"displayedMonth"]
           equalToDate:initialMonth
          toUnitGranularity:NSCalendarUnitMonth]) return 12;

    [gestureView scrollWheel:MCTestScrollEvent(0, 1)];
    if (![[gestureView valueForKey:@"weekViewEnabled"] boolValue]) return 13;
    NSDate *initialWeekDate = [gestureView valueForKey:@"selectedDate"];
    [gestureView scrollWheel:MCTestScrollEvent(1, 0)];
    NSDate *nextWeekDate = [gestureView valueForKey:@"selectedDate"];
    NSInteger weekDelta = [calendar components:NSCalendarUnitDay
                                       fromDate:initialWeekDate
                                         toDate:nextWeekDate
                                        options:0].day;
    if (weekDelta != 7) return 14;
    [gestureView scrollWheel:MCTestScrollEvent(0, -1)];
    if ([[gestureView valueForKey:@"weekViewEnabled"] boolValue]) return 15;

    NSPoint footerPoint = NSMakePoint(200, 680);
    [gestureView scrollWheel:MCTestScrollEventAtPoint(0, 1, footerPoint)];
    if (![[gestureView valueForKey:@"weekViewEnabled"] boolValue]) return 28;
    [gestureView scrollWheel:MCTestScrollEventAtPoint(0, -1, footerPoint)];
    if ([[gestureView valueForKey:@"weekViewEnabled"] boolValue]) return 29;

    NSPoint inputPoint = NSMakePoint(NSMidX(todoField.frame), NSMidY(todoField.frame));
    [todoField scrollWheel:MCTestScrollEventAtPoint(0, 1, inputPoint)];
    if (![[gestureView valueForKey:@"weekViewEnabled"] boolValue]) return 30;
    inputPoint = NSMakePoint(NSMidX(todoField.frame), NSMidY(todoField.frame));
    [todoField scrollWheel:MCTestScrollEventAtPoint(0, -1, inputPoint)];
    if ([[gestureView valueForKey:@"weekViewEnabled"] boolValue]) return 31;

    [gestureView updateTrackingAreas];
    NSTrackingArea *progressArea = [gestureView valueForKey:@"yearProgressTrackingArea"];
    if (!progressArea
        || NSMinX(progressArea.rect) != 0
        || NSWidth(progressArea.rect) != 390) return 32;
    if ([[gestureView valueForKey:@"yearProgressHovered"] boolValue]) return 33;
    if ([[gestureView valueForKey:@"yearProgressReveal"] doubleValue] != 0) return 34;
    [gestureView setValue:@YES forKey:@"yearProgressHovered"];
    [gestureView setValue:@0.5 forKey:@"yearProgressReveal"];
    if ([[gestureView valueForKey:@"shouldDrawYearProgressTooltip"] boolValue]) return 35;
    [gestureView setValue:@1.0 forKey:@"yearProgressReveal"];
    if (![[gestureView valueForKey:@"shouldDrawYearProgressTooltip"] boolValue]) return 36;

    NSLog(@"All MiniCalendar self-tests passed.");
    return 0;
}

static int MCRenderPreview(NSString *path, NSString *appearanceMode, NSString *calendarMode) {
    [NSApplication sharedApplication];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:
        [NSString stringWithFormat:@"MiniCalendarPreview.%@", NSUUID.UUID.UUIDString]
    ];
    MCTodoStore *previewStore = [[MCTodoStore alloc] initWithDefaults:defaults];
    NSDate *today = [MCCalendar() startOfDayForDate:[NSDate date]];
    BOOL matchesFigmaFixture = [calendarMode isEqualToString:@"figma"];
    if (matchesFigmaFixture) {
        [NSUserDefaults.standardUserDefaults setVolatileDomain:
            @{@"MiniCalendarAccentColor": @"red"}
                                                      forName:NSArgumentDomain];
    }
    NSDate *previewDate = matchesFigmaFixture
        ? MCDateFromKey(@"2026-08-30")
        : today;
    if (matchesFigmaFixture) {
        [previewStore addTitle:@"每周工作总结" forDate:previewDate];
        [previewStore addTitle:@"每周工作总结" forDate:previewDate];
        [previewStore addTitle:@"Jev 研究" forDate:previewDate];
        [previewStore addTitle:@"Jev 研究" forDate:previewDate];
        NSArray<NSDictionary *> *items = [previewStore itemsForDate:previewDate];
        [previewStore toggleItemWithID:items[2][@"id"]];
        [previewStore toggleItemWithID:items[3][@"id"]];
    } else {
        [previewStore addTitle:@"整理今天的计划" forDate:previewDate];
        [previewStore addTitle:@"回复两封邮件" forDate:previewDate];
        [previewStore addTitle:@"晚间散步" forDate:previewDate];
        NSDictionary *completedItem = [previewStore itemsForDate:previewDate].firstObject;
        [previewStore toggleItemWithID:completedItem[@"id"]];
    }

    MCCalendarView *view = [[MCCalendarView alloc]
        initWithFrame:NSMakeRect(0, 0, MCWindowWidth, MCWindowHeight)
              defaults:defaults
        systemIntegrationEnabled:NO
    ];
    if (matchesFigmaFixture) {
        [view setValue:MCDateFromKey(@"2026-08-27") forKey:@"today"];
        [view setValue:previewDate forKey:@"selectedDate"];
        [view setValue:MCDateFromKey(@"2026-08-01") forKey:@"displayedMonth"];
        [view showWeekView];
        [view showMonthView];
        NSArray<NSDictionary *> *items = [previewStore itemsForDate:previewDate];
        [view setValue:items forKey:@"visibleTodos"];
        [view setValue:items forKey:@"agendaRows"];
    } else if ([calendarMode isEqualToString:@"week"]) {
        [view showWeekView];
    } else if ([calendarMode isEqualToString:@"progress-hover"]) {
        [view setValue:@YES forKey:@"yearProgressHovered"];
        [view setValue:@1.0 forKey:@"yearProgressReveal"];
    } else if ([calendarMode isEqualToString:@"overdue"]) {
        NSDictionary *overdueTodo = @{
            @"kind": @"todo",
            @"id": @"preview-overdue",
            @"title": @"提交报销单",
            @"done": @NO,
            @"overdue": @YES,
            @"createdAt": [NSDate distantPast],
            @"time": @"",
        };
        NSDictionary *todayTodo = @{
            @"kind": @"todo",
            @"id": @"preview-today",
            @"title": @"回复两封邮件",
            @"done": @NO,
            @"overdue": @NO,
            @"createdAt": [NSDate date],
            @"time": @"",
        };
        NSArray<NSDictionary *> *todos = @[overdueTodo, todayTodo];
        [view setValue:todos forKey:@"visibleTodos"];
        [view setValue:todos forKey:@"agendaRows"];
    }
    NSRect previewFrame = NSMakeRect(0, 0, MCWindowWidth, MCWindowHeight);
    NSView *root = MCSolidContainerForContent(view, previewFrame);
    if ([appearanceMode isEqualToString:@"dark"]) {
        root.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    } else if ([appearanceMode isEqualToString:@"light"]) {
        root.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    }
    [root layoutSubtreeIfNeeded];
    [root displayIfNeeded];
    NSBitmapImageRep *bitmap = [root bitmapImageRepForCachingDisplayInRect:root.bounds];
    [root cacheDisplayInRect:root.bounds toBitmapImageRep:bitmap];
    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [png writeToFile:path atomically:YES] ? 0 : 1;
}

int main(void) {
    @autoreleasepool {
        NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
        if ([arguments containsObject:@"--self-test"]) {
            return MCRunSelfTests();
        }
        NSUInteger previewIndex = [arguments indexOfObject:@"--render-preview"];
        if (previewIndex != NSNotFound && previewIndex + 1 < arguments.count) {
            NSString *appearanceMode = previewIndex + 2 < arguments.count
                ? arguments[previewIndex + 2]
                : @"system";
            NSString *calendarMode = previewIndex + 3 < arguments.count
                ? arguments[previewIndex + 3]
                : @"month";
            return MCRenderPreview(arguments[previewIndex + 1], appearanceMode, calendarMode);
        }

        NSApplication *application = NSApplication.sharedApplication;
        MCAppDelegate *delegate = [[MCAppDelegate alloc] init];
        application.delegate = delegate;
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [application run];
    }
    return 0;
}
