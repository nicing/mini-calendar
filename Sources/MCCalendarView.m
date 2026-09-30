#import "MCCalendarView.h"
#import "MCData.h"
#import "MCFont.h"
#import "MCSettingsWindowController.h"
#import <CoreText/CoreText.h>
#import <QuartzCore/CADisplayLink.h>
#import <QuartzCore/CAMediaTimingFunction.h>
#import <QuartzCore/QuartzCore.h>

static const CGFloat MCViewWidth = 390;
static const CGFloat MCViewHeight = 700;
static const CGFloat MCGridX = 17.75;
static const CGFloat MCContentLeading = 33;
static const CGFloat MCContentRight = 356;
static const CGFloat MCAgendaMarkerLeading = MCContentLeading;
static const CGFloat MCInputTextLeading = 55;
static const CGFloat MCAgendaTextLeading = 57;
static const CGFloat MCHeaderControlX = 281;
static const CGFloat MCHeaderControlWidth = 26;
static const CGFloat MCHeaderIconInset = 3;
static const CGFloat MCHeaderIconSize = 20;
static const CGFloat MCHeaderTop = 45;
static const CGFloat MCHeaderYearOpticalOffsetY = 0.5;
static const CGFloat MCWeekdaysY = 89.5;
static const CGFloat MCGridY = 119;
static const CGFloat MCGridWidth = 353.5;
static const CGFloat MCCellHeight = 51.5;
static const CGFloat MCDateHighlightTopOffset = -2.5;
static const CGFloat MCDateHighlightStrokeOverflow = 0.5;
static const CGFloat MCTodoInputOffset = 72.5;
static const CGFloat MCTodoInputHeight = 40;
static const CGFloat MCAgendaOffset = 126;
static const CGFloat MCAgendaRowHeight = 48;
static const CGFloat MCAgendaMarkerBoxSize = 16;
static const CGFloat MCEventDotSize = 9;
static const CGFloat MCAgendaDividerHeight = 1.5;
static const CGFloat MCFooterTop = 662;
static const CGFloat MCFooterProgressHeight = 1;
static const CGFloat MCFooterProgressHoverPadding = 6;
static const CGFloat MCYearProgressTooltipHeight = 24;
static const CGFloat MCYearProgressTooltipArrowHeight = 6;
static const NSTimeInterval MCYearProgressRevealDuration = 1.0;
static const NSTimeInterval MCCalendarTransitionDuration = 0.22;
static const NSTimeInterval MCReducedMotionFadeDuration = 0.16;
static const NSTimeInterval MCCalendarRowStagger = 0.04;
static const CGFloat MCCalendarGestureAxisLockDistance = 10.0;
static const CGFloat MCCalendarGestureCommitDistance = 18.0;

static NSRect MCYearProgressHoverRect(void) {
    return NSMakeRect(0,
                      MCFooterTop - MCFooterProgressHoverPadding,
                      MCViewWidth,
                      MCFooterProgressHeight + MCFooterProgressHoverPadding * 2);
}

static NSRect MCYearProgressDisplayRect(void) {
    CGFloat top = MCFooterTop - MCYearProgressTooltipHeight
        - MCYearProgressTooltipArrowHeight - 4;
    return NSMakeRect(0,
                      top,
                      MCViewWidth,
                      MCFooterTop + MCFooterProgressHoverPadding - top);
}

typedef NS_ENUM(NSInteger, MCCalendarRowFilter) {
    MCCalendarRowFilterAll,
    MCCalendarRowFilterSelected,
    MCCalendarRowFilterOthers,
};

typedef NS_ENUM(NSInteger, MCCalendarGestureAxis) {
    MCCalendarGestureAxisUndetermined,
    MCCalendarGestureAxisHorizontal,
    MCCalendarGestureAxisVertical,
};

static CGFloat MCCubicBezierCoordinate(CGFloat t, CGFloat first, CGFloat second) {
    CGFloat inverse = 1.0 - t;
    return 3.0 * inverse * inverse * t * first
        + 3.0 * inverse * t * t * second
        + t * t * t;
}

static CGFloat MCEaseInOutProgress(CGFloat linearProgress) {
    // cubic-bezier(0.77, 0, 0.175, 1), solved for x with a bounded binary search.
    CGFloat lower = 0.0;
    CGFloat upper = 1.0;
    for (NSInteger iteration = 0; iteration < 14; iteration++) {
        CGFloat midpoint = (lower + upper) / 2.0;
        CGFloat x = MCCubicBezierCoordinate(midpoint, 0.77, 0.175);
        if (x < linearProgress) {
            lower = midpoint;
        } else {
            upper = midpoint;
        }
    }
    return MCCubicBezierCoordinate((lower + upper) / 2.0, 0.0, 1.0);
}

static CGFloat MCEaseOutProgress(CGFloat linearProgress) {
    // cubic-bezier(0.23, 1, 0.32, 1).
    CGFloat lower = 0.0;
    CGFloat upper = 1.0;
    for (NSInteger iteration = 0; iteration < 14; iteration++) {
        CGFloat midpoint = (lower + upper) / 2.0;
        CGFloat x = MCCubicBezierCoordinate(midpoint, 0.23, 0.32);
        if (x < linearProgress) {
            lower = midpoint;
        } else {
            upper = midpoint;
        }
    }
    return MCCubicBezierCoordinate((lower + upper) / 2.0, 1.0, 1.0);
}

static NSColor *MCSeparatorColor(NSView *view) {
    NSAppearanceName appearance = [view.effectiveAppearance bestMatchFromAppearancesWithNames:
        @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]
    ];
    return [appearance isEqualToString:NSAppearanceNameDarkAqua]
        ? [NSColor colorWithWhite:1.0 alpha:0.10]
        : [NSColor colorWithSRGBRed:0.898 green:0.898 blue:0.898 alpha:1.0];
}

static NSColor *MCAgendaDividerColor(NSView *view) {
    NSAppearanceName appearance = [view.effectiveAppearance bestMatchFromAppearancesWithNames:
        @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]
    ];
    return [appearance isEqualToString:NSAppearanceNameDarkAqua]
        ? [NSColor colorWithWhite:1.0 alpha:0.08]
        : [NSColor colorWithSRGBRed:0.925 green:0.925 blue:0.925 alpha:1.0];
}

static NSColor *MCPrimaryTextColor(NSView *view) {
    NSAppearanceName appearance = [view.effectiveAppearance bestMatchFromAppearancesWithNames:
        @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]
    ];
    return [appearance isEqualToString:NSAppearanceNameDarkAqua]
        ? NSColor.labelColor
        : [NSColor colorWithSRGBRed:0.149 green:0.149 blue:0.149 alpha:1.0];
}

static NSColor *MCSecondaryTextColor(NSView *view) {
    NSAppearanceName appearance = [view.effectiveAppearance bestMatchFromAppearancesWithNames:
        @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]
    ];
    return [appearance isEqualToString:NSAppearanceNameDarkAqua]
        ? NSColor.secondaryLabelColor
        : [NSColor colorWithSRGBRed:0.482 green:0.482 blue:0.482 alpha:1.0];
}

static NSColor *MCTertiaryTextColor(NSView *view) {
    NSAppearanceName appearance = [view.effectiveAppearance bestMatchFromAppearancesWithNames:
        @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]
    ];
    return [appearance isEqualToString:NSAppearanceNameDarkAqua]
        ? NSColor.tertiaryLabelColor
        : [NSColor colorWithSRGBRed:0.710 green:0.710 blue:0.710 alpha:1.0];
}

static NSString *MCHexStringForColor(NSColor *color) {
    NSColor *srgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace]
        ?: NSColor.blackColor;
    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;
    CGFloat alpha = 0;
    [srgb getRed:&red green:&green blue:&blue alpha:&alpha];
    return [NSString stringWithFormat:@"#%02X%02X%02X",
        (unsigned int)lrint(red * 255),
        (unsigned int)lrint(green * 255),
        (unsigned int)lrint(blue * 255)];
}

static NSImage *MCFigmaIcon(NSString *name, NSColor *tint) {
    static NSMutableDictionary<NSString *, NSImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSMutableDictionary alloc] init];
    });
    NSString *hex = MCHexStringForColor(tint);
    NSString *cacheKey = [NSString stringWithFormat:@"%@.%@", name, hex];
    NSImage *image = cache[cacheKey];
    if (image) {
        return image;
    }
    NSURL *url = [NSBundle.mainBundle URLForResource:name
                                      withExtension:@"svg"
                                       subdirectory:@"FigmaIcons"];
    NSString *svg = url ? [NSString stringWithContentsOfURL:url
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil] : nil;
    for (NSString *sourceColor in @[@"#E8585A", @"#7B7B7B", @"#B5B5B5",
                                     @"#262626", @"#E5E5E5"]) {
        svg = [svg stringByReplacingOccurrencesOfString:sourceColor
                                              withString:hex];
    }
    NSData *data = [svg dataUsingEncoding:NSUTF8StringEncoding];
    image = data ? [[NSImage alloc] initWithData:data] : nil;
    if (image) {
        cache[cacheKey] = image;
    }
    return image;
}

static CGFloat MCYearProgressForDate(NSCalendar *calendar, NSDate *date) {
    NSDate *yearStart = nil;
    NSTimeInterval yearDuration = 0;
    BOOL foundYear = [calendar rangeOfUnit:NSCalendarUnitYear
                                 startDate:&yearStart
                                  interval:&yearDuration
                                   forDate:date];
    if (!foundYear || yearDuration <= 0) {
        return 0;
    }
    CGFloat progress = [date timeIntervalSinceDate:yearStart] / yearDuration;
    return MIN(1, MAX(0, progress));
}

static NSColor *MCGlassControlFillColor(NSView *view) {
    NSAppearanceName appearance = [view.effectiveAppearance bestMatchFromAppearancesWithNames:
        @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]
    ];
    return [appearance isEqualToString:NSAppearanceNameDarkAqua]
        ? [NSColor colorWithWhite:1.0 alpha:0.10]
        : [NSColor colorWithWhite:0.0 alpha:0.045];
}

static NSColor *MCGlassControlFocusedBorderColor(NSView *view) {
    NSAppearanceName appearance = [view.effectiveAppearance bestMatchFromAppearancesWithNames:
        @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]
    ];
    return [appearance isEqualToString:NSAppearanceNameDarkAqua]
        ? [NSColor colorWithWhite:1.0 alpha:0.30]
        : [NSColor colorWithWhite:0.0 alpha:0.24];
}

@interface MCVerticallyCenteredTextFieldCell : NSTextFieldCell

@property(nonatomic) CGFloat opticalVerticalOffset;

@end

@implementation MCVerticallyCenteredTextFieldCell

- (NSRect)centeredTextRectForBounds:(NSRect)bounds {
    NSRect rect = [super drawingRectForBounds:bounds];
    rect.origin.x = bounds.origin.x;
    rect.size.width = bounds.size.width;
    NSFont *font = self.font ?: [NSFont systemFontOfSize:NSFont.systemFontSize];
    CGFloat textHeight = ceil(font.ascender - font.descender) + 2;
    rect.origin.y += floor((NSHeight(rect) - textHeight) / 2.0)
        + self.opticalVerticalOffset;
    rect.size.height = textHeight;
    return rect;
}

- (NSRect)drawingRectForBounds:(NSRect)bounds {
    return [self centeredTextRectForBounds:bounds];
}

- (void)editWithFrame:(NSRect)frame
               inView:(NSView *)controlView
                editor:(NSText *)fieldEditor
              delegate:(id)delegate
                 event:(NSEvent *)event {
    [super editWithFrame:[self centeredTextRectForBounds:frame]
                  inView:controlView
                   editor:fieldEditor
                 delegate:delegate
                    event:event];
}

- (void)selectWithFrame:(NSRect)frame
                 inView:(NSView *)controlView
                  editor:(NSText *)fieldEditor
                delegate:(id)delegate
                   start:(NSInteger)start
                  length:(NSInteger)length {
    [super selectWithFrame:[self centeredTextRectForBounds:frame]
                    inView:controlView
                     editor:fieldEditor
                   delegate:delegate
                      start:start
                     length:length];
}

@end

@interface MCFocusableTextField : NSTextField
@end

@implementation MCFocusableTextField

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    (void)event;
    return YES;
}

- (void)mouseDown:(NSEvent *)event {
    [NSApplication.sharedApplication activateIgnoringOtherApps:YES];
    [self.window makeKeyWindow];
    [self.window makeFirstResponder:self];
    [super mouseDown:event];
}

- (void)scrollWheel:(NSEvent *)event {
    if (self.superview) {
        [self.superview scrollWheel:event];
        return;
    }
    [super scrollWheel:event];
}

@end

@interface MCCalendarView ()

@property(nonatomic, strong) NSCalendar *calendar;
@property(nonatomic, strong) MCHolidayService *holidays;
@property(nonatomic, strong) MCLunarService *lunar;
@property(nonatomic, strong) MCSystemDataStore *systemStore;
@property(nonatomic, strong, nullable) MCTodoStore *previewTodoStore;
@property(nonatomic) BOOL systemIntegrationEnabled;
@property(nonatomic, strong) NSDate *today;
@property(nonatomic, strong) NSDate *selectedDate;
@property(nonatomic, strong) NSDate *displayedMonth;
@property(nonatomic, copy) NSArray<NSDate *> *gridDates;
@property(nonatomic, copy) NSArray<NSDictionary *> *visibleTodos;
@property(nonatomic, copy) NSArray<NSDictionary *> *visibleEvents;
@property(nonatomic, copy) NSArray<NSDictionary *> *agendaRows;
@property(nonatomic, strong) NSTextField *todoField;
@property(nonatomic, strong) NSTextField *editTodoField;
@property(nonatomic, copy, nullable) NSString *editingTodoID;
@property(nonatomic, copy, nullable) NSString *editingOriginalTitle;
@property(nonatomic) CGFloat todoScrollOffset;
@property(nonatomic) BOOL todoMutationInProgress;
@property(nonatomic) BOOL todoEditInProgress;
@property(nonatomic, copy, nullable) NSString *statusMessage;
@property(nonatomic) BOOL weekViewEnabled;
@property(nonatomic) CGFloat calendarHorizontalGestureDistance;
@property(nonatomic) CGFloat calendarVerticalGestureDistance;
@property(nonatomic) BOOL calendarGestureConsumed;
@property(nonatomic) MCCalendarGestureAxis calendarGestureAxis;
@property(nonatomic) CGFloat calendarExpansion;
@property(nonatomic) CGFloat calendarAnimationStartExpansion;
@property(nonatomic) CGFloat calendarAnimationTargetExpansion;
@property(nonatomic) CGFloat calendarAnimationLinearProgress;
@property(nonatomic) CFTimeInterval calendarAnimationStartTime;
@property(nonatomic, strong, nullable) CADisplayLink *calendarDisplayLink;
@property(nonatomic, strong, nullable) NSTrackingArea *yearProgressTrackingArea;
@property(nonatomic) BOOL yearProgressHovered;
@property(nonatomic) CGFloat yearProgressReveal;
@property(nonatomic) CGFloat yearProgressAnimationStartReveal;
@property(nonatomic) CGFloat yearProgressAnimationTargetReveal;
@property(nonatomic) CFTimeInterval yearProgressAnimationStartTime;
@property(nonatomic, strong, nullable) CADisplayLink *yearProgressDisplayLink;
@property(nonatomic, strong, nullable) MCSettingsWindowController *settingsController;
@property(nonatomic, copy) NSArray<NSDate *> *transitionMonthDates;
@property(nonatomic, copy) NSArray<NSDate *> *transitionWeekDates;
@property(nonatomic) NSInteger transitionMonthRowCount;
@property(nonatomic) NSInteger transitionSelectedMonthRow;

- (void)beginEditingTodo:(NSDictionary *)item;
- (void)commitTodoEditing:(id)sender;
- (void)cancelTodoEditing;
- (void)updateTodoEditorFrame;
- (void)accentColorDidChange:(NSNotification *)notification;
- (void)showSettings:(id)sender;
- (void)drawFigmaIconNamed:(NSString *)name
                    inRect:(NSRect)rect
                      tint:(NSColor *)tint;
- (void)refreshDeleteToolTips;

@end

@implementation MCCalendarView

- (instancetype)initWithFrame:(NSRect)frameRect defaults:(NSUserDefaults *)defaults {
    return [self initWithFrame:frameRect defaults:defaults systemIntegrationEnabled:YES];
}

- (instancetype)initWithFrame:(NSRect)frameRect
                      defaults:(NSUserDefaults *)defaults
      systemIntegrationEnabled:(BOOL)systemIntegrationEnabled {
    self = [super initWithFrame:frameRect];
    if (self) {
        _calendar = MCCalendar();
        _holidays = [[MCHolidayService alloc] init];
        _lunar = [[MCLunarService alloc] init];
        _systemIntegrationEnabled = systemIntegrationEnabled;
        if (systemIntegrationEnabled) {
            _systemStore = [[MCSystemDataStore alloc] initWithDefaults:defaults];
            __weak typeof(self) weakSelf = self;
            _systemStore.changeHandler = ^{
                [weakSelf refreshSystemData];
            };
        } else {
            _previewTodoStore = [[MCTodoStore alloc] initWithDefaults:defaults];
        }
        _today = [_calendar startOfDayForDate:[NSDate date]];
        _selectedDate = _today;
        _displayedMonth = [self startOfMonth:_today];
        _todoScrollOffset = 0;
        _weekViewEnabled = NO;
        _calendarHorizontalGestureDistance = 0;
        _calendarVerticalGestureDistance = 0;
        _calendarGestureConsumed = NO;
        _calendarGestureAxis = MCCalendarGestureAxisUndetermined;
        _calendarExpansion = 1.0;
        _yearProgressReveal = 0.0;
        _transitionMonthDates = @[];
        _transitionWeekDates = @[];
        _visibleTodos = @[];
        _visibleEvents = @[];
        _agendaRows = @[];

        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(accentColorDidChange:)
                                                   name:MCAccentColorDidChangeNotification
                                                 object:nil];

        _todoField = [[MCFocusableTextField alloc] initWithFrame:
            NSMakeRect(MCInputTextLeading,
                       0,
                       MCContentRight - MCInputTextLeading,
                       MCTodoInputHeight)];
        MCVerticallyCenteredTextFieldCell *todoFieldCell =
            [[MCVerticallyCenteredTextFieldCell alloc] initTextCell:@""];
        todoFieldCell.opticalVerticalOffset = 1.0;
        _todoField.cell = todoFieldCell;
        _todoField.editable = YES;
        _todoField.selectable = YES;
        _todoField.placeholderString = @"添加 todo，回车保存";
        _todoField.font = MCLatinFont(13, NSFontWeightMedium);
        _todoField.bezeled = NO;
        _todoField.bordered = NO;
        _todoField.drawsBackground = NO;
        _todoField.backgroundColor = NSColor.clearColor;
        _todoField.focusRingType = NSFocusRingTypeNone;
        _todoField.target = self;
        _todoField.action = @selector(addTodo:);
        _todoField.delegate = self;
        [self addSubview:_todoField];

        _editTodoField = [[MCFocusableTextField alloc]
            initWithFrame:NSMakeRect(MCAgendaTextLeading, 0, 281, 32)];
        _editTodoField.cell = [[MCVerticallyCenteredTextFieldCell alloc] initTextCell:@""];
        _editTodoField.editable = YES;
        _editTodoField.selectable = YES;
        _editTodoField.font = MCLatinFont(14, NSFontWeightMedium);
        _editTodoField.bezeled = NO;
        _editTodoField.bordered = NO;
        _editTodoField.drawsBackground = NO;
        _editTodoField.backgroundColor = NSColor.clearColor;
        _editTodoField.focusRingType = NSFocusRingTypeNone;
        _editTodoField.target = self;
        _editTodoField.action = @selector(commitTodoEditing:);
        _editTodoField.delegate = self;
        _editTodoField.hidden = YES;
        [self addSubview:_editTodoField];

        [self rebuildGrid];
        [self reloadAgenda];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self.calendarDisplayLink invalidate];
    [self.yearProgressDisplayLink invalidate];
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)isOpaque {
    return NO;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self setNeedsDisplay:YES];
}

- (void)accentColorDidChange:(NSNotification *)notification {
    (void)notification;
    [self setNeedsDisplay:YES];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.yearProgressTrackingArea) {
        [self removeTrackingArea:self.yearProgressTrackingArea];
    }
    self.yearProgressTrackingArea = [[NSTrackingArea alloc]
        initWithRect:MCYearProgressHoverRect()
             options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp
               owner:self
            userInfo:nil];
    [self addTrackingArea:self.yearProgressTrackingArea];
    [self refreshDeleteToolTips];
}

- (void)refreshDeleteToolTips {
    [self removeAllToolTips];
    CGFloat agendaTop = [self agendaTop];
    CGFloat agendaClipTop = [self agendaClipTop];
    for (NSUInteger index = 0; index < self.agendaRows.count; index++) {
        NSDictionary *item = self.agendaRows[index];
        if ([item[@"kind"] isEqualToString:@"event"]) {
            continue;
        }
        CGFloat rowY = agendaTop + index * MCAgendaRowHeight - self.todoScrollOffset;
        if (rowY + MCAgendaRowHeight <= agendaClipTop || rowY >= MCFooterTop) {
            continue;
        }
        [self addToolTipRect:NSMakeRect(336, rowY + 8, 24, 32)
                      owner:self
                   userData:NULL];
    }
}

- (NSString *)view:(NSView *)view
   stringForToolTip:(NSToolTipTag)tag
              point:(NSPoint)point
           userData:(void *)data {
    (void)view;
    (void)tag;
    (void)point;
    (void)data;
    return @"删除";
}

- (void)mouseEntered:(NSEvent *)event {
    if (event.trackingArea != self.yearProgressTrackingArea) {
        [super mouseEntered:event];
        return;
    }
    self.yearProgressHovered = YES;
    [self animateYearProgressRevealTo:1.0];
}

- (void)mouseExited:(NSEvent *)event {
    if (event.trackingArea != self.yearProgressTrackingArea) {
        [super mouseExited:event];
        return;
    }
    self.yearProgressHovered = NO;
    [self animateYearProgressRevealTo:0.0];
}

- (void)animateYearProgressRevealTo:(CGFloat)targetReveal {
    targetReveal = MIN(1.0, MAX(0.0, targetReveal));
    [self.yearProgressDisplayLink invalidate];
    self.yearProgressDisplayLink = nil;
    [self setNeedsDisplayInRect:MCYearProgressDisplayRect()];

    if (!self.window || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        self.yearProgressReveal = targetReveal;
        [self setNeedsDisplayInRect:MCYearProgressDisplayRect()];
        return;
    }

    self.yearProgressAnimationStartReveal = self.yearProgressReveal;
    self.yearProgressAnimationTargetReveal = targetReveal;
    self.yearProgressAnimationStartTime = CACurrentMediaTime();
    self.yearProgressDisplayLink = [self displayLinkWithTarget:self
                                                     selector:@selector(yearProgressAnimationTick:)];
    [self.yearProgressDisplayLink addToRunLoop:NSRunLoop.mainRunLoop
                                       forMode:NSRunLoopCommonModes];
}

- (void)yearProgressAnimationTick:(CADisplayLink *)displayLink {
    CGFloat linearProgress = (CACurrentMediaTime() - self.yearProgressAnimationStartTime)
        / MCYearProgressRevealDuration;
    linearProgress = MIN(1.0, MAX(0.0, linearProgress));
    CGFloat easedProgress = MCEaseOutProgress(linearProgress);
    self.yearProgressReveal = self.yearProgressAnimationStartReveal
        + (self.yearProgressAnimationTargetReveal - self.yearProgressAnimationStartReveal)
        * easedProgress;
    [self setNeedsDisplayInRect:MCYearProgressDisplayRect()];

    if (linearProgress >= 1.0) {
        self.yearProgressReveal = self.yearProgressAnimationTargetReveal;
        [displayLink invalidate];
        self.yearProgressDisplayLink = nil;
        [self setNeedsDisplayInRect:MCYearProgressDisplayRect()];
    }
}

- (void)startSystemSync {
    if (!self.systemIntegrationEnabled) {
        return;
    }
    [self updateTodoFieldState];
    __weak typeof(self) weakSelf = self;
    [self.systemStore requestAccessWithCompletion:^{
        [weakSelf updateTodoFieldState];
        [weakSelf refreshSystemData];
    }];
}

- (void)refreshSystemData {
    if (!self.systemIntegrationEnabled) {
        return;
    }
    [self updateTodoFieldState];
    [self reloadAgenda];
}

- (void)refreshToday {
    NSDate *newToday = [self.calendar startOfDayForDate:[NSDate date]];
    if (![self.calendar isDate:newToday inSameDayAsDate:self.today]) {
        self.today = newToday;
        [self reloadAgenda];
        [self setNeedsDisplay:YES];
    }
}

- (void)showWeekView {
    if (self.weekViewEnabled) {
        return;
    }
    if (![self isDate:self.selectedDate inMonth:self.displayedMonth]) {
        self.selectedDate = self.displayedMonth;
        self.todoScrollOffset = 0;
        [self reloadAgenda];
    }
    self.weekViewEnabled = YES;
    self.displayedMonth = [self startOfMonth:self.selectedDate];
    [self rebuildGrid];
    [self animateCalendarExpansionTo:0.0];
}

- (void)showMonthView {
    if (!self.weekViewEnabled) {
        return;
    }
    self.weekViewEnabled = NO;
    self.displayedMonth = [self startOfMonth:self.selectedDate];
    [self rebuildGrid];
    [self animateCalendarExpansionTo:1.0];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    [self drawHeader];
    [self drawWeekdays];
    [self drawCalendarGrid];
    [self drawTodoSection];
    [self drawFooter];
}

- (void)drawHeader {
    NSDate *headerDate = self.weekViewEnabled ? self.selectedDate : self.displayedMonth;
    NSDateComponents *parts = [self.calendar components:NSCalendarUnitYear | NSCalendarUnitMonth
        fromDate:headerDate
    ];
    NSArray *monthNames = @[@"一月", @"二月", @"三月", @"四月", @"五月", @"六月",
                            @"七月", @"八月", @"九月", @"十月", @"十一月", @"十二月"];
    NSString *month = monthNames[parts.month - 1];
    NSDictionary *monthAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:27 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: MCPrimaryTextColor(self),
    };
    [month drawAtPoint:NSMakePoint(MCContentLeading, MCHeaderTop)
        withAttributes:monthAttributes];

    CGFloat monthWidth = [month sizeWithAttributes:monthAttributes].width;
    [self drawText:[NSString stringWithFormat:@"%ld", (long)parts.year]
            inRect:NSMakeRect(MCContentLeading + 8 + monthWidth,
                              MCHeaderTop + MCHeaderYearOpticalOffsetY,
                              88,
                              34)
              font:MCLatinFont(25, NSFontWeightRegular)
             color:MCAccentColor()
         alignment:NSTextAlignmentLeft
    ];

    CGFloat iconY = MCHeaderTop + 8;
    [self drawFigmaIconNamed:@"chevron-left"
                      inRect:NSMakeRect(MCHeaderControlX + MCHeaderIconInset,
                                        iconY,
                                        MCHeaderIconSize,
                                        MCHeaderIconSize)
                        tint:MCSecondaryTextColor(self)];
    BOOL showsTodayButton = ![self.calendar isDate:self.selectedDate
                                           inSameDayAsDate:self.today];
    if (showsTodayButton) {
        [self drawFigmaIconNamed:@"today"
                          inRect:NSMakeRect(MCHeaderControlX + MCHeaderControlWidth
                                            + MCHeaderIconInset,
                                            iconY,
                                            MCHeaderIconSize,
                                            MCHeaderIconSize)
                            tint:MCAccentColor()];
    }
    [self drawFigmaIconNamed:@"chevron-right"
                      inRect:NSMakeRect(MCHeaderControlX + MCHeaderControlWidth * 2
                                        + MCHeaderIconInset,
                                        iconY,
                                        MCHeaderIconSize,
                                        MCHeaderIconSize)
                        tint:MCSecondaryTextColor(self)];
}

- (void)drawWeekdays {
    NSArray *weekdays = @[@"一", @"二", @"三", @"四", @"五", @"六", @"日"];
    CGFloat width = MCGridWidth / 7;
    for (NSUInteger index = 0; index < weekdays.count; index++) {
        [self drawText:weekdays[index]
                inRect:NSMakeRect(MCGridX + index * width, MCWeekdaysY, width, 15)
                  font:[NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium]
                 color:MCTertiaryTextColor(self)
             alignment:NSTextAlignmentCenter
        ];
    }
}

- (void)drawCalendarGrid {
    if (self.calendarDisplayLink) {
        [self drawTransitionCalendarGrid];
        return;
    }
    [self drawCalendarGridDates:self.gridDates
                       weekMode:self.weekViewEnabled
                      anchorRow:0
                        anchorY:MCGridY
                     rowSpacing:MCCellHeight
                          alpha:1.0
                      rowFilter:MCCalendarRowFilterAll];
}

- (void)drawTransitionCalendarGrid {
    CGFloat expansion = self.calendarExpansion;
    CGFloat selectedRowY = MCGridY
        + expansion * self.transitionSelectedMonthRow * MCCellHeight;
    CGFloat monthRowSpacing = expansion * MCCellHeight;
    BOOL expanding = self.calendarAnimationTargetExpansion
        > self.calendarAnimationStartExpansion;
    CGFloat otherRowsAlpha;
    if (expanding) {
        CGFloat delay = MCCalendarRowStagger / MCCalendarTransitionDuration;
        CGFloat delayedProgress = (self.calendarAnimationLinearProgress - delay) / (1.0 - delay);
        delayedProgress = MIN(1.0, MAX(0.0, delayedProgress));
        otherRowsAlpha = MCEaseOutProgress(delayedProgress);
    } else {
        otherRowsAlpha = 1.0 - MCEaseOutProgress(self.calendarAnimationLinearProgress);
    }

    [NSGraphicsContext saveGraphicsState];
    CGFloat clipTop = MCGridY
        + MCDateHighlightTopOffset
        - MCDateHighlightStrokeOverflow;
    NSRectClip(NSMakeRect(0,
                          clipTop,
                          MCViewWidth,
                          MAX(0, [self todoTop] - clipTop)));

    [self drawCalendarGridDates:self.transitionMonthDates
                       weekMode:NO
                      anchorRow:self.transitionSelectedMonthRow
                        anchorY:MCGridY + self.transitionSelectedMonthRow * MCCellHeight
                     rowSpacing:MCCellHeight
                          alpha:otherRowsAlpha
                      rowFilter:MCCalendarRowFilterOthers];
    [self drawCalendarGridDates:self.transitionMonthDates
                       weekMode:NO
                      anchorRow:self.transitionSelectedMonthRow
                        anchorY:selectedRowY
                     rowSpacing:monthRowSpacing
                          alpha:expansion
                      rowFilter:MCCalendarRowFilterSelected];
    [self drawCalendarGridDates:self.transitionWeekDates
                       weekMode:YES
                      anchorRow:0
                        anchorY:selectedRowY
                     rowSpacing:MCCellHeight
                          alpha:1.0 - expansion
                      rowFilter:MCCalendarRowFilterAll];

    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawCalendarGridDates:(NSArray<NSDate *> *)dates
                     weekMode:(BOOL)weekMode
                    anchorRow:(NSInteger)anchorRow
                      anchorY:(CGFloat)anchorY
                   rowSpacing:(CGFloat)rowSpacing
                        alpha:(CGFloat)alpha
                    rowFilter:(MCCalendarRowFilter)rowFilter {
    if (alpha <= 0.001) {
        return;
    }

    [NSGraphicsContext saveGraphicsState];
    CGContextSetAlpha(NSGraphicsContext.currentContext.CGContext, alpha);
    CGFloat width = MCGridWidth / 7;
    NSDateComponents *displayed = [self.calendar components:NSCalendarUnitYear | NSCalendarUnitMonth
        fromDate:self.displayedMonth
    ];

    for (NSUInteger index = 0; index < dates.count; index++) {
        NSDate *date = dates[index];
        NSDateComponents *parts = [self.calendar components:
            NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date
        ];
        NSInteger column = index % 7;
        NSInteger row = index / 7;
        BOOL selectedRow = row == anchorRow;
        if ((rowFilter == MCCalendarRowFilterSelected && !selectedRow)
            || (rowFilter == MCCalendarRowFilterOthers && selectedRow)) {
            continue;
        }
        CGFloat rowY = anchorY + (row - anchorRow) * rowSpacing;
        NSRect cell = NSMakeRect(MCGridX + column * width, rowY, width, MCCellHeight);
        BOOL inMonth = weekMode
            || (parts.year == displayed.year && parts.month == displayed.month);
        BOOL selected = [self.calendar isDate:date inSameDayAsDate:self.selectedDate];
        BOOL today = [self.calendar isDate:date inSameDayAsDate:self.today];
        MCHoliday *holiday = [self.holidays holidayForDate:date];

        NSRect selectionRect = NSMakeRect(NSMidX(cell) - 14,
                                          cell.origin.y + MCDateHighlightTopOffset,
                                          28,
                                          26);
        if (selected) {
            [MCAccentColor() setFill];
            [[NSBezierPath bezierPathWithRoundedRect:selectionRect
                                             xRadius:8
                                             yRadius:8] fill];
        } else if (today) {
            [MCAccentColor() setStroke];
            NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:selectionRect
                                                                    xRadius:8
                                                                    yRadius:8];
            outline.lineWidth = 1.0;
            [outline stroke];
        }

        NSColor *dayColor = selected ? MCAccentForegroundColor()
            : (inMonth ? MCPrimaryTextColor(self) : MCTertiaryTextColor(self));
        NSString *dayText = [NSString stringWithFormat:@"%ld", (long)parts.day];
        NSFont *dayFont = MCLatinFont(16, NSFontWeightMedium);
        [self drawText:dayText
                inRect:NSMakeRect(cell.origin.x, cell.origin.y, width, 21)
                  font:dayFont
                 color:dayColor
             alignment:NSTextAlignmentCenter];

        NSString *secondary = holiday ? holiday.label : [self.lunar shortTextForDate:date];
        NSColor *secondaryColor = MCSecondaryTextColor(self);
        if (!inMonth) {
            secondaryColor = MCTertiaryTextColor(self);
        } else if (holiday && (holiday.kind == MCHolidayKindFestival || holiday.kind == MCHolidayKindDayOff)) {
            secondaryColor = MCAccentColor();
        } else if (holiday && holiday.kind == MCHolidayKindMakeUpWork) {
            secondaryColor = [NSColor colorWithSRGBRed:0.18 green:0.52 blue:0.92 alpha:1];
        }
        [self drawText:secondary
                inRect:NSMakeRect(cell.origin.x + 2, cell.origin.y + 24, width - 4, 12.5)
                  font:[NSFont systemFontOfSize:9.5 weight:holiday ? NSFontWeightMedium : NSFontWeightRegular]
                 color:secondaryColor
             alignment:NSTextAlignmentCenter
        ];
    }
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawTodoSection {
    CGFloat todoTop = [self todoTop];
    CGFloat agendaTop = [self agendaTop];
    [MCSeparatorColor(self) setFill];
    NSRectFill(NSMakeRect(0, todoTop, MCViewWidth, 0.5));

    NSDateComponents *parts = [self.calendar components:
        NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitWeekday
        fromDate:self.selectedDate
    ];
    NSArray *weekdays = @[@"周日", @"周一", @"周二", @"周三", @"周四", @"周五", @"周六"];
    NSString *dateText = [NSString stringWithFormat:@"%ld月%ld日",
        (long)parts.month, (long)parts.day];
    NSString *weekdayText = weekdays[parts.weekday - 1];
    NSFont *dateFont = MCLatinFont(18, NSFontWeightMedium);
    CGFloat dateWidth = ceil([dateText sizeWithAttributes:@{NSFontAttributeName: dateFont}].width);
    [self drawText:dateText
            inRect:NSMakeRect(MCContentLeading, todoTop + 15, dateWidth, 24)
              font:dateFont
             color:MCPrimaryTextColor(self)
         alignment:NSTextAlignmentLeft];
    CGFloat dotX = MCContentLeading + dateWidth + 6;
    [self drawFigmaIconNamed:@"date-separator"
                      inRect:NSMakeRect(dotX, todoTop + 26, 2, 2)
                        tint:MCPrimaryTextColor(self)];
    [self drawText:weekdayText
            inRect:NSMakeRect(dotX + 8, todoTop + 15, 48, 24)
              font:dateFont
             color:MCPrimaryTextColor(self)
         alignment:NSTextAlignmentLeft];
    [self drawText:[self.lunar longTextForDate:self.selectedDate]
            inRect:NSMakeRect(MCContentLeading, todoTop + 42, 181, 15)
              font:[NSFont systemFontOfSize:11 weight:NSFontWeightMedium]
             color:MCSecondaryTextColor(self) alignment:NSTextAlignmentLeft];

    NSInteger incomplete = 0;
    for (NSDictionary *item in self.visibleTodos) {
        incomplete += ![item[@"done"] boolValue];
    }
    NSMutableArray<NSString *> *counts = [[NSMutableArray alloc] init];
    if (self.visibleEvents.count > 0) {
        [counts addObject:[NSString stringWithFormat:@"%ld 日程", (long)self.visibleEvents.count]];
    }
    if (incomplete > 0) {
        [counts addObject:[NSString stringWithFormat:@"%ld 待办", (long)incomplete]];
    }
    if (counts.count > 0) {
        [self drawText:[counts componentsJoinedByString:@" · "]
                inRect:NSMakeRect(250, todoTop + 20, MCContentRight - 250, 15)
                  font:MCLatinFont(11, NSFontWeightMedium)
             color:MCAccentColor() alignment:NSTextAlignmentRight];
    } else if (self.systemIntegrationEnabled
               && self.systemStore.calendarAccessState == MCSystemAccessStateDenied) {
        [self drawText:@"日历未授权"
                inRect:NSMakeRect(290, todoTop + 20, MCContentRight - 290, 15)
                  font:[NSFont systemFontOfSize:10 weight:NSFontWeightRegular]
                 color:NSColor.tertiaryLabelColor alignment:NSTextAlignmentRight];
    }

    NSBezierPath *inputBackground = [NSBezierPath bezierPathWithRoundedRect:
        NSMakeRect(27,
                   todoTop + MCTodoInputOffset,
                   335,
                   MCTodoInputHeight)
        xRadius:8 yRadius:8];
    [MCGlassControlFillColor(self) setFill];
    [inputBackground fill];
    NSText *todoEditor = self.todoField.currentEditor;
    BOOL inputFocused = todoEditor != nil && self.window.firstResponder == todoEditor;
    if (inputFocused) {
        [MCGlassControlFocusedBorderColor(self) setStroke];
        inputBackground.lineWidth = 1.0;
        [inputBackground stroke];
    }
    [self drawFigmaIconNamed:@"add"
                      inRect:NSMakeRect(MCContentLeading,
                                        todoTop + MCTodoInputOffset
                                            + (MCTodoInputHeight - MCAgendaMarkerBoxSize) / 2.0,
                                        MCAgendaMarkerBoxSize,
                                        MCAgendaMarkerBoxSize)
                        tint:MCAccentColor()];

    [NSGraphicsContext saveGraphicsState];
    CGFloat inputBottom = [self agendaClipTop];
    NSRectClip(NSMakeRect(0,
                          inputBottom,
                          MCViewWidth,
                          MCFooterTop - inputBottom));
    if (self.agendaRows.count == 0) {
        NSString *emptyTitle = self.statusMessage ?: @"这一天没有日程或待办";
        NSString *emptyIcon = self.statusMessage ? @"!" : @"✓";
        CGFloat emptyTop = agendaTop + MAX(20, (MCFooterTop - agendaTop - 58) / 2);
        [self drawText:emptyIcon inRect:NSMakeRect(0, emptyTop, MCViewWidth, 26)
                  font:[NSFont systemFontOfSize:22 weight:NSFontWeightLight]
                 color:NSColor.tertiaryLabelColor alignment:NSTextAlignmentCenter];
        [self drawText:emptyTitle inRect:NSMakeRect(20, emptyTop + 29, MCViewWidth - 40, 34)
                  font:MCLatinFont(12, NSFontWeightRegular)
                 color:NSColor.secondaryLabelColor alignment:NSTextAlignmentCenter];
    } else {
        [self drawAgendaRows];
    }
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawAgendaRows {
    CGFloat agendaTop = [self agendaTop];
    for (NSUInteger index = 0; index < self.agendaRows.count; index++) {
        NSDictionary *item = self.agendaRows[index];
        CGFloat y = agendaTop + index * MCAgendaRowHeight - self.todoScrollOffset;
        if ([item[@"kind"] isEqualToString:@"event"]) {
            [self drawEventRow:item atY:y rowHeight:MCAgendaRowHeight];
            continue;
        }
        [self drawTodoRow:item atY:y rowHeight:MCAgendaRowHeight];
    }
    CGFloat finalDividerY = agendaTop
        + self.agendaRows.count * MCAgendaRowHeight
        - self.todoScrollOffset;
    [self drawFigmaIconNamed:@"dashed-divider"
                      inRect:NSMakeRect(MCContentLeading,
                                        finalDividerY - MCAgendaDividerHeight / 2.0,
                                        MCContentRight - MCContentLeading,
                                        MCAgendaDividerHeight)
                        tint:MCAgendaDividerColor(self)];
}

- (void)drawEventRow:(NSDictionary *)item atY:(CGFloat)y rowHeight:(CGFloat)rowHeight {
    [self drawFigmaIconNamed:@"dashed-divider"
                      inRect:NSMakeRect(MCContentLeading,
                                        y - MCAgendaDividerHeight / 2.0,
                                        MCContentRight - MCContentLeading,
                                        MCAgendaDividerHeight)
                        tint:MCAgendaDividerColor(self)];
    NSColor *color = item[@"color"] ?: NSColor.systemBlueColor;
    [color setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(
        MCAgendaMarkerLeading + (MCAgendaMarkerBoxSize - MCEventDotSize) / 2.0,
        y + (rowHeight - MCEventDotSize) / 2.0,
        MCEventDotSize,
        MCEventDotSize
    )] fill];

    [self drawVerticallyCenteredText:item[@"title"] ?: @"无标题日程"
                                inRect:NSMakeRect(MCAgendaTextLeading, y, 235, rowHeight)
                                  font:MCLatinFont(14, NSFontWeightMedium)
                                 color:MCPrimaryTextColor(self)
                             alignment:NSTextAlignmentLeft];
    [self drawVerticallyCenteredText:item[@"time"] ?: @""
                                inRect:NSMakeRect(296, y, MCContentRight - 296, rowHeight)
                                  font:MCLatinFont(11, NSFontWeightRegular)
                                 color:MCSecondaryTextColor(self)
                             alignment:NSTextAlignmentRight];
}

- (void)drawTodoRow:(NSDictionary *)item atY:(CGFloat)y rowHeight:(CGFloat)rowHeight {
    BOOL done = [item[@"done"] boolValue];
    [self drawFigmaIconNamed:@"dashed-divider"
                      inRect:NSMakeRect(MCContentLeading,
                                        y - MCAgendaDividerHeight / 2.0,
                                        MCContentRight - MCContentLeading,
                                        MCAgendaDividerHeight)
                        tint:MCAgendaDividerColor(self)];
    [self drawFigmaIconNamed:(done ? @"todo-complete" : @"todo-incomplete")
                      inRect:NSMakeRect(MCAgendaMarkerLeading,
                                        y + (rowHeight - MCAgendaMarkerBoxSize) / 2.0,
                                        MCAgendaMarkerBoxSize,
                                        MCAgendaMarkerBoxSize)
                        tint:(done ? MCAccentColor() : MCTertiaryTextColor(self))];

    NSString *time = item[@"time"] ?: @"";
    BOOL overdue = [item[@"overdue"] boolValue] && !done;
    CGFloat titleWidth = time.length > 0 ? 225 : 275;
    BOOL editing = [self.editingTodoID isEqualToString:item[@"id"]];
    if (editing) {
        NSBezierPath *editingBackground = [NSBezierPath bezierPathWithRoundedRect:
            NSMakeRect(MCAgendaTextLeading - 4, y + 8, titleWidth + 8, 32)
            xRadius:8
            yRadius:8];
        [MCGlassControlFillColor(self) setFill];
        [editingBackground fill];
        NSText *editEditor = self.editTodoField.currentEditor;
        BOOL editFocused = editEditor != nil && self.window.firstResponder == editEditor;
        if (editFocused) {
            [MCGlassControlFocusedBorderColor(self) setStroke];
            editingBackground.lineWidth = 1.0;
            [editingBackground stroke];
        }
    } else {
        NSColor *titleColor = done ? MCTertiaryTextColor(self) : MCPrimaryTextColor(self);
        NSMutableAttributedString *title = [[NSMutableAttributedString alloc]
            initWithString:item[@"title"]
            attributes:@{
                NSFontAttributeName: MCLatinFont(14, NSFontWeightMedium),
                NSForegroundColorAttributeName: titleColor,
            }
        ];
        if (done) {
            [title addAttribute:NSStrikethroughStyleAttributeName
                         value:@(NSUnderlineStyleSingle)
                         range:NSMakeRange(0, title.length)];
        }
        [title drawInRect:NSMakeRect(MCAgendaTextLeading,
                                     y + (overdue ? 8 : 14),
                                     titleWidth,
                                     overdue ? 18 : 20)];
        if (overdue) {
            [self drawText:@"已过期"
                    inRect:NSMakeRect(MCAgendaTextLeading, y + 27, titleWidth, 12)
                      font:[NSFont systemFontOfSize:9 weight:NSFontWeightMedium]
                     color:MCAccentColor()
                 alignment:NSTextAlignmentLeft];
        }
    }

    if (time.length > 0) {
        [self drawText:time inRect:NSMakeRect(285, y + 15, 51, 18)
                  font:MCLatinFont(11, NSFontWeightRegular)
                 color:MCSecondaryTextColor(self) alignment:NSTextAlignmentRight];
    }

    [self drawFigmaIconNamed:@"delete"
                      inRect:NSMakeRect(340, y + 16, 16, 16)
                        tint:MCTertiaryTextColor(self)];
}

- (void)drawFooter {
    [MCSeparatorColor(self) setFill];
    NSRectFill(NSMakeRect(0, MCFooterTop, MCViewWidth, 0.5));
    if (self.yearProgressReveal > 0.0) {
        CGFloat yearProgress = MCYearProgressForDate(self.calendar, [NSDate date]);
        CGFloat progressEndX = MCViewWidth * yearProgress * self.yearProgressReveal;
        [MCAccentColor() setFill];
        NSRectFill(NSMakeRect(0,
                              MCFooterTop,
                              progressEndX,
                              MCFooterProgressHeight));
        if ([self shouldDrawYearProgressTooltip]) {
            [self drawYearProgressTooltipAtX:progressEndX
                                yearProgress:yearProgress];
        }
    }
    CGFloat footerHeight = MCViewHeight - MCFooterTop;
    NSString *holidayText = [self nextHolidayText];
    NSMutableParagraphStyle *holidayStyle = [[NSMutableParagraphStyle alloc] init];
    holidayStyle.alignment = NSTextAlignmentLeft;
    holidayStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    NSMutableAttributedString *attributedHoliday = [[NSMutableAttributedString alloc]
        initWithString:holidayText
            attributes:@{
                NSFontAttributeName: MCLatinFont(11, NSFontWeightMedium),
                NSForegroundColorAttributeName: MCSecondaryTextColor(self),
                NSParagraphStyleAttributeName: holidayStyle,
            }];
    [self drawVerticallyCenteredAttributedText:attributedHoliday
                                        inRect:NSMakeRect(MCContentLeading,
                                                          MCFooterTop,
                                                          290,
                                                          footerHeight)];
    [self drawFigmaIconNamed:@"more"
                      inRect:NSMakeRect(340,
                                        MCFooterTop + (footerHeight - 16) / 2.0,
                                        16,
                                        16)
                        tint:MCTertiaryTextColor(self)];
}

- (BOOL)shouldDrawYearProgressTooltip {
    return self.yearProgressHovered
        && self.yearProgressDisplayLink == nil
        && self.yearProgressReveal >= 1.0;
}

- (void)drawYearProgressTooltipAtX:(CGFloat)anchorX
                       yearProgress:(CGFloat)yearProgress {
    NSString *text = [NSString localizedStringWithFormat:@"今年进度 %.1f%%",
                                                       yearProgress * 100];
    NSFont *font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    NSDictionary *textAttributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [NSColor colorWithWhite:1.0 alpha:0.96],
    };
    CGFloat horizontalPadding = 10;
    CGFloat bubbleWidth = ceil([text sizeWithAttributes:textAttributes].width)
        + horizontalPadding * 2;
    CGFloat outerMargin = 8;
    CGFloat bubbleX = MIN(MCViewWidth - outerMargin - bubbleWidth,
                          MAX(outerMargin, anchorX - bubbleWidth / 2));
    CGFloat bubbleY = MCFooterTop - MCYearProgressTooltipArrowHeight
        - MCYearProgressTooltipHeight;
    NSRect bubbleRect = NSMakeRect(bubbleX,
                                   bubbleY,
                                   bubbleWidth,
                                   MCYearProgressTooltipHeight);
    CGFloat cornerRadius = 7;
    CGFloat arrowHalfWidth = 5;
    CGFloat arrowCenterX = MIN(NSMaxX(bubbleRect) - cornerRadius - arrowHalfWidth,
                               MAX(NSMinX(bubbleRect) + cornerRadius + arrowHalfWidth,
                                   anchorX));
    NSColor *tooltipColor = [NSColor colorWithWhite:0.0 alpha:0.78];

    [NSGraphicsContext saveGraphicsState];
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [NSColor colorWithWhite:0.0 alpha:0.18];
    shadow.shadowBlurRadius = 8;
    shadow.shadowOffset = NSMakeSize(0, 2);
    [shadow set];
    [tooltipColor setFill];
    [[NSBezierPath bezierPathWithRoundedRect:bubbleRect
                                     xRadius:cornerRadius
                                     yRadius:cornerRadius] fill];

    NSBezierPath *arrow = [NSBezierPath bezierPath];
    [arrow moveToPoint:NSMakePoint(arrowCenterX - arrowHalfWidth,
                                   NSMaxY(bubbleRect) - 0.5)];
    [arrow lineToPoint:NSMakePoint(anchorX, MCFooterTop)];
    [arrow lineToPoint:NSMakePoint(arrowCenterX + arrowHalfWidth,
                                   NSMaxY(bubbleRect) - 0.5)];
    [arrow closePath];
    [arrow fill];
    [NSGraphicsContext restoreGraphicsState];

    [self drawVerticallyCenteredText:text
                              inRect:bubbleRect
                                font:font
                               color:[NSColor colorWithWhite:1.0 alpha:0.96]
                           alignment:NSTextAlignmentCenter];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (self.todoEditInProgress) {
        NSBeep();
        return;
    }
    if (self.editingTodoID) {
        [self cancelTodoEditing];
    }

    if (NSPointInRect(point, NSMakeRect(MCHeaderControlX, 37,
                                       MCHeaderControlWidth, 42))) {
        [self moveDisplayedPeriodBy:-1];
        return;
    }
    BOOL showsTodayButton = ![self.calendar isDate:self.selectedDate
                                           inSameDayAsDate:self.today];
    if (showsTodayButton
        && NSPointInRect(point, NSMakeRect(MCHeaderControlX + MCHeaderControlWidth,
                                          37,
                                          MCHeaderControlWidth,
                                          42))) {
        self.today = [self.calendar startOfDayForDate:[NSDate date]];
        self.selectedDate = self.today;
        self.displayedMonth = [self startOfMonth:self.today];
        [self rebuildGrid];
        [self reloadAgenda];
        return;
    }
    if (NSPointInRect(point, NSMakeRect(MCHeaderControlX + MCHeaderControlWidth * 2,
                                       37,
                                       MCHeaderControlWidth,
                                       42))) {
        [self moveDisplayedPeriodBy:1];
        return;
    }
    if (point.y >= MCGridY && point.y < MCGridY + [self calendarRowCount] * MCCellHeight) {
        CGFloat width = MCGridWidth / 7;
        NSInteger column = floor((point.x - MCGridX) / width);
        NSInteger row = floor((point.y - MCGridY) / MCCellHeight);
        NSInteger index = row * 7 + column;
        if (column >= 0 && column < 7 && index >= 0 && index < (NSInteger)self.gridDates.count) {
            self.selectedDate = self.gridDates[index];
            self.displayedMonth = [self startOfMonth:self.selectedDate];
            self.todoScrollOffset = 0;
            [self rebuildGrid];
            [self reloadAgenda];
        }
        return;
    }
    CGFloat agendaTop = [self agendaTop];
    if (point.y >= [self agendaClipTop]
        && point.y < MCFooterTop
        && self.agendaRows.count > 0) {
        NSInteger index = floor((point.y - agendaTop + self.todoScrollOffset)
            / MCAgendaRowHeight);
        if (index >= 0 && index < (NSInteger)self.agendaRows.count) {
            NSDictionary *item = self.agendaRows[index];
            if ([item[@"kind"] isEqualToString:@"event"]) {
                return;
            }
            CGFloat rowY = agendaTop + index * MCAgendaRowHeight - self.todoScrollOffset;
            NSRect checkboxHitArea = NSMakeRect(
                MCAgendaMarkerLeading - 8, rowY, 32, MCAgendaRowHeight
            );
            if (NSPointInRect(point, checkboxHitArea)) {
                [self toggleTodo:item];
            } else if (point.x >= 335) {
                [self deleteTodo:item];
            } else if (point.x >= 49) {
                [self beginEditingTodo:item];
            }
        }
        return;
    }
    if (NSPointInRect(point, NSMakeRect(330, MCFooterTop, 60, 38))) {
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
        NSMenuItem *settingsItem = [menu addItemWithTitle:@"设置…"
                                                   action:@selector(showSettings:)
                                            keyEquivalent:@""];
        settingsItem.target = self;
        NSMenuItem *updateItem = [menu addItemWithTitle:@"检查更新…"
                                                 action:@selector(checkForUpdates:)
                                          keyEquivalent:@""];
        updateItem.target = NSApplication.sharedApplication.delegate;
        [menu addItem:NSMenuItem.separatorItem];
        NSMenuItem *aboutItem = [menu addItemWithTitle:@"关于极简日历"
                                                action:@selector(showAbout:)
                                         keyEquivalent:@""];
        aboutItem.target = self;
        [menu addItem:NSMenuItem.separatorItem];
        NSMenuItem *quitItem = [menu addItemWithTitle:@"退出极简日历"
                                               action:@selector(terminate:)
                                        keyEquivalent:@""];
        quitItem.target = NSApplication.sharedApplication;
        [menu popUpMenuPositioningItem:nil
                            atLocation:NSMakePoint(338, MCFooterTop - 2)
                                inView:self];
    }
}

- (void)showSettings:(id)sender {
    (void)sender;
    if (!self.settingsController) {
        self.settingsController = [[MCSettingsWindowController alloc] init];
    }
    [self.settingsController showRelativeToWindow:self.window];
}

- (void)showAbout:(id)sender {
    (void)sender;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"极简日历";
    NSString *version = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"未知";
    alert.informativeText = [NSString stringWithFormat:
        @"版本 %@\n\n界面数字和英文使用 MiSans Latin。\n"
         @"© 2020–2024 Beijing Xiaomi Mobile Software Co., Ltd. All Rights Reserved.\n"
         @"依照 MiSans 字体知识产权许可协议使用。", version];
    [alert addButtonWithTitle:@"好"];
    [alert addButtonWithTitle:@"查看字体许可"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSAlertSecondButtonReturn) {
            return;
        }
        NSURL *licenseURL = [NSBundle.mainBundle URLForResource:@"MiSans-License"
                                                  withExtension:@"pdf"];
        if (!licenseURL) {
            licenseURL = [NSURL URLWithString:
                @"https://hyperos.mi.com/font-download/"
                 "MiSans%E5%AD%97%E4%BD%93%E7%9F%A5%E8%AF%86%E4%BA%A7%E6%9D%83"
                 "%E8%AE%B8%E5%8F%AF%E5%8D%8F%E8%AE%AE.pdf"];
        }
        [NSWorkspace.sharedWorkspace openURL:licenseURL];
    }];
}

- (void)scrollWheel:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (point.y < [self todoTop]) {
        [self handleCalendarScrollEvent:event allowsHorizontalNavigation:YES];
        return;
    }

    CGFloat direction = event.isDirectionInvertedFromDevice ? -1.0 : 1.0;
    CGFloat physicalHorizontalDelta = event.scrollingDeltaX * direction;
    CGFloat physicalVerticalDelta = event.scrollingDeltaY * direction;
    BOOL verticalDominant = fabs(physicalVerticalDelta) >= fabs(physicalHorizontalDelta);
    CGFloat agendaTop = [self agendaTop];
    CGFloat maxOffset = MAX(0,
        self.agendaRows.count * MCAgendaRowHeight - (MCFooterTop - agendaTop));
    BOOL pointsInsideAgenda = point.y >= [self agendaClipTop] && point.y < MCFooterTop;
    BOOL canScrollAgenda = maxOffset > 0 && verticalDominant && pointsInsideAgenda;
    BOOL continuesViewChange = self.calendarGestureConsumed
        || self.calendarGestureAxis == MCCalendarGestureAxisVertical;
    BOOL scrollsTowardLaterRows = physicalVerticalDelta > 0 && self.todoScrollOffset < maxOffset;
    BOOL scrollsTowardEarlierRows = physicalVerticalDelta < 0 && self.todoScrollOffset > 0;
    if (!continuesViewChange
        && canScrollAgenda
        && (scrollsTowardLaterRows || scrollsTowardEarlierRows)) {
        [self resetCalendarGesture];
        self.todoScrollOffset = MIN(maxOffset,
            MAX(0, self.todoScrollOffset + physicalVerticalDelta));
        [self updateTodoEditorFrame];
        [self refreshDeleteToolTips];
        [self setNeedsDisplay:YES];
        return;
    }

    BOOL targetsViewChange = (!self.weekViewEnabled && physicalVerticalDelta > 0)
        || (self.weekViewEnabled && physicalVerticalDelta < 0);
    if (continuesViewChange || (verticalDominant && targetsViewChange)) {
        [self handleCalendarScrollEvent:event allowsHorizontalNavigation:NO];
        return;
    }

    if (self.agendaRows.count == 0) {
        return;
    }
    if (point.y < [self agendaClipTop] || point.y >= MCFooterTop) {
        [super scrollWheel:event];
        return;
    }
}

- (void)handleCalendarScrollEvent:(NSEvent *)event
       allowsHorizontalNavigation:(BOOL)allowsHorizontalNavigation {
    // Momentum must not turn one physical swipe into multiple period changes.
    if (event.momentumPhase != NSEventPhaseNone) {
        return;
    }

    if (event.phase == NSEventPhaseBegan) {
        [self resetCalendarGesture];
    }

    // Normalize to the physical device direction so the gesture behaves the
    // same with or without macOS Natural Scrolling. Positive Y means swipe up;
    // positive X means swipe left, matching AppKit's physical swipe semantics.
    CGFloat direction = event.isDirectionInvertedFromDevice ? -1.0 : 1.0;
    if (allowsHorizontalNavigation) {
        self.calendarHorizontalGestureDistance += event.scrollingDeltaX * direction;
    }
    self.calendarVerticalGestureDistance += event.scrollingDeltaY * direction;

    CGFloat axisLockDistance = event.hasPreciseScrollingDeltas
        ? MCCalendarGestureAxisLockDistance
        : 1.0;
    if (self.calendarGestureAxis == MCCalendarGestureAxisUndetermined) {
        CGFloat horizontalDistance = fabs(self.calendarHorizontalGestureDistance);
        CGFloat verticalDistance = fabs(self.calendarVerticalGestureDistance);
        if (MAX(horizontalDistance, verticalDistance) >= axisLockDistance) {
            self.calendarGestureAxis = allowsHorizontalNavigation
                && horizontalDistance > verticalDistance
                    ? MCCalendarGestureAxisHorizontal
                    : MCCalendarGestureAxisVertical;
        }
    }

    if (!self.calendarGestureConsumed) {
        CGFloat commitDistance = event.hasPreciseScrollingDeltas
            ? MCCalendarGestureCommitDistance
            : 1.0;
        if (self.calendarGestureAxis == MCCalendarGestureAxisHorizontal) {
            if (self.calendarHorizontalGestureDistance >= commitDistance) {
                self.calendarGestureConsumed = YES;
                [self moveDisplayedPeriodBy:1];
            } else if (self.calendarHorizontalGestureDistance <= -commitDistance) {
                self.calendarGestureConsumed = YES;
                [self moveDisplayedPeriodBy:-1];
            }
        } else if (self.calendarGestureAxis == MCCalendarGestureAxisVertical) {
            if (!self.weekViewEnabled
                && self.calendarVerticalGestureDistance >= commitDistance) {
                self.calendarGestureConsumed = YES;
                [self showWeekView];
            } else if (self.weekViewEnabled
                       && self.calendarVerticalGestureDistance <= -commitDistance) {
                self.calendarGestureConsumed = YES;
                [self showMonthView];
            }
        }
    }

    BOOL finished = (event.phase & (NSEventPhaseEnded | NSEventPhaseCancelled)) != 0;
    BOOL discrete = event.phase == NSEventPhaseNone;
    if (finished || discrete) {
        [self resetCalendarGesture];
    }
}

- (void)resetCalendarGesture {
    self.calendarHorizontalGestureDistance = 0;
    self.calendarVerticalGestureDistance = 0;
    self.calendarGestureConsumed = NO;
    self.calendarGestureAxis = MCCalendarGestureAxisUndetermined;
}

- (void)addTodo:(id)sender {
    NSString *title = self.todoField.stringValue;
    if (!self.systemIntegrationEnabled) {
        [self.previewTodoStore addTitle:title forDate:self.selectedDate];
        self.todoField.stringValue = @"";
        [self reloadAgenda];
        return;
    }
    if (self.todoMutationInProgress) {
        return;
    }
    MCSystemAccessState accessState = self.systemStore.remindersAccessState;
    if (accessState != MCSystemAccessStateGranted) {
        self.statusMessage = accessState == MCSystemAccessStateDenied
            ? @"请在系统设置中允许提醒事项访问"
            : @"正在等待系统提醒事项授权";
        [self setNeedsDisplay:YES];
        return;
    }
    self.todoMutationInProgress = YES;
    [self updateTodoFieldState];
    __weak typeof(self) weakSelf = self;
    [self.systemStore addTodoWithTitle:title forDate:self.selectedDate
        completion:^(NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            self.todoMutationInProgress = NO;
            if (error) {
                self.statusMessage = error.localizedDescription;
            } else {
                self.todoField.stringValue = @"";
                self.statusMessage = nil;
            }
            [self updateTodoFieldState];
            [self reloadAgenda];
            [self.window makeFirstResponder:self.todoField];
        }
    ];
}

- (void)moveMonthBy:(NSInteger)offset {
    NSDate *next = [self.calendar dateByAddingUnit:NSCalendarUnitMonth
                                             value:offset
                                            toDate:self.displayedMonth
                                           options:0];
    self.displayedMonth = [self startOfMonth:next];
    [self rebuildGrid];
    [self setNeedsDisplay:YES];
}

- (void)moveDisplayedPeriodBy:(NSInteger)offset {
    if (!self.weekViewEnabled) {
        [self moveMonthBy:offset];
        return;
    }
    self.selectedDate = [self.calendar dateByAddingUnit:NSCalendarUnitDay
                                                   value:offset * 7
                                                  toDate:self.selectedDate
                                                 options:0];
    self.displayedMonth = [self startOfMonth:self.selectedDate];
    self.todoScrollOffset = 0;
    [self rebuildGrid];
    [self reloadAgenda];
}

- (NSDate *)startOfMonth:(NSDate *)date {
    NSDateComponents *parts = [self.calendar components:NSCalendarUnitYear | NSCalendarUnitMonth
        fromDate:date
    ];
    return [self.calendar dateFromComponents:parts];
}

- (NSDate *)startOfWeek:(NSDate *)date {
    NSDate *day = [self.calendar startOfDayForDate:date];
    NSInteger weekday = [self.calendar component:NSCalendarUnitWeekday fromDate:day];
    NSInteger daysBefore = (weekday - self.calendar.firstWeekday + 7) % 7;
    return [self.calendar dateByAddingUnit:NSCalendarUnitDay
                                     value:-daysBefore
                                    toDate:day
                                   options:0];
}

- (BOOL)isDate:(NSDate *)date inMonth:(NSDate *)month {
    NSDateComponents *left = [self.calendar components:NSCalendarUnitYear | NSCalendarUnitMonth
                                              fromDate:date];
    NSDateComponents *right = [self.calendar components:NSCalendarUnitYear | NSCalendarUnitMonth
                                               fromDate:month];
    return left.year == right.year && left.month == right.month;
}

- (NSInteger)calendarRowCount {
    if (self.weekViewEnabled) {
        return 1;
    }
    return [self monthRowCountForMonth:self.displayedMonth];
}

- (NSInteger)monthRowCountForMonth:(NSDate *)month {
    NSRange days = [self.calendar rangeOfUnit:NSCalendarUnitDay
                                       inUnit:NSCalendarUnitMonth
                                      forDate:month];
    NSInteger weekday = [self.calendar component:NSCalendarUnitWeekday
                                         fromDate:month];
    NSInteger daysBefore = (weekday - self.calendar.firstWeekday + 7) % 7;
    return (daysBefore + days.length + 6) / 7;
}

- (CGFloat)todoTop {
    NSInteger monthRows = self.transitionMonthRowCount > 0
        ? self.transitionMonthRowCount
        : [self monthRowCountForMonth:self.displayedMonth];
    CGFloat visibleRows = 1.0 + self.calendarExpansion * (monthRows - 1);
    return MCGridY + visibleRows * MCCellHeight + 9;
}

- (CGFloat)agendaTop {
    return [self todoTop] + MCAgendaOffset;
}

- (CGFloat)agendaClipTop {
    return [self todoTop] + MCTodoInputOffset + MCTodoInputHeight;
}

- (void)updateDynamicLayout {
    CGFloat maxOffset = MAX(0,
        self.agendaRows.count * MCAgendaRowHeight - (MCFooterTop - [self agendaTop]));
    self.todoScrollOffset = MIN(maxOffset, MAX(0, self.todoScrollOffset));
    NSRect frame = self.todoField.frame;
    frame.origin.y = [self todoTop] + MCTodoInputOffset;
    self.todoField.frame = frame;
    [self updateTodoEditorFrame];
    if (!self.calendarDisplayLink) {
        [self refreshDeleteToolTips];
    }
}

- (void)rebuildGrid {
    if (self.weekViewEnabled) {
        self.gridDates = [self datesForWeek:self.selectedDate];
        [self updateDynamicLayout];
        return;
    }
    self.gridDates = [self datesForMonth:self.displayedMonth];
    [self updateDynamicLayout];
}

- (NSArray<NSDate *> *)datesForWeek:(NSDate *)date {
    NSDate *weekStart = [self startOfWeek:date];
    NSMutableArray<NSDate *> *dates = [[NSMutableArray alloc] initWithCapacity:7];
    for (NSInteger offset = 0; offset < 7; offset++) {
        [dates addObject:[self.calendar dateByAddingUnit:NSCalendarUnitDay
                                                   value:offset
                                                  toDate:weekStart
                                                 options:0]];
    }
    return dates;
}

- (NSArray<NSDate *> *)datesForMonth:(NSDate *)month {
    NSInteger weekday = [self.calendar component:NSCalendarUnitWeekday fromDate:month];
    NSInteger daysBefore = (weekday - self.calendar.firstWeekday + 7) % 7;
    NSDate *gridStart = [self.calendar dateByAddingUnit:NSCalendarUnitDay
                                                  value:-daysBefore
                                                 toDate:month
                                                options:0];
    NSInteger dayCount = [self monthRowCountForMonth:month] * 7;
    NSMutableArray<NSDate *> *dates = [[NSMutableArray alloc] initWithCapacity:dayCount];
    for (NSInteger offset = 0; offset < dayCount; offset++) {
        [dates addObject:[self.calendar dateByAddingUnit:NSCalendarUnitDay
                                                   value:offset
                                                  toDate:gridStart
                                                   options:0]];
    }
    return dates;
}

- (void)prepareCalendarTransitionGeometry {
    self.transitionMonthDates = [self datesForMonth:self.displayedMonth];
    self.transitionWeekDates = [self datesForWeek:self.selectedDate];
    self.transitionMonthRowCount = [self monthRowCountForMonth:self.displayedMonth];
    self.transitionSelectedMonthRow = 0;
    for (NSUInteger index = 0; index < self.transitionMonthDates.count; index++) {
        if ([self.calendar isDate:self.transitionMonthDates[index]
                    inSameDayAsDate:self.selectedDate]) {
            self.transitionSelectedMonthRow = index / 7;
            break;
        }
    }
}

- (void)animateCalendarExpansionTo:(CGFloat)targetExpansion {
    [self.calendarDisplayLink invalidate];
    self.calendarDisplayLink = nil;

    if (!self.window || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        self.calendarExpansion = targetExpansion;
        self.transitionMonthRowCount = 0;
        [self updateDynamicLayout];
        [self setNeedsDisplay:YES];

        if (self.window) {
            self.alphaValue = 0.88;
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = MCReducedMotionFadeDuration;
                context.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23
                                                                                        :1.0
                                                                                        :0.32
                                                                                        :1.0];
                self.animator.alphaValue = 1.0;
            } completionHandler:nil];
        }
        return;
    }

    [self prepareCalendarTransitionGeometry];
    self.calendarAnimationStartExpansion = self.calendarExpansion;
    self.calendarAnimationTargetExpansion = targetExpansion;
    self.calendarAnimationLinearProgress = 0.0;
    self.calendarAnimationStartTime = CACurrentMediaTime();
    self.calendarDisplayLink = [self displayLinkWithTarget:self
                                                  selector:@selector(calendarAnimationTick:)];
    [self.calendarDisplayLink addToRunLoop:NSRunLoop.mainRunLoop
                                   forMode:NSRunLoopCommonModes];
    [self setNeedsDisplay:YES];
}

- (void)calendarAnimationTick:(CADisplayLink *)displayLink {
    CGFloat linearProgress = (CACurrentMediaTime() - self.calendarAnimationStartTime)
        / MCCalendarTransitionDuration;
    linearProgress = MIN(1.0, MAX(0.0, linearProgress));
    self.calendarAnimationLinearProgress = linearProgress;
    CGFloat easedProgress = MCEaseInOutProgress(linearProgress);
    self.calendarExpansion = self.calendarAnimationStartExpansion
        + (self.calendarAnimationTargetExpansion - self.calendarAnimationStartExpansion)
        * easedProgress;
    [self updateDynamicLayout];
    [self setNeedsDisplay:YES];

    if (linearProgress >= 1.0) {
        self.calendarExpansion = self.calendarAnimationTargetExpansion;
        [displayLink invalidate];
        self.calendarDisplayLink = nil;
        self.transitionMonthDates = @[];
        self.transitionWeekDates = @[];
        self.transitionMonthRowCount = 0;
        [self updateDynamicLayout];
        [self setNeedsDisplay:YES];
    }
}

- (void)reloadAgenda {
    if (!self.systemIntegrationEnabled) {
        self.visibleTodos = [self.previewTodoStore itemsForDate:self.selectedDate];
        self.visibleEvents = @[];
        [self rebuildAgendaRows];
        return;
    }

    NSString *requestedDateKey = MCDateKey(self.selectedDate);
    __weak typeof(self) weakSelf = self;
    [self.systemStore loadAgendaForDate:self.selectedDate
        completion:^(NSArray<NSDictionary *> *todos, NSArray<NSDictionary *> *events) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || ![MCDateKey(self.selectedDate) isEqualToString:requestedDateKey]) {
                return;
            }
            self.visibleTodos = todos;
            self.visibleEvents = events;
            if (self.systemStore.remindersAccessState == MCSystemAccessStateDenied
                && self.systemStore.calendarAccessState == MCSystemAccessStateDenied) {
                self.statusMessage = @"请在系统设置中允许日历和提醒事项访问";
            } else if (!self.todoMutationInProgress) {
                self.statusMessage = nil;
            }
            [self rebuildAgendaRows];
        }
    ];
}

- (void)rebuildAgendaRows {
    NSMutableArray<NSDictionary *> *rows = [[NSMutableArray alloc] init];
    [rows addObjectsFromArray:self.visibleEvents ?: @[]];
    [rows addObjectsFromArray:self.visibleTodos ?: @[]];
    self.agendaRows = rows;
    CGFloat maxOffset = MAX(0,
        self.agendaRows.count * MCAgendaRowHeight - (MCFooterTop - [self agendaTop]));
    self.todoScrollOffset = MIN(self.todoScrollOffset, maxOffset);
    [self updateTodoEditorFrame];
    [self refreshDeleteToolTips];
    [self setNeedsDisplay:YES];
}

- (NSString *)nextHolidayText {
    NSDate *today = [self.calendar startOfDayForDate:[NSDate date]];
    NSDate *festivalDate = nil;
    MCHoliday *holiday = [self.holidays nextFestivalOnOrAfterDate:today
                                                     festivalDate:&festivalDate];
    if (!holiday || !festivalDate) {
        return @"暂无后续法定假期";
    }

    NSString *name = holiday.label;
    BOOL keepsOriginalName = [name hasSuffix:@"节"]
        || [name isEqualToString:@"元旦"]
        || [name isEqualToString:@"除夕"];
    if (!keepsOriginalName) {
        name = [name stringByAppendingString:@"节"];
    }
    NSInteger days = [self.calendar components:NSCalendarUnitDay
                                      fromDate:today
                                        toDate:festivalDate
                                       options:0].day;
    return [NSString stringWithFormat:@"下一个假期：%@（%ld天）", name, (long)days];
}

- (void)beginEditingTodo:(NSDictionary *)item {
    NSString *itemID = item[@"id"];
    if (itemID.length == 0) {
        return;
    }
    if ([self.editingTodoID isEqualToString:itemID]) {
        [self.window makeFirstResponder:self.editTodoField];
        return;
    }
    [self cancelTodoEditing];
    self.editingTodoID = itemID;
    self.editingOriginalTitle = item[@"title"] ?: @"";
    self.editTodoField.stringValue = self.editingOriginalTitle;
    self.editTodoField.enabled = YES;
    self.editTodoField.toolTip = nil;
    [self updateTodoEditorFrame];
    [self.window makeFirstResponder:self.editTodoField];
    [self.editTodoField selectText:nil];
    [self setNeedsDisplay:YES];
}

- (void)commitTodoEditing:(id)sender {
    (void)sender;
    if (self.editingTodoID.length == 0 || self.todoEditInProgress) {
        return;
    }
    NSString *title = [self.editTodoField.stringValue stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (title.length == 0) {
        self.statusMessage = @"Todo 内容不能为空";
        self.editTodoField.toolTip = self.statusMessage;
        NSBeep();
        return;
    }
    if ([title isEqualToString:self.editingOriginalTitle]) {
        [self cancelTodoEditing];
        return;
    }

    NSString *itemID = [self.editingTodoID copy];
    if (!self.systemIntegrationEnabled) {
        [self.previewTodoStore updateItemWithID:itemID title:title];
        [self cancelTodoEditing];
        [self reloadAgenda];
        return;
    }

    self.todoEditInProgress = YES;
    self.editTodoField.enabled = NO;
    __weak typeof(self) weakSelf = self;
    [self.systemStore updateTodoWithID:itemID title:title completion:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.todoEditInProgress = NO;
        if (error) {
            self.statusMessage = error.localizedDescription;
            self.editTodoField.toolTip = error.localizedDescription;
            self.editTodoField.enabled = YES;
            [self.window makeFirstResponder:self.editTodoField];
            NSBeep();
            return;
        }
        self.statusMessage = nil;
        [self cancelTodoEditing];
        [self reloadAgenda];
    }];
}

- (void)cancelTodoEditing {
    self.editingTodoID = nil;
    self.editingOriginalTitle = nil;
    self.todoEditInProgress = NO;
    self.editTodoField.enabled = YES;
    self.editTodoField.hidden = YES;
    self.editTodoField.stringValue = @"";
    self.editTodoField.toolTip = nil;
    if (self.window) {
        [self.window makeFirstResponder:self];
    }
    [self setNeedsDisplay:YES];
}

- (void)updateTodoEditorFrame {
    if (self.editingTodoID.length == 0) {
        self.editTodoField.hidden = YES;
        return;
    }
    NSUInteger index = [self.agendaRows indexOfObjectPassingTest:
        ^BOOL(NSDictionary *item, NSUInteger rowIndex, BOOL *stop) {
            (void)rowIndex;
            BOOL match = ![item[@"kind"] isEqualToString:@"event"]
                && [item[@"id"] isEqualToString:self.editingTodoID];
            if (match) {
                *stop = YES;
            }
            return match;
        }
    ];
    if (index == NSNotFound) {
        [self cancelTodoEditing];
        return;
    }

    CGFloat agendaTop = [self agendaTop];
    CGFloat rowY = agendaTop + index * MCAgendaRowHeight - self.todoScrollOffset;
    if (rowY < [self agendaClipTop] || rowY + MCAgendaRowHeight > MCFooterTop) {
        self.editTodoField.hidden = YES;
        return;
    }
    NSDictionary *item = self.agendaRows[index];
    NSString *time = item[@"time"] ?: @"";
    CGFloat width = time.length > 0 ? 225 : 275;
    self.editTodoField.frame = NSMakeRect(MCAgendaTextLeading, rowY + 8, width, 32);
    self.editTodoField.hidden = NO;
}

- (BOOL)control:(NSControl *)control
       textView:(NSTextView *)textView
doCommandBySelector:(SEL)commandSelector {
    (void)textView;
    if (control == self.editTodoField && commandSelector == @selector(cancelOperation:)) {
        [self cancelTodoEditing];
        return YES;
    }
    if (control == self.editTodoField
        && (commandSelector == @selector(insertTab:)
            || commandSelector == @selector(insertBacktab:))) {
        [self commitTodoEditing:control];
        return YES;
    }
    return NO;
}

- (void)toggleTodo:(NSDictionary *)item {
    if (!self.systemIntegrationEnabled) {
        [self.previewTodoStore toggleItemWithID:item[@"id"]];
        [self reloadAgenda];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self.systemStore toggleTodoWithID:item[@"id"] completion:^(NSError *error) {
        weakSelf.statusMessage = error.localizedDescription;
        [weakSelf reloadAgenda];
    }];
}

- (void)deleteTodo:(NSDictionary *)item {
    if (!self.systemIntegrationEnabled) {
        [self.previewTodoStore deleteItemWithID:item[@"id"]];
        [self reloadAgenda];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self.systemStore deleteTodoWithID:item[@"id"] completion:^(NSError *error) {
        weakSelf.statusMessage = error.localizedDescription;
        [weakSelf reloadAgenda];
    }];
}

- (void)updateTodoFieldState {
    if (!self.systemIntegrationEnabled) {
        self.todoField.enabled = YES;
        self.todoField.placeholderString = @"添加 todo，回车保存";
        return;
    }
    self.todoField.enabled = !self.todoMutationInProgress;
    if (self.todoMutationInProgress) {
        self.todoField.placeholderString = @"正在保存到系统提醒事项…";
    } else {
        self.todoField.placeholderString = @"添加 todo，回车保存";
    }
}

- (void)controlTextDidBeginEditing:(NSNotification *)notification {
    if (notification.object == self.todoField
        || notification.object == self.editTodoField) {
        [self setNeedsDisplay:YES];
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    if (notification.object == self.todoField
        || notification.object == self.editTodoField) {
        [self setNeedsDisplay:YES];
    }
}

- (void)drawFigmaIconNamed:(NSString *)name
                    inRect:(NSRect)rect
                      tint:(NSColor *)tint {
    NSImage *image = MCFigmaIcon(name, tint);
    if (!image) {
        return;
    }
    [image drawInRect:rect
             fromRect:NSZeroRect
            operation:NSCompositingOperationSourceOver
             fraction:1.0
       respectFlipped:YES
                hints:@{NSImageHintInterpolation: @(NSImageInterpolationHigh)}];
}

- (void)drawText:(NSString *)text
          inRect:(NSRect)rect
            font:(NSFont *)font
           color:(NSColor *)color
       alignment:(NSTextAlignment)alignment {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = alignment;
    [text drawInRect:rect withAttributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: style,
    }];
}

- (void)drawVerticallyCenteredText:(NSString *)text
                            inRect:(NSRect)rect
                              font:(NSFont *)font
                             color:(NSColor *)color
                         alignment:(NSTextAlignment)alignment {
    NSDictionary *attributes = @{NSFontAttributeName: font};
    CGFloat textHeight = ceil([text sizeWithAttributes:attributes].height);
    NSRect centeredRect = rect;
    centeredRect.origin.y += floor((NSHeight(rect) - textHeight) / 2.0);
    centeredRect.size.height = textHeight;
    [self drawText:text
            inRect:centeredRect
              font:font
             color:color
         alignment:alignment];
}

- (void)drawVerticallyCenteredAttributedText:(NSAttributedString *)text
                                       inRect:(NSRect)rect {
    CGFloat textHeight = ceil(text.size.height);
    NSRect centeredRect = rect;
    centeredRect.origin.y += floor((NSHeight(rect) - textHeight) / 2.0);
    centeredRect.size.height = textHeight;
    [text drawInRect:centeredRect];
}

- (void)drawOpticallyCenteredText:(NSString *)text
                           inRect:(NSRect)rect
                             font:(NSFont *)font
                            color:(NSColor *)color {
    NSAttributedString *attributedText = [[NSAttributedString alloc]
        initWithString:text
            attributes:@{
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: color,
            }];
    CTLineRef line = CTLineCreateWithAttributedString(
        (__bridge CFAttributedStringRef)attributedText
    );
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(context);
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextTranslateCTM(context, 0, NSMaxY(self.bounds));
    CGContextScaleCTM(context, 1, -1);

    CGRect inkBounds = CTLineGetImageBounds(line, context);
    CGFloat centerX = NSMidX(rect);
    CGFloat centerY = NSMaxY(self.bounds) - NSMidY(rect);
    CGContextSetTextPosition(
        context,
        centerX - CGRectGetMidX(inkBounds),
        centerY - CGRectGetMidY(inkBounds)
    );
    CTLineDraw(line, context);

    CGContextRestoreGState(context);
    CFRelease(line);
}

@end
