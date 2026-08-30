#import "MCFont.h"
#import <CoreText/CoreText.h>

static NSString * const MCLatinFontPostScriptName = @"MiSansLatinVF";

BOOL MCRegisterBundledFonts(void) {
    static BOOL registered = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *fontURL = [NSBundle.mainBundle URLForResource:@"MiSansLatinVF"
                                              withExtension:@"ttf"];
        if (!fontURL) {
            return;
        }

        CFErrorRef error = NULL;
        BOOL success = CTFontManagerRegisterFontsForURL(
            (__bridge CFURLRef)fontURL,
            kCTFontManagerScopeProcess,
            &error
        );
        if (!success && error
            && CFErrorGetCode(error) == kCTFontManagerErrorAlreadyRegistered) {
            success = YES;
        }
        if (error) {
            CFRelease(error);
        }
        registered = success
            && [NSFont fontWithName:MCLatinFontPostScriptName size:12] != nil;
    });
    return registered;
}

NSFont *MCLatinFont(CGFloat size, NSFontWeight weight) {
    if (!MCRegisterBundledFonts()) {
        return [NSFont systemFontOfSize:size weight:weight];
    }
    NSFontDescriptor *descriptor = [NSFontDescriptor
        fontDescriptorWithName:MCLatinFontPostScriptName
                          size:size];
    descriptor = [descriptor fontDescriptorByAddingAttributes:@{
        NSFontTraitsAttribute: @{NSFontWeightTrait: @(weight)},
    }];
    return [NSFont fontWithDescriptor:descriptor size:size]
        ?: [NSFont fontWithName:MCLatinFontPostScriptName size:size]
        ?: [NSFont systemFontOfSize:size weight:weight];
}
