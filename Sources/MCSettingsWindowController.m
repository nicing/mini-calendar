#import "MCSettingsWindowController.h"
#import "MCData.h"

@interface MCAccentSwatchButton : NSButton

@property(nonatomic, copy) NSString *accentIdentifier;
@property(nonatomic, strong) NSColor *swatchColor;
@property(nonatomic) BOOL selectedSwatch;

@end


@implementation MCAccentSwatchButton

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect colorRect = NSInsetRect(self.bounds, 4, 4);

    [NSGraphicsContext saveGraphicsState];
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [NSColor colorWithWhite:0.0 alpha:0.14];
    shadow.shadowBlurRadius = 2;
    shadow.shadowOffset = NSMakeSize(0, 1);
    [shadow set];
    [self.swatchColor setFill];
    [[NSBezierPath bezierPathWithOvalInRect:colorRect] fill];
    [NSGraphicsContext restoreGraphicsState];

    if (self.selectedSwatch) {
        NSBezierPath *selectionRing = [NSBezierPath bezierPathWithOvalInRect:
            NSInsetRect(self.bounds, 0.75, 0.75)
        ];
        selectionRing.lineWidth = 1.5;
        [[NSColor.labelColor colorWithAlphaComponent:0.72] setStroke];
        [selectionRing stroke];
    }
}

@end


@interface MCSettingsWindowController ()

@property(nonatomic, copy) NSArray<MCAccentSwatchButton *> *swatchButtons;

@end


@implementation MCSettingsWindowController

- (instancetype)init {
    NSRect contentRect = NSMakeRect(0, 0, 452, 122);
    NSPanel *window = [[NSPanel alloc]
        initWithContentRect:contentRect
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                    backing:NSBackingStoreBuffered
                      defer:NO
    ];
    self = [super initWithWindow:window];
    if (self) {
        window.title = @"设置";
        window.titlebarAppearsTransparent = YES;
        window.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
        window.releasedWhenClosed = NO;
        window.hidesOnDeactivate = NO;
        window.floatingPanel = NO;
        window.level = NSNormalWindowLevel;
        window.animationBehavior = NSWindowAnimationBehaviorDocumentWindow;

        NSVisualEffectView *background = [[NSVisualEffectView alloc]
            initWithFrame:contentRect
        ];
        background.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        background.material = NSVisualEffectMaterialPopover;
        background.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        background.state = NSVisualEffectStateActive;
        window.contentView = background;

        NSTextField *title = [NSTextField labelWithString:@"高亮颜色"];
        title.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
        title.textColor = NSColor.labelColor;

        NSTextField *description = [NSTextField
            labelWithString:@"颜色会立即应用并自动保存"
        ];
        description.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
        description.textColor = NSColor.secondaryLabelColor;

        NSStackView *swatchRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
        swatchRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        swatchRow.alignment = NSLayoutAttributeCenterY;
        swatchRow.spacing = 6;
        swatchRow.distribution = NSStackViewDistributionFill;

        NSMutableArray<MCAccentSwatchButton *> *buttons = [NSMutableArray array];
        for (NSString *identifier in MCAccentColorIdentifiers()) {
            MCAccentSwatchButton *button = [[MCAccentSwatchButton alloc]
                initWithFrame:NSMakeRect(0, 0, 32, 32)
            ];
            button.accentIdentifier = identifier;
            button.swatchColor = MCAccentColorForIdentifier(identifier);
            button.bordered = NO;
            button.title = @"";
            button.target = self;
            button.action = @selector(selectAccentColor:);
            button.toolTip = MCAccentColorName(identifier);
            button.translatesAutoresizingMaskIntoConstraints = NO;
            [button.widthAnchor constraintEqualToConstant:32].active = YES;
            [button.heightAnchor constraintEqualToConstant:32].active = YES;
            [button setAccessibilityLabel:MCAccentColorName(identifier)];
            [swatchRow addArrangedSubview:button];
            [buttons addObject:button];
        }
        self.swatchButtons = buttons.copy;

        NSStackView *contentStack = [[NSStackView alloc] initWithFrame:NSZeroRect];
        contentStack.orientation = NSUserInterfaceLayoutOrientationVertical;
        contentStack.alignment = NSLayoutAttributeLeading;
        contentStack.spacing = 4;
        [contentStack addArrangedSubview:title];
        [contentStack addArrangedSubview:description];
        [contentStack addArrangedSubview:swatchRow];
        [contentStack setCustomSpacing:12 afterView:description];
        contentStack.translatesAutoresizingMaskIntoConstraints = NO;
        [background addSubview:contentStack];

        [NSLayoutConstraint activateConstraints:@[
            [contentStack.leadingAnchor constraintEqualToAnchor:background.leadingAnchor
                                                       constant:20],
            [contentStack.trailingAnchor constraintLessThanOrEqualToAnchor:background.trailingAnchor
                                                                  constant:-20],
            [contentStack.topAnchor constraintEqualToAnchor:background.topAnchor
                                                   constant:16],
            [swatchRow.trailingAnchor constraintEqualToAnchor:background.trailingAnchor
                                                     constant:-20],
        ]];
        [self refreshSelection];
    }
    return self;
}

- (void)showRelativeToWindow:(NSWindow *)parentWindow {
    NSWindow *window = self.window;
    if (parentWindow.visible) {
        NSRect parentFrame = parentWindow.frame;
        NSRect settingsFrame = window.frame;
        settingsFrame.origin.x = round(NSMidX(parentFrame) - NSWidth(settingsFrame) / 2);
        settingsFrame.origin.y = round(NSMidY(parentFrame) - NSHeight(settingsFrame) / 2);
        [window setFrame:settingsFrame display:NO];
    } else {
        [window center];
    }
    [self refreshSelection];
    [NSApplication.sharedApplication activateIgnoringOtherApps:YES];
    [window makeKeyAndOrderFront:nil];
}

- (void)selectAccentColor:(MCAccentSwatchButton *)sender {
    MCSetAccentColorIdentifier(sender.accentIdentifier);
    [self refreshSelection];
}

- (void)refreshSelection {
    NSString *selectedIdentifier = MCAccentColorIdentifier();
    for (MCAccentSwatchButton *button in self.swatchButtons) {
        button.selectedSwatch = [button.accentIdentifier isEqualToString:selectedIdentifier];
        NSString *name = MCAccentColorName(button.accentIdentifier);
        button.toolTip = button.selectedSwatch
            ? [NSString stringWithFormat:@"%@（已选择）", name]
            : name;
        [button setAccessibilityLabel:button.toolTip];
        [button setNeedsDisplay:YES];
    }
}

@end
