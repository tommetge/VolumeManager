//
//  VolumeManager.h
//  VolumeManager
//
//  Created by Tom Metge on 11/10/13.
//  Copyright (c) 2013 Flying Paper Software. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString * const VMVolumeType;
NSString * const VMVolumeName;
NSString * const VMVolumeLocal;
NSString * const VMVolumeMountURL;

@protocol VolumeManagerDelegate <NSObject>

@optional
- (BOOL)volumeShouldMountAt:(NSURL*)URL withProperties:(NSDictionary*)properties;
- (BOOL)volumeShouldUnmountFrom:(NSURL*)URL withProperties:(NSDictionary*)properties;
- (BOOL)volumeShouldEjectWithProperties:(NSDictionary*)properties;

- (void)volumeWillMountAt:(NSURL*)URL withProperties:(NSDictionary*)properties;
- (void)volumeWillUnmountFrom:(NSURL*)URL withProperties:(NSDictionary*)properties;
- (void)volumeWillEjectWithProperties:(NSDictionary*)properties;

- (void)volumeDidMountAt:(NSURL*)URL withProperties:(NSDictionary*)properties;
- (void)volumeDidEjectWithProperties:(NSDictionary*)properties;

@end

@interface VolumeManager : NSObject {
    __weak id<VolumeManagerDelegate> _delegate;
}

@property (atomic, weak) id<VolumeManagerDelegate> delegate;

- (NSArray*)mountedVolumes;
- (NSDictionary*)mountedVolumesByType;
- (NSArray*)mountedVolumesForType:(NSString*)type;
- (BOOL)unmountVolumeAt:(NSURL*)URL withError:(NSError**)error;
- (BOOL)unmountAndEjectVolumeAt:(NSURL*)URL withError:(NSError**)error;

@end
