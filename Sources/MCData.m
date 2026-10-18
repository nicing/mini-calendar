#import <AppKit/AppKit.h>
#import <EventKit/EventKit.h>
#import "MCData.h"

NSNotificationName const MCAccentColorDidChangeNotification =
    @"MCAccentColorDidChangeNotification";

static NSString * const MCAccentColorDefaultsKey = @"MiniCalendarAccentColor";
static NSString * const MCDefaultAccentColorIdentifier = @"red";

static NSArray<NSDictionary<NSString *, id> *> *MCAccentPalette(void) {
    static NSArray<NSDictionary<NSString *, id> *> *palette;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        palette = @[
            @{ @"id": @"red", @"name": @"红色",
               @"color": [NSColor colorWithSRGBRed:0.910 green:0.345 blue:0.353 alpha:1.0] },
            @{ @"id": @"blue", @"name": @"蓝色",
               @"color": [NSColor colorWithSRGBRed:0.18 green:0.49 blue:0.97 alpha:1.0] },
            @{ @"id": @"cyan", @"name": @"青色",
               @"color": [NSColor colorWithSRGBRed:0.04 green:0.59 blue:0.71 alpha:1.0] },
            @{ @"id": @"teal", @"name": @"蓝绿色",
               @"color": [NSColor colorWithSRGBRed:0.03 green:0.61 blue:0.55 alpha:1.0] },
            @{ @"id": @"green", @"name": @"绿色",
               @"color": [NSColor colorWithSRGBRed:0.03 green:0.62 blue:0.40 alpha:1.0] },
            @{ @"id": @"yellow", @"name": @"黄色",
               @"color": [NSColor colorWithSRGBRed:0.96 green:0.71 blue:0.00 alpha:1.0],
               @"darkForeground": @YES },
            @{ @"id": @"orange", @"name": @"橙色",
               @"color": [NSColor colorWithSRGBRed:1.00 green:0.38 blue:0.02 alpha:1.0],
               @"darkForeground": @YES },
            @{ @"id": @"pink", @"name": @"粉色",
               @"color": [NSColor colorWithSRGBRed:0.94 green:0.16 blue:0.55 alpha:1.0] },
            @{ @"id": @"purple", @"name": @"紫色",
               @"color": [NSColor colorWithSRGBRed:0.56 green:0.00 blue:0.62 alpha:1.0] },
            @{ @"id": @"violet", @"name": @"亮紫色",
               @"color": [NSColor colorWithSRGBRed:0.43 green:0.00 blue:0.91 alpha:1.0] },
            @{ @"id": @"gray", @"name": @"灰色",
               @"color": [NSColor colorWithSRGBRed:0.34 green:0.35 blue:0.39 alpha:1.0] },
        ];
    });
    return palette;
}

static NSDictionary<NSString *, id> *MCAccentOption(NSString *identifier) {
    for (NSDictionary<NSString *, id> *option in MCAccentPalette()) {
        if ([option[@"id"] isEqualToString:identifier]) {
            return option;
        }
    }
    return MCAccentPalette().firstObject;
}

NSCalendar *MCCalendar(void) {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.locale = [NSLocale localeWithLocaleIdentifier:@"zh_Hans_CN"];
    calendar.timeZone = NSTimeZone.localTimeZone;
    calendar.firstWeekday = 2;
    return calendar;
}

NSArray<NSString *> *MCAccentColorIdentifiers(void) {
    static NSArray<NSString *> *identifiers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray<NSString *> *values = [NSMutableArray array];
        for (NSDictionary<NSString *, id> *option in MCAccentPalette()) {
            [values addObject:option[@"id"]];
        }
        identifiers = values.copy;
    });
    return identifiers;
}

NSString *MCAccentColorIdentifier(void) {
    NSString *identifier = [NSUserDefaults.standardUserDefaults
        stringForKey:MCAccentColorDefaultsKey
    ];
    return [MCAccentColorIdentifiers() containsObject:identifier]
        ? identifier
        : MCDefaultAccentColorIdentifier;
}

NSString *MCAccentColorName(NSString *identifier) {
    return MCAccentOption(identifier)[@"name"];
}

NSColor *MCAccentColorForIdentifier(NSString *identifier) {
    return MCAccentOption(identifier)[@"color"];
}

void MCSetAccentColorIdentifier(NSString *identifier) {
    if (![MCAccentColorIdentifiers() containsObject:identifier]
        || [MCAccentColorIdentifier() isEqualToString:identifier]) {
        return;
    }
    [NSUserDefaults.standardUserDefaults setObject:identifier
                                            forKey:MCAccentColorDefaultsKey];
    [NSNotificationCenter.defaultCenter
        postNotificationName:MCAccentColorDidChangeNotification
                      object:identifier];
}

NSColor *MCAccentColor(void) {
    return MCAccentColorForIdentifier(MCAccentColorIdentifier());
}

NSColor *MCAccentForegroundColor(void) {
    NSDictionary<NSString *, id> *option = MCAccentOption(MCAccentColorIdentifier());
    return [option[@"darkForeground"] boolValue]
        ? [NSColor colorWithWhite:0.06 alpha:0.92]
        : NSColor.whiteColor;
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
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *recurringYears;
@property(nonatomic, strong) NSDictionary<NSString *, NSNumber *> *qingmingDays;
@property(nonatomic, strong) NSURL *cacheURL;
@property(nonatomic, strong) NSDictionary *updateDocument;
@property(nonatomic, strong) NSDate *lastRefreshAttempt;
@property(nonatomic) BOOL refreshing;
@property(nonatomic) BOOL hasValidCache;

- (BOOL)applyUpdateData:(NSData *)data;

@end

@implementation MCHolidayService

- (instancetype)init {
    NSURL *support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                         inDomains:NSUserDomainMask].firstObject;
    NSURL *cacheURL = [[support URLByAppendingPathComponent:@"MiniCalendar" isDirectory:YES]
        URLByAppendingPathComponent:@"holidays.json"];
    return [self initWithCacheURL:cacheURL];
}

- (instancetype)initWithCacheURL:(NSURL *)cacheURL {
    self = [super init];
    if (self) {
        _records = [[NSMutableDictionary alloc] init];
        _recurringYears = [[NSMutableDictionary alloc] init];
        _cacheURL = cacheURL;
        NSURL *qingmingURL = [NSBundle.mainBundle URLForResource:@"qingming" withExtension:@"json"];
        NSData *qingmingData = qingmingURL ? [NSData dataWithContentsOfURL:qingmingURL] : nil;
        _qingmingDays = qingmingData
            ? [NSJSONSerialization JSONObjectWithData:qingmingData options:0 error:nil][@"days"] : @{};
        NSURL *bundledURL = [NSBundle.mainBundle URLForResource:@"holidays" withExtension:@"json"];
        NSData *bundled = bundledURL ? [NSData dataWithContentsOfURL:bundledURL] : nil;
        if (bundled) [self applyUpdateData:bundled];
        NSData *cached = cacheURL ? [NSData dataWithContentsOfURL:cacheURL] : nil;
        if (cached) {
            BOOL applied = [self applyUpdateData:cached];
            id cachedDocument = cached.length <= 512 * 1024
                ? [NSJSONSerialization JSONObjectWithData:cached options:0 error:nil] : nil;
            _hasValidCache = applied || [cachedDocument isEqual:_updateDocument];
        }
    }
    return self;
}

- (MCHoliday *)holidayForDate:(NSDate *)date {
    NSString *key = MCDateKey(date);
    if (self.records[key]) return self.records[key];
    NSString *year = [key substringToIndex:4];
    if (!self.recurringYears[year]) [self loadRecurringYear:year.integerValue];
    return self.recurringYears[year][key];
}

- (void)loadRecurringYear:(NSInteger)year {
    // Use Chinese civil dates (UTC+8), independently of the Mac's current time zone.
    NSCalendar *solar = MCCalendar();
    solar.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
    NSCalendar *lunar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierChinese];
    lunar.timeZone = solar.timeZone;
    NSString *yearKey = [NSString stringWithFormat:@"%04ld", (long)year];
    NSMutableDictionary *days = [NSMutableDictionary dictionary];
    void (^add)(NSString *, NSString *) = ^(NSString *key, NSString *label) {
        MCHoliday *existing = days[key];
        NSString *name = existing ? [existing.label stringByAppendingFormat:@"·%@", label] : label;
        days[key] = [[MCHoliday alloc] initWithLabel:name kind:MCHolidayKindFestival];
    };
    add([yearKey stringByAppendingString:@"-01-01"], @"元旦");
    add([yearKey stringByAppendingString:@"-05-01"], @"劳动节");
    add([yearKey stringByAppendingString:@"-10-01"], @"国庆");
    NSInteger qingmingDay = self.qingmingDays[yearKey].integerValue;
    if (qingmingDay >= 4 && qingmingDay <= 6) {
        add([yearKey stringByAppendingFormat:@"-04-%02ld", (long)qingmingDay], @"清明");
    }
    NSDateComponents *start = [[NSDateComponents alloc] init];
    start.year = year;
    start.month = 1;
    start.day = 1;
    start.hour = 12;
    NSDate *day = [solar dateFromComponents:start];
    while (day && [solar component:NSCalendarUnitYear fromDate:day] == year) {
        NSDateComponents *parts = [lunar components:NSCalendarUnitMonth | NSCalendarUnitDay fromDate:day];
        NSDateComponents *civil = [solar components:NSCalendarUnitMonth | NSCalendarUnitDay fromDate:day];
        NSString *key = [yearKey stringByAppendingFormat:@"-%02ld-%02ld", (long)civil.month, (long)civil.day];
        if (!parts.isLeapMonth) {
            if (parts.month == 1 && parts.day == 1) {
                add(key, @"春节");
                NSDate *eve = [solar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:day options:0];
                NSDateComponents *eveParts = [solar components:NSCalendarUnitMonth | NSCalendarUnitDay fromDate:eve];
                add([yearKey stringByAppendingFormat:@"-%02ld-%02ld", (long)eveParts.month, (long)eveParts.day], @"除夕");
            } else if (parts.month == 5 && parts.day == 5) {
                add(key, @"端午");
            } else if (parts.month == 8 && parts.day == 15) {
                add(key, @"中秋");
            }
        }
        day = [solar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:day options:0];
    }
    self.recurringYears[yearKey] = days.copy;
}

- (BOOL)applyUpdateData:(NSData *)data {
    if (data.length == 0 || data.length > 512 * 1024) return NO;
    id document = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![document isKindOfClass:NSDictionary.class]) return NO;
    NSNumber *schema = document[@"schemaVersion"];
    NSNumber *revision = document[@"revision"];
    NSDictionary *years = document[@"years"];
    if (![schema isKindOfClass:NSNumber.class] || schema.doubleValue != 1
        || CFGetTypeID((__bridge CFTypeRef)schema) == CFBooleanGetTypeID()
        || ![revision isKindOfClass:NSNumber.class] || revision.longLongValue < 1
        || revision.doubleValue != revision.longLongValue
        || CFGetTypeID((__bridge CFTypeRef)revision) == CFBooleanGetTypeID()
        || ![years isKindOfClass:NSDictionary.class] || years.count == 0 || years.count > 200) return NO;
    NSMutableDictionary *validated = [NSMutableDictionary dictionary];
    for (NSString *year in years) {
        if (![year isKindOfClass:NSString.class] || year.length != 4
            || year.integerValue < 1901 || year.integerValue > 2199) return NO;
        id entry = years[year];
        if (![entry isKindOfClass:NSDictionary.class]) return NO;
        NSString *source = entry[@"source"];
        NSDictionary *days = entry[@"days"];
        NSURL *sourceURL = [source isKindOfClass:NSString.class] ? [NSURL URLWithString:source] : nil;
        if (![sourceURL.scheme isEqualToString:@"https"]
            || !([sourceURL.host isEqualToString:@"gov.cn"] || [sourceURL.host hasSuffix:@".gov.cn"])
            || ![days isKindOfClass:NSDictionary.class] || days.count == 0 || days.count > 366) return NO;
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        for (NSString *key in days) {
            if (![key isKindOfClass:NSString.class] || key.length != 10
                || ![key hasPrefix:[year stringByAppendingString:@"-"]]) return NO;
            NSDate *date = MCDateFromKey(key);
            if (!date || ![MCDateKey(date) isEqualToString:key]) return NO;
            id value = days[key];
            if (![value isKindOfClass:NSDictionary.class]) return NO;
            NSString *label = value[@"label"];
            NSString *kind = value[@"kind"];
            if (![label isKindOfClass:NSString.class] || label.length == 0 || label.length > 12
                || [label rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound
                || ![@[@"festival", @"dayOff", @"workday"] containsObject:kind ?: NSNull.null]) return NO;
            MCHolidayKind holidayKind = [kind isEqualToString:@"festival"] ? MCHolidayKindFestival
                : [kind isEqualToString:@"dayOff"] ? MCHolidayKindDayOff : MCHolidayKindMakeUpWork;
            records[key] = [[MCHoliday alloc] initWithLabel:label kind:holidayKind];
        }
        validated[year] = records;
    }
    if (revision.longLongValue <= [self.updateDocument[@"revision"] longLongValue]) return NO;
    for (NSString *year in validated) {
        for (NSString *key in self.records.allKeys) {
            if ([key hasPrefix:[year stringByAppendingString:@"-"]]) [self.records removeObjectForKey:key];
        }
        [self.records addEntriesFromDictionary:validated[year]];
    }
    NSMutableDictionary *mergedYears = [self.updateDocument[@"years"] mutableCopy] ?: [NSMutableDictionary dictionary];
    [mergedYears addEntriesFromDictionary:years];
    self.updateDocument = @{@"schemaVersion": @1, @"revision": revision, @"years": mergedYears};
    return YES;
}

- (void)refreshIfNeededWithCompletion:(void (^)(BOOL))completion {
    if (self.refreshing || (self.lastRefreshAttempt && -self.lastRefreshAttempt.timeIntervalSinceNow < 3600)) {
        completion(NO);
        return;
    }
    NSDate *lastSuccess = self.cacheURL ? [NSFileManager.defaultManager
        attributesOfItemAtPath:self.cacheURL.path error:nil][NSFileModificationDate] : nil;
    if (self.hasValidCache && lastSuccess && -lastSuccess.timeIntervalSinceNow < 24 * 60 * 60) {
        completion(NO);
        return;
    }
    self.refreshing = YES;
    self.lastRefreshAttempt = NSDate.date;
    NSURL *URL = [NSURL URLWithString:@"https://raw.githubusercontent.com/nicing/mini-calendar/main/Data/holidays.json"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL
        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:
        ^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.refreshing = NO;
            BOOL changed = NO;
            if (!error && [(NSHTTPURLResponse *)response statusCode] == 200) {
                changed = [self applyUpdateData:data];
                id received = data.length <= 512 * 1024
                    ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
                // Write only the validated active snapshot. Invalid responses never replace the cache.
                if (self.cacheURL && (changed || [received isEqual:self.updateDocument])) {
                    [NSFileManager.defaultManager createDirectoryAtURL:self.cacheURL.URLByDeletingLastPathComponent
                                          withIntermediateDirectories:YES attributes:nil error:nil];
                    NSData *snapshot = [NSJSONSerialization dataWithJSONObject:self.updateDocument options:0 error:nil];
                    self.hasValidCache = [snapshot writeToURL:self.cacheURL options:NSDataWritingAtomic error:nil];
                }
            }
            completion(changed);
        });
    }] resume];
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
    BOOL viewingToday = [calendar isDate:date inSameDayAsDate:today];

    for (EKReminder *reminder in reminders) {
        NSDateComponents *dateComponents = reminder.dueDateComponents ?: reminder.startDateComponents;
        NSDate *reminderDate = dateComponents ? [calendar dateFromComponents:dateComponents] : nil;
        NSDate *reminderDay = reminderDate ? [calendar startOfDayForDate:reminderDate] : nil;
        BOOL overdue = !reminder.completed
            && reminderDay
            && [reminderDay compare:today] == NSOrderedAscending;
        BOOL belongsToDate = reminderDate
            ? ([calendar isDate:reminderDate inSameDayAsDate:date]
               || (viewingToday && overdue))
            : (!reminder.completed && viewingToday);
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
            @"overdue": @(overdue),
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
        BOOL leftOverdue = [left[@"overdue"] boolValue];
        BOOL rightOverdue = [right[@"overdue"] boolValue];
        if (leftOverdue != rightOverdue) {
            return leftOverdue ? NSOrderedAscending : NSOrderedDescending;
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
