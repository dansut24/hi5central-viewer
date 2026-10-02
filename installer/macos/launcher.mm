#import <Cocoa/Cocoa.h>

#include <spawn.h>
#include <string>

extern char** environ;

namespace {

bool LaunchViewerCore(NSString* deepLink) {
    NSString* corePath = [[[NSBundle mainBundle] bundlePath]
        stringByAppendingPathComponent:@"Contents/MacOS/Hi5CentralViewerCore"];

    const char* executable = [corePath fileSystemRepresentation];
    if (!executable || !*executable) return false;

    std::string executableArg(executable);
    std::string linkArg;
    if (deepLink) {
        const char* utf8 = [deepLink UTF8String];
        if (utf8) linkArg = utf8;
    }

    char* argvWithLink[] = {
        executableArg.data(),
        linkArg.empty() ? nullptr : linkArg.data(),
        nullptr
    };
    char* argvWithoutLink[] = {
        executableArg.data(),
        nullptr
    };

    pid_t pid = 0;
    const int rc = posix_spawn(
        &pid,
        executable,
        nullptr,
        nullptr,
        linkArg.empty() ? argvWithoutLink : argvWithLink,
        environ);
    return rc == 0;
}

bool IsSupportedViewerUrl(NSURL* url) {
    if (!url) return false;
    NSString* scheme = [[url scheme] lowercaseString];
    return [scheme isEqualToString:@"hi5central-viewer"] ||
           [scheme isEqualToString:@"hi5viewer"] ||
           [scheme isEqualToString:@"hi5tech"];
}

} // namespace

@interface Hi5CentralViewerLauncherDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, assign) BOOL receivedUrl;
@end

@implementation Hi5CentralViewerLauncherDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    (void)notification;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    // A normal Finder launch should still show the Viewer shell. Give
    // LaunchServices a short opportunity to deliver an incoming URL first.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        if (!self.receivedUrl) {
            LaunchViewerCore(nil);
            [NSApp terminate:nil];
        }
    });
}

- (void)application:(NSApplication*)application openURLs:(NSArray<NSURL*>*)urls {
    self.receivedUrl = YES;

    for (NSURL* url in urls) {
        if (!IsSupportedViewerUrl(url)) continue;
        LaunchViewerCore([url absoluteString]);
    }

    // Keep each remote session in its own core process. Exiting this lightweight
    // URL handler means the next custom URL launch gets a fresh launcher and can
    // create another independent Viewer session.
    [application terminate:nil];
}

@end

int main(int argc, const char* argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSApplication* app = [NSApplication sharedApplication];
        Hi5CentralViewerLauncherDelegate* delegate =
            [[Hi5CentralViewerLauncherDelegate alloc] init];
        [app setDelegate:delegate];
        [app run];
    }

    return 0;
}
