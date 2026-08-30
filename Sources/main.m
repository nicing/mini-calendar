#import <AppKit/AppKit.h>
#import "MCData.h"
#import "MCFont.h"
#import "MCCalendarView.h"

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
    [text drawAtPoint:NSMakePoint(10.5 - textSize.width / 2, 2.4) withAttributes:attributes];

    [image unlockFocus];
    image.template = YES;
    return image;
}

static NSVisualEffectView *MCVibrancyContainerForContent(NSView *content, NSRect frame) {
    content.frame = NSMakeRect(0, 0, NSWidth(frame), NSHeight(frame));
    content.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    NSVisualEffectView *vibrancy = [[NSVisualEffectView alloc] initWithFrame:frame];
    vibrancy.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    vibrancy.material = NSVisualEffectMaterialPopover;
    vibrancy.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    vibrancy.state = NSVisualEffectStateActive;
    [vibrancy addSubview:content];
    return vibrancy;
}

static NSView *MCGlassContainerForContent(NSView *content, NSRect frame) {
    content.frame = NSMakeRect(0, 0, NSWidth(frame), NSHeight(frame));
    content.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    if (@available(macOS 26.0, *)) {
        NSView *container = [[NSView alloc] initWithFrame:frame];
        container.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

        NSGlassEffectView *glass = [[NSGlassEffectView alloc] initWithFrame:frame];
        glass.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        glass.style = NSGlassEffectViewStyleRegular;
        glass.cornerRadius = 0;
        glass.contentView = [[NSView alloc] initWithFrame:glass.bounds];
        [container addSubview:glass];
        [container addSubview:content];
        return container;
    }

    return MCVibrancyContainerForContent(content, frame);
}

static NSView *MCFullWindowGlassContainer(NSView *content, NSRect frame) {
    NSView *stage = [[NSView alloc] initWithFrame:frame];
    stage.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    content.frame = NSMakeRect(0, 0, 390, 700);
    content.autoresizingMask = NSViewWidthSizable;
    [stage addSubview:content];
    return MCGlassContainerForContent(stage, frame);
}

@interface MCAppDelegate : NSObject <NSApplicationDelegate>

@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSPanel *window;
@property(nonatomic, strong) MCCalendarView *calendarView;
@property(nonatomic, strong) NSTimer *midnightTimer;

@end

@implementation MCAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.calendarView = [[MCCalendarView alloc]
        initWithFrame:NSMakeRect(0, 0, 390, 700)
             defaults:NSUserDefaults.standardUserDefaults
    ];

    self.window = [[NSPanel alloc]
        initWithContentRect:NSMakeRect(0, 0, 390, 700)
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
    self.window.opaque = NO;
    self.window.backgroundColor = NSColor.clearColor;
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
    self.window.contentMinSize = NSMakeSize(390, 700);
    self.window.contentMaxSize = NSMakeSize(390, 700);
    NSRect fullWindowBounds = self.window.contentView.bounds;
    self.window.contentView = MCFullWindowGlassContainer(
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

@end

static NSEvent *MCTestScrollEvent(int32_t horizontalDelta, int32_t verticalDelta) {
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
    CGEventSetLocation(cgEvent, CGPointMake(100, 100));
    NSEvent *event = [NSEvent eventWithCGEvent:cgEvent];
    CFRelease(cgEvent);
    return event;
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
    if (!MCRegisterBundledFonts()) return 24;
    NSFont *latinFont = MCLatinFont(16, NSFontWeightSemibold);
    if (![latinFont.fontName containsString:@"MiSansLatin"]) return 25;
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
        initWithFrame:NSMakeRect(0, 0, 390, 700)
              defaults:gestureDefaults
        systemIntegrationEnabled:NO
    ];
    NSTextField *todoField = [gestureView valueForKey:@"todoField"];
    if (!todoField.isEditable || !todoField.isSelectable || !todoField.isEnabled) return 16;
    if (![todoField acceptsFirstMouse:nil]) return 17;
    NSTextField *editTodoField = [gestureView valueForKey:@"editTodoField"];
    if (!editTodoField.isEditable || !editTodoField.isSelectable || !editTodoField.isHidden) return 21;
    NSPoint todoCenter = NSMakePoint(NSMidX(todoField.frame), NSMidY(todoField.frame));
    NSView *gestureRoot = MCFullWindowGlassContainer(
        gestureView,
        NSMakeRect(0, 0, 390, 700)
    );
    NSPoint rootTodoCenter = [gestureView convertPoint:todoCenter toView:gestureRoot];
    if ([gestureRoot hitTest:rootTodoCenter] != todoField) return 18;
    NSWindow *interactionWindow = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 390, 700)
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
    CGFloat interactionRowCenterY = todoField.frame.origin.y + 49 + 18.5;
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
    [previewStore addTitle:@"整理今天的计划" forDate:today];
    [previewStore addTitle:@"回复两封邮件" forDate:today];
    [previewStore addTitle:@"晚间散步" forDate:today];
    NSDictionary *completedItem = [previewStore itemsForDate:today].firstObject;
    [previewStore toggleItemWithID:completedItem[@"id"]];

    MCCalendarView *view = [[MCCalendarView alloc]
        initWithFrame:NSMakeRect(0, 0, 390, 700)
              defaults:defaults
        systemIntegrationEnabled:NO
    ];
    if ([calendarMode isEqualToString:@"week"]) {
        [view showWeekView];
    }
    NSView *root = MCVibrancyContainerForContent(view, NSMakeRect(0, 0, 390, 700));
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
