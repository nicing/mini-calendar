#import <AppKit/AppKit.h>
#import <EventKit/EventKit.h>
#import "MCData.h"

NSCalendar *MCCalendar(void) {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.locale = [NSLocale localeWithLocaleIdentifier:@"zh_Hans_CN"];
    calendar.timeZone = NSTimeZone.localTimeZone;
    calendar.firstWeekday = 2;
    return calendar;
}

NSColor *MCAccentColor(void) {
    return [NSColor colorWithSRGBRed:0.98 green:0.31 blue:0.33 alpha:1.0];
}

NSString *MCDateKey(NSDate *date) {
    NSDateComponents *parts = [MCCalendar() components:
        NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
        fromDate:date
    ];
    return [NSString stringWithFormat:@"%04ld-%02ld-%02ld",
        (long)parts.year, (long)parts.month, (long)parts.day
    ];
}

NSDate *MCDateFromKey(NSString *key) {
    NSArray<NSString *> *parts = [key componentsSeparatedByString:@"-"];
    if (parts.count != 3) {
        return nil;
    }
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = parts[0].integerValue;
    components.month = parts[1].integerValue;
    components.day = parts[2].integerValue;
    return [MCCalendar() dateFromComponents:components];
}

@implementation MCHoliday

- (instancetype)initWithLabel:(NSString *)label kind:(MCHolidayKind)kind {
    self = [super init];
    if (self) {
        _label = [label copy];
        _kind = kind;
    }
    return self;
}

@end

@interface MCHolidayService ()

@property(nonatomic, strong) NSMutableDictionary<NSString *, MCHoliday *> *records;

@end

@implementation MCHolidayService

- (instancetype)init {
    self = [super init];
    if (self) {
        _records = [[NSMutableDictionary alloc] init];
        [self load2025];
        [self load2026];
    }
    return self;
}

- (MCHoliday *)holidayForDate:(NSDate *)date {
    return self.records[MCDateKey(date)];
}

- (MCHoliday *)nextFestivalOnOrAfterDate:(NSDate *)date
                            festivalDate:(NSDate **)festivalDate {
    NSCalendar *calendar = MCCalendar();
    NSDate *current = [calendar startOfDayForDate:date];
    for (NSInteger offset = 0; offset <= 370; offset++) {
        MCHoliday *holiday = [self holidayForDate:current];
        if (holiday && holiday.kind == MCHolidayKindFestival) {
            if (festivalDate) {
                *festivalDate = current;
            }
            return holiday;
        }
        current = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:current options:0];
    }
    if (festivalDate) {
        *festivalDate = nil;
    }
    return nil;
}

- (void)addFestival:(NSString *)name on:(NSString *)dateKey {
    self.records[dateKey] = [[MCHoliday alloc] initWithLabel:name kind:MCHolidayKindFestival];
}

- (void)addMakeUpWorkDays:(NSArray<NSString *> *)dateKeys {
    for (NSString *dateKey in dateKeys) {
        self.records[dateKey] = [[MCHoliday alloc] initWithLabel:@"补班" kind:MCHolidayKindMakeUpWork];
    }
}

- (void)addDayOffFrom:(NSString *)startKey through:(NSString *)endKey {
    NSDate *current = MCDateFromKey(startKey);
    NSDate *end = MCDateFromKey(endKey);
    NSCalendar *calendar = MCCalendar();
    while (current && end && [current compare:end] != NSOrderedDescending) {
        self.records[MCDateKey(current)] = [[MCHoliday alloc] initWithLabel:@"放假" kind:MCHolidayKindDayOff];
        current = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:current options:0];
    }
}

- (void)load2025 {
    // 国办发明电〔2024〕12号
    [self addDayOffFrom:@"2025-01-01" through:@"2025-01-01"];
    [self addFestival:@"元旦" on:@"2025-01-01"];

    [self addDayOffFrom:@"2025-01-28" through:@"2025-02-04"];
    [self addFestival:@"除夕" on:@"2025-01-28"];
    [self addFestival:@"春节" on:@"2025-01-29"];
    [self addMakeUpWorkDays:@[@"2025-01-26", @"2025-02-08"]];

    [self addDayOffFrom:@"2025-04-04" through:@"2025-04-06"];
    [self addFestival:@"清明" on:@"2025-04-04"];

    [self addDayOffFrom:@"2025-05-01" through:@"2025-05-05"];
    [self addFestival:@"劳动节" on:@"2025-05-01"];
    [self addMakeUpWorkDays:@[@"2025-04-27"]];

    [self addDayOffFrom:@"2025-05-31" through:@"2025-06-02"];
    [self addFestival:@"端午" on:@"2025-05-31"];

    [self addDayOffFrom:@"2025-10-01" through:@"2025-10-08"];
    [self addFestival:@"国庆" on:@"2025-10-01"];
    [self addFestival:@"中秋" on:@"2025-10-06"];
    [self addMakeUpWorkDays:@[@"2025-09-28", @"2025-10-11"]];
}

- (void)load2026 {
    // 国办发明电〔2025〕7号
    [self addDayOffFrom:@"2026-01-01" through:@"2026-01-03"];
    [self addFestival:@"元旦" on:@"2026-01-01"];
    [self addMakeUpWorkDays:@[@"2026-01-04"]];

    [self addDayOffFrom:@"2026-02-15" through:@"2026-02-23"];
    [self addFestival:@"除夕" on:@"2026-02-16"];
    [self addFestival:@"春节" on:@"2026-02-17"];
    [self addMakeUpWorkDays:@[@"2026-02-14", @"2026-02-28"]];

    [self addDayOffFrom:@"2026-04-04" through:@"2026-04-06"];
    [self addFestival:@"清明" on:@"2026-04-05"];

    [self addDayOffFrom:@"2026-05-01" through:@"2026-05-05"];
    [self addFestival:@"劳动节" on:@"2026-05-01"];
    [self addMakeUpWorkDays:@[@"2026-05-09"]];

    [self addDayOffFrom:@"2026-06-19" through:@"2026-06-21"];
    [self addFestival:@"端午" on:@"2026-06-19"];

    [self addDayOffFrom:@"2026-09-25" through:@"2026-09-27"];
    [self addFestival:@"中秋" on:@"2026-09-25"];

    [self addDayOffFrom:@"2026-10-01" through:@"2026-10-07"];
    [self addFestival:@"国庆" on:@"2026-10-01"];
    [self addMakeUpWorkDays:@[@"2026-09-20", @"2026-10-10"]];
}

@end

@implementation MCLunarService

- (NSCalendar *)lunarCalendar {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierChinese];
    calendar.locale = [NSLocale localeWithLocaleIdentifier:@"zh_Hans_CN"];
    calendar.timeZone = NSTimeZone.localTimeZone;
    return calendar;
}

- (NSDateComponents *)componentsForDate:(NSDate *)date {
    return [[self lunarCalendar] components:NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
}

- (NSString *)shortTextForDate:(NSDate *)date {
    NSDateComponents *parts = [self componentsForDate:date];
    NSString *festival = [self festivals][
        [NSString stringWithFormat:@"%ld-%ld", (long)parts.month, (long)parts.day]
    ];
    if (festival) {
        return festival;
    }
    if ([self isNewYearsEve:date]) {
        return @"除夕";
    }
    NSArray<NSString *> *months = [self monthNames];
    NSArray<NSString *> *days = [self dayNames];
    if (parts.day == 1 && parts.month >= 1 && parts.month <= (NSInteger)months.count) {
        return [NSString stringWithFormat:@"%@%@", parts.leapMonth ? @"闰" : @"", months[parts.month - 1]];
    }
    if (parts.day >= 1 && parts.day <= (NSInteger)days.count) {
        return days[parts.day - 1];
    }
    return @"";
}

- (NSString *)longTextForDate:(NSDate *)date {
    NSDateComponents *parts = [self componentsForDate:date];
    NSArray<NSString *> *months = [self monthNames];
    NSArray<NSString *> *days = [self dayNames];
    NSString *month = parts.month >= 1 && parts.month <= (NSInteger)months.count ? months[parts.month - 1] : @"";
    NSString *day = parts.day >= 1 && parts.day <= (NSInteger)days.count ? days[parts.day - 1] : @"";
    return [NSString stringWithFormat:@"农历%@%@%@", parts.leapMonth ? @"闰" : @"", month, day];
}

- (BOOL)isNewYearsEve:(NSDate *)date {
    NSDateComponents *current = [self componentsForDate:date];
    if (current.month != 12 || current.day < 29) {
        return NO;
    }
    NSDate *tomorrow = [MCCalendar() dateByAddingUnit:NSCalendarUnitDay value:1 toDate:date options:0];
    NSDateComponents *next = [self componentsForDate:tomorrow];
    return next.month == 1 && next.day == 1;
}

- (NSDictionary<NSString *, NSString *> *)festivals {
    return @{
        @"1-1": @"春节",
        @"1-15": @"元宵",
        @"5-5": @"端午",
        @"7-7": @"七夕",
        @"8-15": @"中秋",
        @"9-9": @"重阳",
        @"12-8": @"腊八",
    };
}

- (NSArray<NSString *> *)monthNames {
    return @[@"正月", @"二月", @"三月", @"四月", @"五月", @"六月",
             @"七月", @"八月", @"九月", @"十月", @"冬月", @"腊月"];
}

- (NSArray<NSString *> *)dayNames {
    return @[@"初一", @"初二", @"初三", @"初四", @"初五", @"初六", @"初七", @"初八", @"初九", @"初十",
             @"十一", @"十二", @"十三", @"十四", @"十五", @"十六", @"十七", @"十八", @"十九", @"二十",
             @"廿一", @"廿二", @"廿三", @"廿四", @"廿五", @"廿六", @"廿七", @"廿八", @"廿九", @"三十"];
}

@end

@interface MCTodoStore ()

@property(nonatomic, strong) NSUserDefaults *defaults;
@property(nonatomic, strong) NSMutableArray<NSMutableDictionary *> *mutableItems;

@end

@implementation MCTodoStore

static NSString * const MCTodoStorageKey = @"mini-calendar.todos.v1";
static NSString * const MCTodoMigrationKey = @"mini-calendar.todos.eventkit-migration.v1";

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    self = [super init];
    if (self) {
        _defaults = defaults;
        NSArray *saved = [defaults arrayForKey:MCTodoStorageKey] ?: @[];
        _mutableItems = [[NSMutableArray alloc] initWithCapacity:saved.count];
        for (NSDictionary *item in saved) {
            [_mutableItems addObject:[item mutableCopy]];
        }
    }
    return self;
}

- (NSArray<NSDictionary *> *)allItems {
    return [self.mutableItems copy];
}

- (NSArray<NSDictionary *> *)itemsForDate:(NSDate *)date {
    NSString *key = MCDateKey(date);
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        (void)bindings;
        return [item[@"dateKey"] isEqualToString:key];
    }];
    NSArray *filtered = [self.mutableItems filteredArrayUsingPredicate:predicate];
    return [filtered sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        BOOL leftDone = [left[@"done"] boolValue];
        BOOL rightDone = [right[@"done"] boolValue];
        if (leftDone != rightDone) {
            return leftDone ? NSOrderedDescending : NSOrderedAscending;
        }
        return [left[@"createdAt"] compare:right[@"createdAt"]];
    }];
}

- (void)addTitle:(NSString *)title forDate:(NSDate *)date {
    NSString *clean = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (clean.length == 0) {
        return;
    }
    [self.mutableItems addObject:[@{
        @"id": NSUUID.UUID.UUIDString,
        @"title": clean,
        @"dateKey": MCDateKey(date),
        @"done": @NO,
        @"createdAt": [NSDate date],
    } mutableCopy]];
    [self save];
}

- (void)updateItemWithID:(NSString *)itemID title:(NSString *)title {
    NSString *clean = [title stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (clean.length == 0) {
        return;
    }
    for (NSMutableDictionary *item in self.mutableItems) {
        if ([item[@"id"] isEqualToString:itemID]) {
            item[@"title"] = clean;
            break;
        }
    }
    [self save];
}

- (void)toggleItemWithID:(NSString *)itemID {
    for (NSMutableDictionary *item in self.mutableItems) {
        if ([item[@"id"] isEqualToString:itemID]) {
            item[@"done"] = @(![item[@"done"] boolValue]);
            break;
        }
    }
    [self save];
}

- (void)deleteItemWithID:(NSString *)itemID {
    NSIndexSet *matches = [self.mutableItems indexesOfObjectsPassingTest:
        ^BOOL(NSDictionary *item, NSUInteger index, BOOL *stop) {
            (void)index;
            (void)stop;
            return [item[@"id"] isEqualToString:itemID];
        }
    ];
    [self.mutableItems removeObjectsAtIndexes:matches];
    [self save];
}

- (void)save {
    [self.defaults setObject:self.mutableItems forKey:MCTodoStorageKey];
}

@end

@interface MCSystemDataStore ()

@property(nonatomic, strong) EKEventStore *eventStore;
@property(nonatomic, strong) NSUserDefaults *defaults;
@property(nonatomic) BOOL accessRequestStarted;

@end

@implementation MCSystemDataStore

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    self = [super init];
    if (self) {
        _defaults = defaults;
        _eventStore = [[EKEventStore alloc] init];
        [NSNotificationCenter.defaultCenter
            addObserver:self
               selector:@selector(eventStoreChanged:)
                   name:EKEventStoreChangedNotification
                 object:_eventStore];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (MCSystemAccessState)remindersAccessState {
    return [self accessStateForEntityType:EKEntityTypeReminder];
}

- (MCSystemAccessState)calendarAccessState {
    return [self accessStateForEntityType:EKEntityTypeEvent];
}

- (MCSystemAccessState)accessStateForEntityType:(EKEntityType)entityType {
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:entityType];
    if (status == EKAuthorizationStatusFullAccess) {
        return MCSystemAccessStateGranted;
    }
    if (status == EKAuthorizationStatusNotDetermined) {
        return MCSystemAccessStateUnknown;
    }
    return MCSystemAccessStateDenied;
}

- (void)requestAccessWithCompletion:(void (^)(void))completion {
    if (self.accessRequestStarted) {
        if (completion) {
            completion();
        }
        return;
    }
    self.accessRequestStarted = YES;

    __weak typeof(self) weakSelf = self;
    [self requestReminderAccessWithCompletion:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        // Reminders and Calendar permissions are independent. Refresh the UI
        // as soon as Reminders resolves instead of waiting for Calendar access.
        [self notifyChange];
        [self migrateLocalTodosIfNeededWithCompletion:^{
            [self requestCalendarAccessWithCompletion:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion();
                    }
                    [self notifyChange];
                });
            }];
        }];
    }];
}

- (void)requestReminderAccessWithCompletion:(void (^)(void))completion {
    if (self.remindersAccessState != MCSystemAccessStateUnknown) {
        completion();
        return;
    }
    [self.eventStore requestFullAccessToRemindersWithCompletion:
        ^(BOOL granted, NSError *error) {
            (void)granted;
            if (error) {
                NSLog(@"Unable to request Reminders access: %@", error);
            }
            dispatch_async(dispatch_get_main_queue(), completion);
        }
    ];
}

- (void)requestCalendarAccessWithCompletion:(void (^)(void))completion {
    if (self.calendarAccessState != MCSystemAccessStateUnknown) {
        completion();
        return;
    }
    [self.eventStore requestFullAccessToEventsWithCompletion:
        ^(BOOL granted, NSError *error) {
            (void)granted;
            if (error) {
                NSLog(@"Unable to request Calendar access: %@", error);
            }
            dispatch_async(dispatch_get_main_queue(), completion);
        }
    ];
}

- (void)loadAgendaForDate:(NSDate *)date completion:(MCSystemAgendaCompletion)completion {
    NSArray<NSDictionary *> *events = [self eventItemsForDate:date];
    if (self.remindersAccessState != MCSystemAccessStateGranted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], events);
        });
        return;
    }

    NSPredicate *predicate = [self.eventStore predicateForRemindersInCalendars:nil];
    [self.eventStore fetchRemindersMatchingPredicate:predicate
        completion:^(NSArray<EKReminder *> *reminders) {
            NSArray<NSDictionary *> *todos = [self todoItemsFromReminders:reminders forDate:date];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(todos, events);
            });
        }
    ];
}

- (NSArray<NSDictionary *> *)eventItemsForDate:(NSDate *)date {
    if (self.calendarAccessState != MCSystemAccessStateGranted) {
        return @[];
    }
    NSDate *start = [MCCalendar() startOfDayForDate:date];
    NSDate *end = [MCCalendar() dateByAddingUnit:NSCalendarUnitDay value:1 toDate:start options:0];
    NSPredicate *predicate = [self.eventStore predicateForEventsWithStartDate:start
                                                                      endDate:end
                                                                    calendars:nil];
    NSArray<EKEvent *> *events = [self.eventStore eventsMatchingPredicate:predicate];
    NSMutableArray<NSDictionary *> *items = [[NSMutableArray alloc] initWithCapacity:events.count];
    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
    timeFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_Hans_CN"];
    timeFormatter.dateFormat = @"HH:mm";

    for (EKEvent *event in events) {
        NSString *time = @"全天";
        if (!event.allDay) {
            time = [[MCCalendar() startOfDayForDate:event.startDate] isEqualToDate:start]
                ? [timeFormatter stringFromDate:event.startDate]
                : @"持续";
        }
        NSColor *color = nil;
        if (event.calendar.CGColor) {
            color = [NSColor colorWithCGColor:event.calendar.CGColor];
        }
        color = color ?: NSColor.systemBlueColor;
        [items addObject:@{
            @"kind": @"event",
            @"id": event.eventIdentifier ?: NSUUID.UUID.UUIDString,
            @"title": event.title.length > 0 ? event.title : @"无标题日程",
            @"time": time,
            @"startDate": event.startDate ?: start,
            @"allDay": @(event.allDay),
            @"calendarTitle": event.calendar.title ?: @"日历",
            @"color": color,
        }];
    }
    return [items sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        BOOL leftAllDay = [left[@"allDay"] boolValue];
        BOOL rightAllDay = [right[@"allDay"] boolValue];
        if (leftAllDay != rightAllDay) {
            return leftAllDay ? NSOrderedAscending : NSOrderedDescending;
        }
        return [left[@"startDate"] compare:right[@"startDate"]];
    }];
}

- (NSArray<NSDictionary *> *)todoItemsFromReminders:(NSArray<EKReminder *> *)reminders
                                             forDate:(NSDate *)date {
    NSCalendar *calendar = MCCalendar();
    NSDate *today = [calendar startOfDayForDate:[NSDate date]];
    NSMutableArray<NSDictionary *> *items = [[NSMutableArray alloc] init];

    for (EKReminder *reminder in reminders) {
        NSDateComponents *dateComponents = reminder.dueDateComponents ?: reminder.startDateComponents;
        NSDate *reminderDate = dateComponents ? [calendar dateFromComponents:dateComponents] : nil;
        BOOL belongsToDate = reminderDate
            ? [calendar isDate:reminderDate inSameDayAsDate:date]
            : (!reminder.completed && [calendar isDate:date inSameDayAsDate:today]);
        if (!belongsToDate) {
            continue;
        }

        NSString *time = @"";
        if (dateComponents
            && dateComponents.hour != NSDateComponentUndefined
            && dateComponents.minute != NSDateComponentUndefined) {
            time = [NSString stringWithFormat:@"%02ld:%02ld",
                (long)dateComponents.hour, (long)dateComponents.minute];
        }
        [items addObject:@{
            @"kind": @"todo",
            @"id": reminder.calendarItemIdentifier ?: @"",
            @"title": reminder.title.length > 0 ? reminder.title : @"无标题待办",
            @"done": @(reminder.completed),
            @"createdAt": reminder.creationDate ?: [NSDate distantPast],
            @"time": time,
            @"listTitle": reminder.calendar.title ?: @"提醒事项",
        }];
    }

    return [items sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        BOOL leftDone = [left[@"done"] boolValue];
        BOOL rightDone = [right[@"done"] boolValue];
        if (leftDone != rightDone) {
            return leftDone ? NSOrderedDescending : NSOrderedAscending;
        }
        NSString *leftTime = left[@"time"];
        NSString *rightTime = right[@"time"];
        if (leftTime.length != rightTime.length) {
            return leftTime.length > 0 ? NSOrderedAscending : NSOrderedDescending;
        }
        NSComparisonResult timeResult = [leftTime compare:rightTime];
        if (timeResult != NSOrderedSame) {
            return timeResult;
        }
        return [left[@"createdAt"] compare:right[@"createdAt"]];
    }];
}

- (void)addTodoWithTitle:(NSString *)title
                 forDate:(NSDate *)date
              completion:(void (^)(NSError * _Nullable error))completion {
    NSString *clean = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (clean.length == 0) {
        [self finishMutationWithError:nil completion:completion];
        return;
    }
    if (self.remindersAccessState != MCSystemAccessStateGranted) {
        [self finishMutationWithError:[self permissionError] completion:completion];
        return;
    }

    NSError *calendarError = nil;
    EKCalendar *list = [self writableMiniCalendarReminderList:&calendarError];
    if (!list) {
        [self finishMutationWithError:calendarError completion:completion];
        return;
    }

    EKReminder *reminder = [EKReminder reminderWithEventStore:self.eventStore];
    reminder.title = clean;
    reminder.calendar = list;
    reminder.dueDateComponents = [MCCalendar() components:
        NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];

    NSError *error = nil;
    [self.eventStore saveReminder:reminder commit:YES error:&error];
    [self finishMutationWithError:error completion:completion];
}

- (void)toggleTodoWithID:(NSString *)itemID
              completion:(void (^)(NSError * _Nullable error))completion {
    EKCalendarItem *item = [self.eventStore calendarItemWithIdentifier:itemID];
    if (![item isKindOfClass:EKReminder.class]) {
        [self finishMutationWithError:[self missingItemError] completion:completion];
        return;
    }
    EKReminder *reminder = (EKReminder *)item;
    reminder.completed = !reminder.completed;
    NSError *error = nil;
    [self.eventStore saveReminder:reminder commit:YES error:&error];
    [self finishMutationWithError:error completion:completion];
}

- (void)updateTodoWithID:(NSString *)itemID
                   title:(NSString *)title
              completion:(void (^)(NSError * _Nullable error))completion {
    NSString *clean = [title stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (clean.length == 0) {
        NSError *error = [NSError errorWithDomain:@"MiniCalendar"
                                             code:5
                                         userInfo:@{NSLocalizedDescriptionKey: @"Todo 内容不能为空"}];
        [self finishMutationWithError:error completion:completion];
        return;
    }
    if (self.remindersAccessState != MCSystemAccessStateGranted) {
        [self finishMutationWithError:[self permissionError] completion:completion];
        return;
    }
    EKCalendarItem *item = [self.eventStore calendarItemWithIdentifier:itemID];
    if (![item isKindOfClass:EKReminder.class]) {
        [self finishMutationWithError:[self missingItemError] completion:completion];
        return;
    }
    EKReminder *reminder = (EKReminder *)item;
    reminder.title = clean;
    NSError *error = nil;
    [self.eventStore saveReminder:reminder commit:YES error:&error];
    [self finishMutationWithError:error completion:completion];
}

- (void)deleteTodoWithID:(NSString *)itemID
              completion:(void (^)(NSError * _Nullable error))completion {
    EKCalendarItem *item = [self.eventStore calendarItemWithIdentifier:itemID];
    if (![item isKindOfClass:EKReminder.class]) {
        [self finishMutationWithError:[self missingItemError] completion:completion];
        return;
    }
    NSError *error = nil;
    [self.eventStore removeReminder:(EKReminder *)item commit:YES error:&error];
    [self finishMutationWithError:error completion:completion];
}

- (EKCalendar *)writableMiniCalendarReminderList:(NSError **)error {
    for (EKCalendar *calendar in [self.eventStore calendarsForEntityType:EKEntityTypeReminder]) {
        if ([calendar.title isEqualToString:@"极简日历"] && calendar.allowsContentModifications) {
            return calendar;
        }
    }

    EKCalendar *defaultList = self.eventStore.defaultCalendarForNewReminders;
    if (!defaultList) {
        if (error) {
            *error = [NSError errorWithDomain:@"MiniCalendar"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"没有可写入的系统提醒列表"}];
        }
        return nil;
    }

    EKCalendar *list = [EKCalendar calendarForEntityType:EKEntityTypeReminder
                                              eventStore:self.eventStore];
    list.title = @"极简日历";
    list.source = defaultList.source;
    NSError *saveError = nil;
    if ([self.eventStore saveCalendar:list commit:YES error:&saveError]) {
        return list;
    }

    // Some managed accounts don't allow creating lists, but still allow writing
    // to their default list.
    if (defaultList.allowsContentModifications) {
        return defaultList;
    }
    if (error) {
        *error = saveError;
    }
    return nil;
}

- (void)migrateLocalTodosIfNeededWithCompletion:(void (^)(void))completion {
    if (self.remindersAccessState != MCSystemAccessStateGranted
        || [self.defaults boolForKey:MCTodoMigrationKey]) {
        completion();
        return;
    }
    NSArray<NSDictionary *> *saved = [self.defaults arrayForKey:MCTodoStorageKey] ?: @[];
    if (saved.count == 0) {
        [self.defaults setBool:YES forKey:MCTodoMigrationKey];
        completion();
        return;
    }

    NSError *calendarError = nil;
    EKCalendar *list = [self writableMiniCalendarReminderList:&calendarError];
    if (!list) {
        NSLog(@"Unable to migrate local todos: %@", calendarError);
        completion();
        return;
    }

    NSError *saveError = nil;
    for (NSDictionary *item in saved) {
        NSDate *date = MCDateFromKey(item[@"dateKey"]);
        NSString *title = item[@"title"];
        if (!date || title.length == 0) {
            continue;
        }
        EKReminder *reminder = [EKReminder reminderWithEventStore:self.eventStore];
        reminder.title = title;
        reminder.calendar = list;
        reminder.dueDateComponents = [MCCalendar() components:
            NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
        reminder.completed = [item[@"done"] boolValue];
        if (![self.eventStore saveReminder:reminder commit:NO error:&saveError]) {
            break;
        }
    }
    BOOL committed = !saveError && [self.eventStore commit:&saveError];
    if (committed) {
        [self.defaults removeObjectForKey:MCTodoStorageKey];
        [self.defaults setBool:YES forKey:MCTodoMigrationKey];
    } else {
        [self.eventStore reset];
        NSLog(@"Unable to migrate local todos: %@", saveError);
    }
    completion();
}

- (void)finishMutationWithError:(NSError *)error
                     completion:(void (^)(NSError * _Nullable error))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) {
            completion(error);
        }
        if (!error) {
            [self notifyChange];
        }
    });
}

- (NSError *)permissionError {
    return [NSError errorWithDomain:@"MiniCalendar"
                               code:3
                           userInfo:@{
        NSLocalizedDescriptionKey: @"请在“系统设置 → 隐私与安全性 → 提醒事项”中允许访问"
    }];
}

- (NSError *)missingItemError {
    return [NSError errorWithDomain:@"MiniCalendar"
                               code:4
                           userInfo:@{NSLocalizedDescriptionKey: @"该提醒事项已被删除或不可修改"}];
}

- (void)eventStoreChanged:(NSNotification *)notification {
    (void)notification;
    [self notifyChange];
}

- (void)notifyChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.changeHandler) {
            self.changeHandler();
        }
    });
}

@end
