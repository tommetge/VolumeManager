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

- (void)volumeWillMountAt:(NSURL *)URL withProperties:(NSDictionary *)properties;
- (void)volumeWillUnmountFrom:(NSURL *)URL withProperties:(NSDictionary *)properties;
- (void)volumeWillEjectWithProperties:(NSDictionary *)properties;
- (void)volumeDidMountAt:(NSURL *)URL withProperties:(NSDictionary *)properties;
- (void)volumeDidEjectWithProperties:(NSDictionary *)properties;

@end

@implementation VolumeWatcher

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
    NSPrint(@"Volume '%@' ejected", [properties objectForKey:VMVolumeName]);
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
            if ([command isEqualToString:@"list"]) {
                VolumeManager* manager = [[VolumeManager alloc] init];

                NSPrint(@"Currently mounted volumes:");
                NSPrint(@"%@", [manager mountedVolumes]);
            }
        }

    }
    return 0;
}

