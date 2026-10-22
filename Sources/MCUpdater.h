#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

BOOL MCUpdateAssetIsValid(NSDictionary *asset, NSString *tag);
int MCInstallUpdate(NSArray<NSString *> *arguments);
int MCRunUpdaterTests(void);
int MCRunUpdateDownloadTest(void);

@interface MCUpdater : NSObject <NSURLSessionDownloadDelegate>

@property(nonatomic, readonly) BOOL ready;
@property(nonatomic, copy, nullable) void (^progressHandler)(double fraction, NSString *status);
@property(nonatomic, copy, nullable) void (^completionHandler)(NSError * _Nullable error);

- (instancetype)initWithAsset:(NSDictionary *)asset version:(NSString *)version;
- (void)start;
- (void)cancel;
- (BOOL)restartToInstallAtURL:(NSURL *)target error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
