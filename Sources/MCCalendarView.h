#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MCCalendarView : NSView <NSTextFieldDelegate>

- (instancetype)initWithFrame:(NSRect)frameRect defaults:(NSUserDefaults *)defaults;
- (instancetype)initWithFrame:(NSRect)frameRect
                      defaults:(NSUserDefaults *)defaults
      systemIntegrationEnabled:(BOOL)systemIntegrationEnabled;
- (void)startSystemSync;
- (void)refreshSystemData;
- (void)refreshToday;
- (void)showWeekView;
- (void)showMonthView;

@end

NS_ASSUME_NONNULL_END
