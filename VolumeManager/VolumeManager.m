//
//  VolumeManager.m
//  VolumeManager
//
//  Created by Tom Metge on 11/10/13.
//  Copyright (c) 2013 Flying Paper Software. All rights reserved.
//

#import "VolumeManager.h"

#include <sys/mount.h>

#pragma mark Constants

NSString * const VMVolumeType = @"VMVolumeType";
NSString * const VMVolumeName = @"VMVolumeName";
NSString * const VMVolumeLocal = @"VMVolumeLocal";
NSString * const VMVolumeMountURL = @"VMVolumeMountURL";

#pragma mark Volume

@interface Volume : NSObject {
    NSString *_type;
    NSString *_name;
    NSURL *_url;
    BOOL _local;

    NSDictionary *_properties;
}

@property (copy) NSString *type;
@property (copy) NSString *name;
@property (copy) NSURL *url;
@property (assign) BOOL local;

- (instancetype)initWithStatFS:(struct statfs)stat;
- (NSDictionary*)properties;

@end

@implementation Volume

@synthesize type=_type, name=_name, url=_url, local=_local;

- (instancetype)initWithStatFS:(struct statfs)stat {
    self = [super init];
    if (self) {
        _properties = nil;

        self.type = [NSString stringWithUTF8String:stat.f_fstypename];
        NSString *mountpoint = [NSString stringWithUTF8String:stat.f_mntonname];
        self.url = [NSURL fileURLWithPath:mountpoint];
        self.local = (stat.f_flags & MNT_LOCAL) != 0;
    }
    return self;
}

- (NSDictionary*)properties {
    if (!_properties) {
        _properties = @{VMVolumeType: self.type,
                        VMVolumeLocal: [NSNumber numberWithBool:self.local],
                        VMVolumeMountURL: self.url};
    }

    return _properties;
}

@end

#pragma mark VolumeManager implementation

@implementation VolumeManager

@synthesize delegate = _delegate;

- (void)iterateMountedVolumes:(void (^)(Volume *volume))getVolume
{
    struct statfs* mounts;
    size_t num_mounts;

    num_mounts = getmntinfo(&mounts, MNT_WAIT);

    if (num_mounts <= 0) {
        return;
    }

    for (int i = 0; i < num_mounts; i++) {
        Volume *volume = [[Volume alloc] initWithStatFS:mounts[i]];
        getVolume(volume);
    }
}

- (NSArray*)mountedVolumes
{
    NSMutableArray *mountedDisks = [[NSMutableArray alloc] init];
    [self iterateMountedVolumes:^(Volume *volume) {
        [mountedDisks addObject:[volume properties]];
    }];

    return mountedDisks;
}

- (NSDictionary*)mountedVolumesByType
{
    NSMutableDictionary *volumesByType = [[NSMutableDictionary alloc] init];
    [self iterateMountedVolumes:^(Volume *volume) {
        NSMutableArray *typedVolumes;
        NSArray *currentTypedVolumes = [volumesByType objectForKey:volume.type];
        if (currentTypedVolumes) {
            typedVolumes = [[NSMutableArray alloc] initWithArray:currentTypedVolumes];
        } else {
            typedVolumes = [[NSMutableArray alloc] init];
        }

        [typedVolumes addObject:[volume properties]];

        [volumesByType setObject:typedVolumes forKey:volume.type];
    }];

    return volumesByType;
}

- (NSArray*)mountedVolumesForType:(NSString *)type
{
    NSMutableArray *typedVolumes = [[NSMutableArray alloc] init];
    [self iterateMountedVolumes:^(Volume *volume) {
        if ([volume.type isEqualToString:type]) {
            [typedVolumes addObject:[volume properties]];
        }
    }];
    return typedVolumes;
}

- (BOOL)unmountVolumeAt:(NSURL*)URL withError:(NSError**)error
{
    return NO;
}

- (BOOL)unmountAndEjectVolumeAt:(NSURL*)URL withError:(NSError**)error
{
    return NO;
}

@end
