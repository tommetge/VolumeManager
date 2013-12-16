//
//  main.m
//  VolumeMgr
//
//  Created by Tom Metge on 11/12/13.
//  Copyright (c) 2013 Flying Paper Software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "VolumeManager.h"

// print to stdout
static void NSPrint(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    fprintf(stdout, "%s\n", [string UTF8String]);
}

@interface VolumeWatcher : NSObject <VolumeManagerDelegate>

@property (assign) BOOL unmount_completed;
@property (assign) BOOL eject_completed;

- (void)volumeWillMountAt:(NSURL *)URL withProperties:(NSDictionary *)properties;
- (void)volumeWillUnmountFrom:(NSURL *)URL withProperties:(NSDictionary *)properties;
- (void)volumeWillEjectWithProperties:(NSDictionary *)properties;
- (void)volumeDidMountAt:(NSURL *)URL withProperties:(NSDictionary *)properties;
- (void)volumeDidEjectWithProperties:(NSDictionary *)properties;

@end

@implementation VolumeWatcher

@synthesize unmount_completed, eject_completed;

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.unmount_completed = NO;
        self.eject_completed = NO;
    }
    return self;
}

- (void)volumeWillMountAt:(NSURL *)URL withProperties:(NSDictionary *)properties
{
    NSPrint(@"Volume '%@' will mount at %@", [properties objectForKey:VMVolumeName], [URL path]);
}

- (void)volumeWillUnmountFrom:(NSURL *)URL withProperties:(NSDictionary *)properties
{
    NSPrint(@"Volume '%@' will unmount from %@", [properties objectForKey:VMVolumeName], [URL path]);
}

- (void)volumeWillEjectWithProperties:(NSDictionary *)properties
{
    NSPrint(@"Volume '%@' will eject", [properties objectForKey:VMVolumeName]);
}

- (void)volumeDidMountAt:(NSURL *)URL withProperties:(NSDictionary *)properties
{
    NSPrint(@"Volume '%@' mounted at %@", [properties objectForKey:VMVolumeName], [URL path]);
}

- (void)volumeDidEjectWithProperties:(NSDictionary *)properties
{
    self.eject_completed = YES;  // This amy or may not actually be true
    NSPrint(@"Volume '%@' ejected", [properties objectForKey:VMVolumeName]);
}

- (void)volumeDidUnmountWithProperties:(NSDictionary *)properties
{
    self.unmount_completed = YES;
    NSPrint(@"Volume '%@' unmounted", [properties objectForKey:VMVolumeName]);
}

- (void)volumeDidFailToUnmountFrom:(NSURL *)URL withProperties:(NSDictionary *)properties error:(NSError *)error
{
    self.unmount_completed = YES;
    NSPrint(@"Volume '%@' failed to unmount from '%@': %@", [properties objectForKey:VMVolumeName], [URL path], [error localizedDescription]);
}

- (void)volumeDidFailToEjectWithProperties:(NSDictionary *)properties error:(NSError *)error
{
    self.eject_completed = YES;
    NSPrint(@"Volume '%@' failed to eject: %@", [properties objectForKey:VMVolumeName], [error localizedDescription]);
}

@end

int main(int argc, const char * argv[])
{

    @autoreleasepool {

        if (argc == 1) {
            NSPrint(@"Watching disks (ctrl-c to exit)...");

            VolumeManager *manager = [[VolumeManager alloc] init];
            VolumeWatcher* watcher = [[VolumeWatcher alloc] init];
            manager.delegate = watcher;

            [[NSRunLoop currentRunLoop] run];
            exit(0);
        } else {
            NSString *command = [[NSString stringWithUTF8String:argv[1]] lowercaseString];
            if ([command isEqualToString:@"help"]) {
                NSPrint(@"Available commands: list, unmount, eject");
                exit(1);
            }
            if ([command isEqualToString:@"list"]) {
                VolumeManager* manager = [[VolumeManager alloc] init];

                NSPrint(@"Currently mounted volumes:");
                NSPrint(@"%@", [manager mountedVolumes]);

                exit(0);
            }
            if ([command isEqualToString:@"unmount"]) {
                if (argc != 3) {
                    NSPrint(@"Usage: VolumeMgr unmount [path]");
                    exit(1);
                }

                VolumeManager *manager = [[VolumeManager alloc] init];
                VolumeWatcher *watcher = [[VolumeWatcher alloc] init];
                manager.delegate = watcher;

                NSString *path = [NSString stringWithUTF8String:argv[2]];
                [manager unmountVolumeAt:[NSURL fileURLWithPath:path] withError:nil];

                while (!watcher.unmount_completed) {
                    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1, false);
                }

                exit(0);
            }
            if ([command isEqualToString:@"eject"]) {
                if (argc != 3) {
                    NSPrint(@"Usage: VolumeMgr eject [path]");
                    exit(1);
                }

                VolumeManager *manager = [[VolumeManager alloc] init];
                VolumeWatcher *watcher = [[VolumeWatcher alloc] init];
                manager.delegate = watcher;

                NSString *path = [NSString stringWithUTF8String:argv[2]];
                [manager unmountAndEjectVolumeAt:[NSURL fileURLWithPath:path] withError:nil];

                while (!watcher.eject_completed) {
                    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1, false);
                }

                exit(0);
            }
            if ([command isEqualToString:@"info"]) {
                if (argc != 3) {
                    NSPrint(@"Usage: VolumeMgr info [path]");
                    exit(1);
                }

                VolumeManager *manager = [[VolumeManager alloc] init];

                NSString *path = [NSString stringWithUTF8String:argv[2]];
                NSPrint(@"%@", [manager mountedVolumeInfoAt:[NSURL fileURLWithPath:path]]);
            }
        }

    }
    return 0;
}

