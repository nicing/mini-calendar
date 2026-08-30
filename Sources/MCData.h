#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *MCDateKey(NSDate *date);
FOUNDATION_EXPORT NSDate * _Nullable MCDateFromKey(NSString *key);
FOUNDATION_EXPORT NSCalendar *MCCalendar(void);
FOUNDATION_EXPORT NSColor *MCAccentColor(void);

typedef NS_ENUM(NSInteger, MCHolidayKind) {
    MCHolidayKindFestival,
    MCHolidayKindDayOff,
    MCHolidayKindMakeUpWork,
};

@interface MCHoliday : NSObject

@property(nonatomic, copy, readonly) NSString *label;
@property(nonatomic, readonly) MCHolidayKind kind;

- (instancetype)initWithLabel:(NSString *)label kind:(MCHolidayKind)kind;

@end

@interface MCHolidayService : NSObject

- (nullable MCHoliday *)holidayForDate:(NSDate *)date;
- (nullable MCHoliday *)nextFestivalOnOrAfterDate:(NSDate *)date
                                      festivalDate:(NSDate * _Nullable * _Nullable)festivalDate;

@end

@interface MCLunarService : NSObject

- (NSString *)shortTextForDate:(NSDate *)date;
- (NSString *)longTextForDate:(NSDate *)date;

@end

@interface MCTodoStore : NSObject

@property(nonatomic, copy, readonly) NSArray<NSDictionary *> *allItems;

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
- (NSArray<NSDictionary *> *)itemsForDate:(NSDate *)date;
- (void)addTitle:(NSString *)title forDate:(NSDate *)date;
- (void)updateItemWithID:(NSString *)itemID title:(NSString *)title;
- (void)toggleItemWithID:(NSString *)itemID;
- (void)deleteItemWithID:(NSString *)itemID;

@end

typedef NS_ENUM(NSInteger, MCSystemAccessState) {
    MCSystemAccessStateUnknown,
    MCSystemAccessStateDenied,
    MCSystemAccessStateGranted,
};

typedef void (^MCSystemAgendaCompletion)(
    NSArray<NSDictionary *> *todos,
    NSArray<NSDictionary *> *events
);

@interface MCSystemDataStore : NSObject

@property(nonatomic, readonly) MCSystemAccessState remindersAccessState;
@property(nonatomic, readonly) MCSystemAccessState calendarAccessState;
@property(nonatomic, copy, nullable) void (^changeHandler)(void);

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
- (void)requestAccessWithCompletion:(void (^)(void))completion;
- (void)loadAgendaForDate:(NSDate *)date completion:(MCSystemAgendaCompletion)completion;
- (void)addTodoWithTitle:(NSString *)title
                 forDate:(NSDate *)date
              completion:(void (^)(NSError * _Nullable error))completion;
- (void)updateTodoWithID:(NSString *)itemID
                   title:(NSString *)title
              completion:(void (^)(NSError * _Nullable error))completion;
- (void)toggleTodoWithID:(NSString *)itemID
              completion:(void (^)(NSError * _Nullable error))completion;
- (void)deleteTodoWithID:(NSString *)itemID
              completion:(void (^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
