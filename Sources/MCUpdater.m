#import "MCUpdater.h"
#import <CommonCrypto/CommonDigest.h>
#import <signal.h>
#import <unistd.h>

static NSString * const MCUpdateBundleID = @"com.lizhenyang.minicalendar";
static const long long MCMaximumUpdateSize = 200 * 1024 * 1024;

static NSError *MCUpdateError(NSString *message) {
    return [NSError errorWithDomain:@"MiniCalendarUpdater" code:1
                          userInfo:@{NSLocalizedDescriptionKey: message}];
}

static BOOL MCRunUpdateTool(NSString *path, NSArray<NSString *> *arguments) {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:path];
    task.arguments = arguments;
    task.standardOutput = NSFileHandle.fileHandleWithNullDevice;
    task.standardError = NSFileHandle.fileHandleWithNullDevice;
    if (![task launchAndReturnError:nil]) return NO;
    [task waitUntilExit];
    return task.terminationStatus == 0;
}

static NSDictionary *MCUpdateInfo(NSURL *app) {
    return [NSDictionary dictionaryWithContentsOfURL:
        [app URLByAppendingPathComponent:@"Contents/Info.plist"]];
}

static BOOL MCValidateUpdateApp(NSURL *app, NSString *version) {
    NSDictionary *info = MCUpdateInfo(app);
    if (![info[@"CFBundleIdentifier"] isEqualToString:MCUpdateBundleID]
        || ![info[@"CFBundleShortVersionString"] isEqualToString:version]
        || ![info[@"CFBundleExecutable"] isEqualToString:@"MiniCalendar"]
        || ![NSFileManager.defaultManager isExecutableFileAtPath:
            [app URLByAppendingPathComponent:@"Contents/MacOS/MiniCalendar"].path]) return NO;
    NSString *minimum = info[@"LSMinimumSystemVersion"];
    if ([minimum isKindOfClass:NSString.class]) {
        NSArray *parts = [minimum componentsSeparatedByString:@"."];
        NSOperatingSystemVersion required = {0, 0, 0};
        if (parts.count > 0) required.majorVersion = [parts[0] integerValue];
        if (parts.count > 1) required.minorVersion = [parts[1] integerValue];
        if (parts.count > 2) required.patchVersion = [parts[2] integerValue];
        if (![NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:required]) return NO;
    }
    return MCRunUpdateTool(@"/usr/bin/codesign", @[@"--verify", @"--deep", @"--strict", app.path]);
}

BOOL MCUpdateAssetIsValid(NSDictionary *asset, NSString *tag) {
    if (![asset isKindOfClass:NSDictionary.class] || ![tag isKindOfClass:NSString.class]) return NO;
    NSString *name = asset[@"name"];
    NSString *address = asset[@"browser_download_url"];
    NSString *digest = asset[@"digest"];
    NSNumber *size = asset[@"size"];
    if (![name isKindOfClass:NSString.class] || ![name hasSuffix:@".dmg"]
        || ![address isKindOfClass:NSString.class] || ![digest isKindOfClass:NSString.class]
        || ![size isKindOfClass:NSNumber.class] || size.longLongValue <= 0
        || size.longLongValue > MCMaximumUpdateSize || digest.length != 71
        || ![digest hasPrefix:@"sha256:"]) return NO;
    NSCharacterSet *notHex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"].invertedSet;
    if ([[digest substringFromIndex:7] rangeOfCharacterFromSet:notHex].location != NSNotFound) return NO;
    NSURL *URL = [NSURL URLWithString:address];
    NSString *prefix = [NSString stringWithFormat:@"/nicing/mini-calendar/releases/download/%@/", tag];
    return [URL.scheme isEqualToString:@"https"] && [URL.host isEqualToString:@"github.com"]
        && URL.user == nil && URL.password == nil && URL.query == nil && URL.fragment == nil
        && [URL.path isEqualToString:[prefix stringByAppendingString:name]];
}

static BOOL MCUpdateDigestMatches(NSURL *file, NSString *expected) {
    NSInputStream *stream = [NSInputStream inputStreamWithURL:file];
    [stream open];
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    uint8_t buffer[64 * 1024];
    NSInteger count;
    while ((count = [stream read:buffer maxLength:sizeof(buffer)]) > 0) {
        CC_SHA256_Update(&context, buffer, (CC_LONG)count);
    }
    [stream close];
    if (count < 0) return NO;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    NSMutableString *hex = [NSMutableString stringWithString:@"sha256:"];
    for (NSUInteger i = 0; i < sizeof(digest); i++) [hex appendFormat:@"%02x", digest[i]];
    return [hex isEqualToString:expected];
}

static BOOL MCCanInstallUpdate(NSURL *target) {
    NSString *path = target.URLByResolvingSymlinksInPath.path;
    NSNumber *readOnly = nil;
    [target getResourceValue:&readOnly forKey:NSURLVolumeIsReadOnlyKey error:nil];
    return [target.path isEqualToString:path] && [path.pathExtension isEqualToString:@"app"]
        && ![path hasPrefix:@"/Volumes/"] && ![path containsString:@"/AppTranslocation/"]
        && !readOnly.boolValue
        && [NSFileManager.defaultManager isWritableFileAtPath:target.URLByDeletingLastPathComponent.path]
        && [MCUpdateInfo(target)[@"CFBundleIdentifier"] isEqualToString:MCUpdateBundleID];
}

// Copy first, then exchange names on the same volume. Keep the original until launch succeeds.
static BOOL MCReplaceUpdate(NSURL *source, NSURL *target, NSString *version, BOOL launch, NSError **error) {
    NSFileManager *files = NSFileManager.defaultManager;
    if (!MCCanInstallUpdate(target) || !MCValidateUpdateApp(source, version)) {
        if (error) *error = MCUpdateError(@"无法替换此位置的 App。请将极简日历移至“应用程序”或用户的“应用程序”文件夹后重试。");
        return NO;
    }
    NSURL *parent = target.URLByDeletingLastPathComponent;
    NSString *identifier = NSUUID.UUID.UUIDString;
    NSURL *staged = [parent URLByAppendingPathComponent:[NSString stringWithFormat:@".MiniCalendar-%@.app", identifier]];
    NSURL *backup = [parent URLByAppendingPathComponent:[NSString stringWithFormat:@".MiniCalendar-backup-%@.app", identifier]];
    if (!MCRunUpdateTool(@"/usr/bin/ditto", @[@"--noextattr", @"--noacl", source.path, staged.path])
        || !MCValidateUpdateApp(staged, version)) {
        [files removeItemAtURL:staged error:nil];
        if (error) *error = MCUpdateError(@"准备安装失败，旧版本未改动。请检查磁盘空间后重试。");
        return NO;
    }
    if (![files moveItemAtURL:target toURL:backup error:error]) {
        [files removeItemAtURL:staged error:nil];
        return NO;
    }
    BOOL installed = [files moveItemAtURL:staged toURL:target error:error];
    BOOL opened = installed && (!launch || MCRunUpdateTool(@"/usr/bin/open", @[@"-n", target.path]));
    if (!opened) {
        // Only remove the new bundle if the old one can be restored at the original path.
        if (installed) [files moveItemAtURL:target toURL:staged error:nil];
        BOOL restored = [files moveItemAtURL:backup toURL:target error:nil];
        if (restored && launch) MCRunUpdateTool(@"/usr/bin/open", @[@"-n", target.path]);
        [files removeItemAtURL:staged error:nil];
        if (error && !*error) *error = MCUpdateError(restored ? @"安装失败，已恢复旧版本。" : @"安装失败，原版本保留在同目录的 MiniCalendar-backup 文件中。");
        return NO;
    }
    [files removeItemAtURL:backup error:nil];
    return YES;
}

@interface MCUpdater ()
@property(nonatomic, copy) NSDictionary *asset;
@property(nonatomic, copy) NSString *version;
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, strong) NSURLSessionDownloadTask *task;
@property(nonatomic, strong) NSURL *workDirectory;
@property(nonatomic, strong) NSURL *preparedApp;
@property(nonatomic) BOOL ready;
@property(nonatomic) BOOL preparing;
@property(nonatomic) BOOL cancelled;
@property(nonatomic) BOOL handedOff;
@end

@implementation MCUpdater

- (instancetype)initWithAsset:(NSDictionary *)asset version:(NSString *)version {
    self = [super init];
    if (self) { _asset = asset.copy; _version = version.copy; }
    return self;
}

- (void)dealloc {
    if (!self.handedOff && self.workDirectory) [NSFileManager.defaultManager removeItemAtURL:self.workDirectory error:nil];
}

- (void)finish:(NSError *)error {
    [self.session finishTasksAndInvalidate];
    self.session = nil;
    self.task = nil;
    void (^completion)(NSError *) = self.completionHandler;
    self.completionHandler = nil;
    if (completion) completion(error);
}

- (void)start {
    if (self.session || self.ready) return;
    NSString *address = self.asset[@"browser_download_url"];
    NSURL *downloadURL = [address isKindOfClass:NSString.class] ? [NSURL URLWithString:address] : nil;
    NSString *tag = downloadURL.URLByDeletingLastPathComponent.lastPathComponent;
    if (!MCUpdateAssetIsValid(self.asset, tag)) {
        [self finish:MCUpdateError(@"更新地址或校验信息无效，请重新检查更新。")];
        return;
    }
    self.workDirectory = [NSURL fileURLWithPath:[NSTemporaryDirectory()
        stringByAppendingPathComponent:[@"MiniCalendarUpdate-" stringByAppendingString:NSUUID.UUID.UUIDString]]];
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtURL:self.workDirectory withIntermediateDirectories:NO
        attributes:@{NSFilePosixPermissions: @0700} error:&error]) { [self finish:error]; return; }
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.timeoutIntervalForRequest = 30;
    configuration.timeoutIntervalForResource = 10 * 60;
    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:NSOperationQueue.mainQueue];
    self.task = [self.session downloadTaskWithURL:downloadURL];
    [self.task resume];
}

- (void)cancel {
    self.cancelled = YES;
    [self.task cancel];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
    completionHandler:(void (^)(NSURLRequest *))completionHandler {
    NSString *host = request.URL.host;
    BOOL valid = [request.URL.scheme isEqualToString:@"https"]
        && ([@[@"github.com", @"release-assets.githubusercontent.com", @"objects.githubusercontent.com"] containsObject:host]);
    completionHandler(valid ? request : nil);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task
    didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)written
    totalBytesExpectedToWrite:(int64_t)expected {
    if (written > MCMaximumUpdateSize) { [task cancel]; return; }
    if (self.progressHandler) self.progressHandler(MIN(1.0, (double)written / [self.asset[@"size"] doubleValue]), @"正在下载安装包…");
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task
    didFinishDownloadingToURL:(NSURL *)location {
    if (self.cancelled) {
        [self finish:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
        return;
    }
    NSError *error = nil;
    NSURL *dmg = [self.workDirectory URLByAppendingPathComponent:@"Update.dmg"];
    NSNumber *size = nil;
    [location getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    if ([(NSHTTPURLResponse *)task.response statusCode] != 200
        || size.longLongValue != [self.asset[@"size"] longLongValue]
        || ![NSFileManager.defaultManager moveItemAtURL:location toURL:dmg error:&error]) {
        [self finish:error ?: MCUpdateError(@"安装包下载不完整，请重试。")];
        return;
    }
    self.preparing = YES;
    if (self.progressHandler) self.progressHandler(1, @"下载完成，正在验证安装包…");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *preparationError = nil;
        NSURL *prepared = [self prepareDMG:dmg error:&preparationError];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.preparing = NO;
            if (self.cancelled) { [self finish:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]]; return; }
            self.preparedApp = prepared;
            self.ready = prepared != nil;
            [self finish:preparationError];
        });
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error && !self.preparing) [self finish:error];
}

- (NSURL *)prepareDMG:(NSURL *)dmg error:(NSError **)error {
    if (!MCUpdateDigestMatches(dmg, self.asset[@"digest"])
        || !MCRunUpdateTool(@"/usr/bin/hdiutil", @[@"verify", dmg.path])) {
        *error = MCUpdateError(@"安装包校验失败，已停止安装。请重新下载。");
        return nil;
    }
    NSURL *mount = [self.workDirectory URLByAppendingPathComponent:@"Volume"];
    [NSFileManager.defaultManager createDirectoryAtURL:mount withIntermediateDirectories:NO attributes:nil error:nil];
    BOOL mounted = MCRunUpdateTool(@"/usr/bin/hdiutil", @[@"attach", @"-readonly", @"-nobrowse", @"-mountpoint", mount.path, dmg.path]);
    if (!mounted) { *error = MCUpdateError(@"无法打开安装包，请重试。"); return nil; }
    NSURL *candidate = [mount URLByAppendingPathComponent:@"极简日历.app"];
    NSURL *prepared = [self.workDirectory URLByAppendingPathComponent:@"MiniCalendar.app"];
    BOOL valid = MCValidateUpdateApp(candidate, self.version)
        && MCRunUpdateTool(@"/usr/bin/ditto", @[@"--noextattr", @"--noacl", candidate.path, prepared.path])
        && MCValidateUpdateApp(prepared, self.version);
    BOOL detached = MCRunUpdateTool(@"/usr/bin/hdiutil", @[@"detach", mount.path]);
    if (!detached) MCRunUpdateTool(@"/usr/bin/hdiutil", @[@"detach", @"-force", mount.path]);
    if (!valid) { *error = MCUpdateError(@"新版本的应用校验失败，或不支持当前 macOS。旧版本未改动。"); return nil; }
    [NSFileManager.defaultManager removeItemAtURL:dmg error:nil];
    return prepared;
}

- (BOOL)restartToInstallAtURL:(NSURL *)target error:(NSError **)error {
    if (!self.ready || !MCCanInstallUpdate(target)) {
        if (error) *error = MCUpdateError(@"此位置无法自动安装。请先将极简日历移至可写的“应用程序”文件夹，再重试。");
        return NO;
    }
    NSURL *helper = [self.workDirectory URLByAppendingPathComponent:@"Installer"];
    [NSFileManager.defaultManager removeItemAtURL:helper error:nil];
    if (![NSFileManager.defaultManager copyItemAtURL:NSBundle.mainBundle.executableURL toURL:helper error:error]) return NO;
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = helper;
    task.arguments = @[@"--install-update", self.preparedApp.path, target.path, self.version,
        [NSString stringWithFormat:@"%d", getpid()]];
    task.standardOutput = NSFileHandle.fileHandleWithNullDevice;
    task.standardError = NSFileHandle.fileHandleWithNullDevice;
    if (![task launchAndReturnError:error]) {
        [NSFileManager.defaultManager removeItemAtURL:helper error:nil];
        return NO;
    }
    self.handedOff = YES;
    return YES;
}

@end

int MCInstallUpdate(NSArray<NSString *> *arguments) {
    if (arguments.count != 6) return 1;
    NSURL *source = [NSURL fileURLWithPath:arguments[2]];
    NSURL *target = [NSURL fileURLWithPath:arguments[3]];
    pid_t parent = (pid_t)[arguments[5] intValue];
    if (parent <= 1) return 1;
    // The helper lives outside the bundle being replaced and waits for the App to exit.
    for (NSInteger attempt = 0; attempt < 1200 && kill(parent, 0) == 0; attempt++) usleep(100000);
    if (kill(parent, 0) == 0) return 1;
    NSError *error = nil;
    BOOL installed = MCReplaceUpdate(source, target, arguments[4], YES, &error);
    if (!installed) {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"未能完成更新";
        alert.informativeText = error.localizedDescription ?: @"旧版本仍可继续使用，请重试。";
        [alert addButtonWithTitle:@"好"];
        [NSApp activateIgnoringOtherApps:YES];
        [alert runModal];
    }
    NSURL *work = source.URLByDeletingLastPathComponent;
    if (installed && [work.lastPathComponent hasPrefix:@"MiniCalendarUpdate-"]
        && [NSBundle.mainBundle.executablePath isEqualToString:[work URLByAppendingPathComponent:@"Installer"].path]) {
        [NSFileManager.defaultManager removeItemAtURL:work error:nil];
    }
    return installed ? 0 : 1;
}

int MCRunUpdaterTests(void) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
        [@"MiniCalendarInstallTest-" stringByAppendingString:NSUUID.UUID.UUIDString]]];
    [files createDirectoryAtURL:root withIntermediateDirectories:NO attributes:nil error:nil];
    NSURL *source = [root URLByAppendingPathComponent:@"Source.app"];
    NSURL *target = [root URLByAppendingPathComponent:@"Target.app"];
    BOOL copied = [files copyItemAtURL:NSBundle.mainBundle.bundleURL toURL:source error:nil]
        && [files copyItemAtURL:NSBundle.mainBundle.bundleURL toURL:target error:nil];
    NSString *version = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
    NSURL *marker = [target URLByAppendingPathComponent:@"previous-version-marker"];
    [@"old" writeToURL:marker atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSError *error = nil;
    BOOL replaced = copied && MCReplaceUpdate(source, target, version, NO, &error)
        && ![files fileExistsAtPath:marker.path] && MCValidateUpdateApp(target, version);
    BOOL invalidRejected = !MCReplaceUpdate(source, target, @"999.0.0", NO, &error)
        && MCValidateUpdateApp(target, version);
    NSURL *tampered = [source URLByAppendingPathComponent:@"Contents/Resources/holidays.json"];
    [@"tampered" writeToURL:tampered atomically:YES encoding:NSUTF8StringEncoding error:nil];
    BOOL tamperedRejected = !MCReplaceUpdate(source, target, version, NO, &error)
        && MCValidateUpdateApp(target, version);
    NSDictionary *asset = @{@"name": @"MiniCalendar.dmg", @"size": @100,
        @"browser_download_url": @"https://github.com/nicing/mini-calendar/releases/download/v1.2.0/MiniCalendar.dmg",
        @"digest": [@"sha256:" stringByAppendingString:[@"" stringByPaddingToLength:64 withString:@"0" startingAtIndex:0]]};
    NSMutableDictionary *badAsset = asset.mutableCopy;
    badAsset[@"browser_download_url"] = @"https://github.com/other/project/releases/download/v1.2.0/MiniCalendar.dmg";
    BOOL assetsPassed = MCUpdateAssetIsValid(asset, @"v1.2.0") && !MCUpdateAssetIsValid(badAsset, @"v1.2.0");
    badAsset = asset.mutableCopy;
    badAsset[@"digest"] = @"sha256:broken";
    assetsPassed = assetsPassed && !MCUpdateAssetIsValid(badAsset, @"v1.2.0");
    [files removeItemAtURL:root error:nil];
    BOOL passed = replaced && invalidRejected && tamperedRejected && assetsPassed;
    NSLog(@"Updater isolated install / invalid-version / tamper / asset tests %@", passed ? @"passed" : @"FAILED");
    return passed ? 0 : 1;
}

int MCRunUpdateDownloadTest(void) {
    __block BOOL fetched = NO;
    __block NSDictionary *release = nil;
    NSURL *URL = [NSURL URLWithString:@"https://api.github.com/repos/nicing/mini-calendar/releases/latest"];
    [[NSURLSession.sharedSession dataTaskWithURL:URL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error && [(NSHTTPURLResponse *)response statusCode] == 200) {
                release = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            }
            fetched = YES;
        });
    }] resume];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:30];
    while (!fetched && deadline.timeIntervalSinceNow > 0) {
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    NSDictionary *asset = nil;
    for (NSDictionary *candidate in release[@"assets"]) {
        if (MCUpdateAssetIsValid(candidate, release[@"tag_name"])) { asset = candidate; break; }
    }
    if (!asset) return 1;
    NSString *tag = release[@"tag_name"];
    NSString *version = [tag hasPrefix:@"v"] ? [tag substringFromIndex:1] : tag;
    MCUpdater *updater = [[MCUpdater alloc] initWithAsset:asset version:version];
    __block BOOL finished = NO;
    __block NSError *failure = nil;
    updater.completionHandler = ^(NSError *error) { failure = error; finished = YES; };
    [updater start];
    deadline = [NSDate dateWithTimeIntervalSinceNow:90];
    while (!finished && deadline.timeIntervalSinceNow > 0) {
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    BOOL passed = finished && !failure && updater.ready;
    NSLog(@"Updater GitHub download / SHA-256 / DMG / app verification %@ %@", passed ? @"passed" : @"FAILED", failure ?: @"");
    if (!finished) [updater cancel];
    return passed ? 0 : 1;
}
