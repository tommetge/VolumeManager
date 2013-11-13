//
//  VolumeManager.m
//  VolumeManager
//
//  Created by Tom Metge on 11/10/13.
//  Copyright (c) 2013 Flying Paper Software. All rights reserved.
//

#import "VolumeManager.h"

#include <DiskArbitration/DiskArbitration.h>

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

#pragma VolumeManager private interface

@interface VolumeManager() {
    DASessionRef _daSession;
}

- (void)volumeWillMountWithProperties:(NSDictionary*)properties;
- (void)volumeWillUnmountWithProperties:(NSDictionary*)properties;
- (void)volumeWillEjectWithProperties:(NSDictionary*)properties;
- (void)volumeDidMountWithProperties:(NSDictionary*)da_properties;
- (void)volumeDidUnmountWithProperties:(NSDictionary*)da_properties;
- (void)volumeDidUnmountWithProperties:(NSDictionary *)da_properties ejectDisk:(DADiskRef)disk;
- (void)volumeDidEjectWithProperties:(NSDictionary*)da_properties;
- (void)volumeDidFailToUnmountWithProperties:(NSDictionary*)da_properties error:(NSError*)error;
- (void)volumeDidFailToEjectWithProperties:(NSDictionary*)da_properties error:(NSError*)error;
- (BOOL)volumeShouldMountWithProperties:(NSDictionary*)da_properties;
- (BOOL)volumeShouldUnmountWithProperties:(NSDictionary*)da_properties;
- (BOOL)volumeShouldEjectWithProperties:(NSDictionary*)da_properties;

@end

#pragma mark DiskArbitration helpers

VolumeManager* manager(void *context)
{
    return (__bridge VolumeManager*)context;
}

NSDictionary* diskRefToProperties(DADiskRef disk)
{
    CFDictionaryRef diskDictionary = DADiskCopyDescription(disk);
    return (__bridge NSDictionary*)diskDictionary;
}

#pragma mark DiskArbitration callbacks

void diskAppeared(DADiskRef disk, void *context)
{
    [manager(context) volumeDidMountWithProperties:diskRefToProperties(disk)];
}

void diskDescriptionChanged(DADiskRef disk, CFArrayRef keys, void *context)
{
    // Pass on this right now
}

void diskDisappeared(DADiskRef disk, void *context)
{
    [manager(context) volumeDidEjectWithProperties:diskRefToProperties(disk)];
}

DADissenterRef diskEjectApproval(DADiskRef disk, void *context)
{
    if ([manager(context) volumeShouldEjectWithProperties:diskRefToProperties(disk)]) {
        return NULL;  // NULL is an approval
    } else {
        return DADissenterCreate(kCFAllocatorDefault,
                                 kDAReturnNotPermitted,
                                 CFSTR("Disallowed by VolumeManager"));
    }
}

// This is only used for DADiskEject()
void diskEject(DADiskRef disk, DADissenterRef dissenter, void *context)
{
    [manager(context) volumeDidEjectWithProperties:diskRefToProperties(disk)];
}

DADissenterRef diskMountApproval(DADiskRef disk, void *context)
{
    if ([manager(context) volumeShouldMountWithProperties:diskRefToProperties(disk)]) {
        return NULL;  // NULL is an approval
    } else {
        return DADissenterCreate(kCFAllocatorDefault,
                                 kDAReturnNotPermitted,
                                 CFSTR("Disallowed by VolumeManager"));
    }
}

void diskPeek(DADiskRef disk, void *context)
{
    // Pass on this right now
}

void diskRename(DADiskRef disk, DADissenterRef dissenter, void *context)
{
    // Pass on this right now
}

DADissenterRef diskUnmountApproval(DADiskRef disk, void *context)
{
    if ([manager(context) volumeShouldUnmountWithProperties:diskRefToProperties(disk)]) {
        return NULL;  // NULL is an approval
    } else {
        return DADissenterCreate(kCFAllocatorDefault,
                                 kDAReturnNotPermitted,
                                 CFSTR("Disallowed by VolumeManager"));
    }
}

void diskUnmounted(DADiskRef disk, DADissenterRef dissenter, void *context)
{
    if (dissenter == NULL) {
        // Success
        [manager(context) volumeDidUnmountWithProperties:diskRefToProperties(disk)];
    } else {
        // Failure
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: (__bridge NSString*)DADissenterGetStatusString(dissenter)};
        NSError *error = [NSError errorWithDomain:@"VolumeManager"
                                             code:DADissenterGetStatus(dissenter)
                                         userInfo:userInfo];
        [manager(context) volumeDidFailToUnmountWithProperties:diskRefToProperties(disk)
                                                         error:error];
    }
}

void diskUnmountedShouldEject(DADiskRef disk, DADissenterRef dissenter, void *context)
{
    if (dissenter == NULL) {
        // Success
        [manager(context) volumeDidUnmountWithProperties:diskRefToProperties(disk) ejectDisk:disk];
    } else {
        // Failure
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: (__bridge NSString*)DADissenterGetStatusString(dissenter)};
        NSError *error = [NSError errorWithDomain:@"VolumeManager"
                                             code:DADissenterGetStatus(dissenter)
                                         userInfo:userInfo];
        [manager(context) volumeDidFailToUnmountWithProperties:diskRefToProperties(disk)
                                                         error:error];
        [manager(context) volumeDidFailToEjectWithProperties:diskRefToProperties(disk)
                                                       error:error];
    }
}

void diskEjected(DADiskRef disk, DADissenterRef dissenter, void *context)
{
    if (dissenter == NULL) {
        // Success
        [manager(context) volumeDidEjectWithProperties:diskRefToProperties(disk)];
    } else {
        // Failure
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: (__bridge NSString*)DADissenterGetStatusString(dissenter)};
        NSError *error = [NSError errorWithDomain:@"VolumeManager"
                                             code:DADissenterGetStatus(dissenter)
                                         userInfo:userInfo];
        [manager(context) volumeDidFailToEjectWithProperties:diskRefToProperties(disk)
                                                       error:error];
    }
}

#pragma mark VolumeManager implementation

@implementation VolumeManager

@synthesize delegate = _delegate;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _daSession = NULL;
        _daSession = DASessionCreate(kCFAllocatorDefault);
        DASessionScheduleWithRunLoop(_daSession,
                                     [[NSRunLoop mainRunLoop] getCFRunLoop],
                                     kCFRunLoopDefaultMode);
        [self setupArbitrationCalls];
    }
    return self;
}

- (void)dealloc
{
    if (_daSession != NULL) {
        [self removeArbitrationCalls];
        DASessionUnscheduleFromRunLoop(_daSession,
                                       [[NSRunLoop mainRunLoop] getCFRunLoop],
                                       kCFRunLoopDefaultMode);
        CFRelease(_daSession);
        _daSession = NULL;
    }
}

- (void)setupArbitrationCalls
{
    DARegisterDiskAppearedCallback(_daSession, NULL, diskAppeared, (__bridge void*)self);
    DARegisterDiskDescriptionChangedCallback(_daSession, NULL, NULL, diskDescriptionChanged, (__bridge void*)self);
    DARegisterDiskDisappearedCallback(_daSession, NULL, diskDisappeared, (__bridge void*)self);
    DARegisterDiskPeekCallback(_daSession, NULL, 0, diskPeek, (__bridge void*)self);
    DARegisterDiskEjectApprovalCallback(_daSession, NULL, diskEjectApproval, (__bridge void*)self);
    DARegisterDiskMountApprovalCallback(_daSession, NULL, diskMountApproval, (__bridge void*)self);
    DARegisterDiskUnmountApprovalCallback(_daSession, NULL, diskUnmountApproval, (__bridge void*)self);
}

- (void)removeArbitrationCalls
{
    DAUnregisterApprovalCallback(_daSession, diskEjectApproval, (__bridge void*)self);
    DAUnregisterApprovalCallback(_daSession, diskMountApproval, (__bridge void*)self);
    DAUnregisterApprovalCallback(_daSession, diskUnmountApproval, (__bridge void*)self);
    DAUnregisterCallback(_daSession, diskAppeared, (__bridge void*)self);
    DAUnregisterCallback(_daSession, diskDescriptionChanged, (__bridge void*)self);
    DAUnregisterCallback(_daSession, diskDisappeared, (__bridge void*)self);
    DAUnregisterCallback(_daSession, diskPeek, (__bridge void*)self);
}

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
    struct statfs fsStat;
	DADiskRef disk = NULL;

	if (statfs([[URL path] UTF8String], &fsStat) != 0) return NO;

	disk = DADiskCreateFromBSDName(kCFAllocatorDefault,
								   _daSession,
								   fsStat.f_mntfromname);
    if (!disk) return NO;

    DADiskUnmount(disk, kDADiskUnmountOptionDefault, diskUnmounted, (__bridge void*)self);
    CFRelease(disk);

    return YES;
}

- (BOOL)unmountAndEjectVolumeAt:(NSURL*)URL withError:(NSError**)error
{
    struct statfs fsStat;
	DADiskRef disk = NULL;

	if (statfs([[URL path] UTF8String], &fsStat) != 0) return NO;

	disk = DADiskCreateFromBSDName(kCFAllocatorDefault,
								   _daSession,
								   fsStat.f_mntfromname);
    if (!disk) return NO;

    DADiskRef wholeDisk = DADiskCopyWholeDisk(disk);
    CFRelease(disk);

    DADiskUnmount(wholeDisk, kDADiskUnmountOptionWhole, diskUnmountedShouldEject, (__bridge void*)self);
    CFRelease(wholeDisk);

    return YES;
}

- (void)volumeWillMountWithProperties:(NSDictionary*)properties
{
    if ([self delegateRespondsTo:@selector(volumeWillMountAt:withProperties:)]) {
        NSURL *url = [properties objectForKey:VMVolumeMountURL];
        if (url) {
            [self.delegate volumeWillMountAt:url withProperties:properties];
        }
    }
}

- (void)volumeWillUnmountWithProperties:(NSDictionary*)properties
{
    if ([self delegateRespondsTo:@selector(volumeWillUnmountFrom:withProperties:)]) {
        NSURL *url = [properties objectForKey:VMVolumeMountURL];
        [self.delegate volumeWillUnmountFrom:url withProperties:properties];
    }
}

- (void)volumeWillEjectWithProperties:(NSDictionary*)properties
{
    if ([self delegateRespondsTo:@selector(volumeWillEjectWithProperties:)]) {
        [self.delegate volumeWillEjectWithProperties:properties];
    }
}

- (void)volumeDidAppearWithProperties:(NSDictionary*)da_properties
{}

- (void)volumeDidMountWithProperties:(NSDictionary*)da_properties
{
    if ([self delegateRespondsTo:@selector(volumeDidMountAt:withProperties:)]) {
        NSDictionary *properties = [self propertiesForDAProperties:da_properties];
        NSURL *url = [properties objectForKey:VMVolumeMountURL];
        if (url) {
            [self.delegate volumeDidMountAt:url withProperties:properties];
        }
    }
}

- (void)volumeDidUnmountWithProperties:(NSDictionary*)da_properties
{
    if ([self delegateRespondsTo:@selector(volumeDidUnmountWithProperties:)]) {
        NSDictionary *properties = [self propertiesForDAProperties:da_properties];
        [self.delegate volumeDidUnmountWithProperties:properties];
    }
}

- (void)volumeDidUnmountWithProperties:(NSDictionary *)da_properties ejectDisk:(DADiskRef)disk
{
    [self volumeDidUnmountWithProperties:da_properties];
    DADiskEject(disk, kDADiskEjectOptionDefault, diskEjected, (__bridge void*)self);
}

- (void)volumeDidEjectWithProperties:(NSDictionary*)da_properties
{
    if ([self delegateRespondsTo:@selector(volumeDidEjectWithProperties:)]) {
        NSDictionary *properties = [self propertiesForDAProperties:da_properties];
        [self.delegate volumeDidEjectWithProperties:properties];
    }
}

- (void)volumeDidFailToUnmountWithProperties:(NSDictionary*)da_properties error:(NSError*)error
{
    if ([self delegateRespondsTo:@selector(volumeDidFailToUnmountFrom:withProperties:error:)]) {
        NSDictionary *properties = [self propertiesForDAProperties:da_properties];
        NSURL *url = [properties objectForKey:VMVolumeMountURL];
        [self.delegate volumeDidFailToUnmountFrom:url withProperties:properties error:error];
    }
}

- (void)volumeDidFailToEjectWithProperties:(NSDictionary*)da_properties error:(NSError*)error
{
    if ([self delegateRespondsTo:@selector(volumeDidFailToEjectWithProperties:error:)]) {
        NSDictionary *properties = [self propertiesForDAProperties:da_properties];
        [self.delegate volumeDidFailToEjectWithProperties:properties error:error];
    }
}

- (BOOL)volumeShouldMountWithProperties:(NSDictionary*)da_properties
{
    BOOL shouldMount = YES;
    NSDictionary *properties = [self propertiesForDAProperties:da_properties];

    if ([self delegateRespondsTo:@selector(volumeShouldMountAt:withProperties:)]) {
        NSURL *url = [properties objectForKey:VMVolumeMountURL];
        if (url) {
            shouldMount = [self.delegate volumeShouldMountAt:url withProperties:properties];
        }
    }

    if (shouldMount) {
        [self volumeWillMountWithProperties:properties];
    }

    return shouldMount;
}

- (BOOL)volumeShouldUnmountWithProperties:(NSDictionary*)da_properties
{
    BOOL shouldUnmount = YES;
    NSDictionary *properties = [self propertiesForDAProperties:da_properties];

    if ([self delegateRespondsTo:@selector(volumeShouldUnmountFrom:withProperties:)]) {
        NSURL *url = [properties objectForKey:VMVolumeMountURL];
        if (url) {
            shouldUnmount = [self.delegate volumeShouldUnmountFrom:url withProperties:properties];
        }
    }

    if (shouldUnmount) {
        [self volumeWillUnmountWithProperties:properties];
    }

    return shouldUnmount;
}

- (BOOL)volumeShouldEjectWithProperties:(NSDictionary*)da_properties
{
    BOOL shouldEject = YES;
    NSDictionary *properties = [self propertiesForDAProperties:da_properties];

    if ([self delegateRespondsTo:@selector(volumeShouldEjectWithProperties:)]) {
        shouldEject = [self.delegate volumeShouldEjectWithProperties:properties];
    }

    if (shouldEject) {
        [self volumeWillEjectWithProperties:properties];
    }

    return shouldEject;
}

- (BOOL)delegateRespondsTo:(SEL)sel {
    return (self.delegate && [self.delegate respondsToSelector:sel]);
}

- (NSDictionary*)propertiesForDAProperties:(NSDictionary*)da_properties {
    NSMutableDictionary* properties = [da_properties mutableCopy];
    if ([da_properties objectForKey:@"DAVolumePath"]) {
        [properties setObject:[da_properties objectForKey:@"DAVolumePath"] forKey:VMVolumeMountURL];
    }
    if ([da_properties objectForKey:@"DAVolumeKind"]) {
        [properties setObject:[da_properties objectForKey:@"DAVolumeKind"] forKey:VMVolumeType];
    }
    if ([da_properties objectForKey:@"DAMediaRemovable"]) {
        [properties setObject:[da_properties objectForKey:@"DAMediaRemovable"] forKey:VMVolumeLocal];
    }
    if ([da_properties objectForKey:@"DAVolumeName"]) {
        [properties setObject:[da_properties objectForKey:@"DAVolumeName"] forKey:VMVolumeName];
    }

    return properties;
}

@end
