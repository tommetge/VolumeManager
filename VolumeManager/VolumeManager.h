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
- (void)volumeShouldMountAt:(NSURL*)URL withProperties:(NSDictionary*)properties;
- (void)volumeShouldUnmountAt:(NSURL*)URL withProperties:(NSDictionary*)properties;
- (void)volumeDidMountAt:(NSURL*)URL withProperties:(NSDictionary*)properties;
- (void)volumeDidUnmountAt:(NSURL*)URL withProperties:(NSDictionary*)properties;

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
