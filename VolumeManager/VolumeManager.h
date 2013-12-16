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
NSString * const VMVolumeNetwork;

@protocol VolumeManagerDelegate <NSObject>

@optional

/**-----------------------------------------------------------------
 * @name Arbiting mount, unmount, and eject requests
 * -----------------------------------------------------------------
 */

/**
 Arbitration method for pending volume mounts

 Allows the delegate to allow or disallow mounting of a specific volume.

 @param URL URL to which the volume would mount, if allowed
 @param properties Properties of the volume wishing to mount, including the VM-prefixed keys
 */
- (BOOL)volumeShouldMountAt:(NSURL*)URL withProperties:(NSDictionary*)properties;
/**
 Arbitration method for pending volume unmounts

 Allows the delegate to allow or disallow unmounting of a specific volume.

 @param URL URL from which the volume would unmount, if allowed
 @param properties Properties of the volume wishing to unmount, including the VM-prefixed keys
 */
- (BOOL)volumeShouldUnmountFrom:(NSURL*)URL withProperties:(NSDictionary*)properties;
/**
 Arbitration method for pending volume ejects

 Allows the delegate to allow or disallow ejection of a specific volume.

 @param properties Properties of the volume wishing to eject, including the VM-prefixed keys

 @warning: VMVolumeMountURL will not be available as the volume is not mounted.
 */
- (BOOL)volumeShouldEjectWithProperties:(NSDictionary*)properties;

/**-----------------------------------------------------------------
 * @name Notification of pending mount, unmount, and eject
 * -----------------------------------------------------------------
 */

/**
 Notification of a pending mount

 Informs the delegate of a pending mount event.

 @param URL URL to which the volume will mount
 @param properties Properties of the mounting volume, including the VM-prefixed keys
*/
- (void)volumeWillMountAt:(NSURL*)URL withProperties:(NSDictionary*)properties;

/**
 Notification of a pending unmount

 Informs the delegate of a pending unmount event.

 @param URL URL from which the volume will unmount
 @param properties Properties of the unmounting volume, including the VM-prefixed keys
 */
- (void)volumeWillUnmountFrom:(NSURL*)URL withProperties:(NSDictionary*)properties;

/**
 Notification of a pending eject

 Informs the delegate of a pending eject event.

 @param properties Properties of the ejecting volume, including the VM-prefixed keys
 
 @warning: VMVolumeMountURL will not be available as the volume is not mounted.
 */
- (void)volumeWillEjectWithProperties:(NSDictionary*)properties;

/**-----------------------------------------------------------------
 * @name Notification of mount, unmount, and eject events
 * -----------------------------------------------------------------
 */

/**
 Notification that a volume has mounted

 Informs the delegate of a successful mount event.

 @param URL URL to which the volume has mounted
 @param properties Properties of the mounted volume, including the VM-prefixed keys
 */
- (void)volumeDidMountAt:(NSURL*)URL withProperties:(NSDictionary*)properties;

/**
 Notification that a volume has unmounted

 Informs the delegate of a successful unmount event.

 @param properties Properties of the mounted volume, including the VM-prefixed keys

 @warning This will only be called in response to unmount or eject requests
 @see unmountVolumeAt:withError:
 @see unmountAndEjectVolumeAt:withError:
 */
- (void)volumeDidUnmountWithProperties:(NSDictionary*)properties;

/**
 Notification that a volume/disk has ejected

 Informs the delegate of a successful eject event.

 @param properties Properties of the ejected volume, including the VM-prefixed keys

 @see unmountVolumeAt:withError:
 @see unmountAndEjectVolumeAt:withError:
 */
- (void)volumeDidEjectWithProperties:(NSDictionary*)properties;

/**-----------------------------------------------------------------
 * @name Notification of failed unmount and eject events
 * -----------------------------------------------------------------
 */

/**
 Notification that a volume has failed to unmount

 Informs the delegate that the unmount request has failed. This will always be in
 response to a delegate's request to unmount or eject a volume.

 @param properties Properties of the volume, including the VM-prefixed keys

 @see unmountVolumeAt:withError:
 @see unmountAndEjectVolumeAt:withError:
 */
- (void)volumeDidFailToUnmountFrom:(NSURL*)URL withProperties:(NSDictionary*)properties error:(NSError*)error;

/**
 Notification that a volume has failed to eject

 Informs the delegate that the eject request has failed. This will always be in
 response to a delegate's request to unmount or eject a volume.

 @param properties Properties of the volume, including the VM-prefixed keys

 @see unmountVolumeAt:withError:
 @see unmountAndEjectVolumeAt:withError:
 */
- (void)volumeDidFailToEjectWithProperties:(NSDictionary*)properties error:(NSError*)error;

@end

/** This class offers a high-level, Cocoa-style interface for DiskArbitration

 VolumeManager offers similar functionality to the Disk Manager app or the `diskutil`
 command-line utility. It is possible to list all mounted volumes and manage both
 mounted and unmounted volumes or disks.

 The delegate model is used to provide arbitration features to the delegate, allowing
 the delegate to approve or deny requests to mount or eject volumes. Additionally,
 the delegate's notification methods are called when disks are pending mount, unmount,
 or eject, as well as after these events have taken place.

 An example of these features is provided in the included "VolumeMgr" utility, which
 emulates the diskutil command-line utility.

 To simply list all mounted volumes:

        VolumeManager *manager = [[VolumeManager alloc] init];
        NSArray *mounts = [manager mountedVolumes];

 As documented below, it is possible to categorize mounted volumes by their "type"
 (bus or filesystem type). @see mountedVolumesByType and @see mountedVolumesForType:

 */

@interface VolumeManager : NSObject {
    __weak id<VolumeManagerDelegate> _delegate;
}

@property (atomic, weak) id<VolumeManagerDelegate> delegate;

/**
 Asks for all currently mounted volumes

 @return Array of NSDictionary* instances, representing all mounted volumes

 @note Each disks' NSDictionary* includes the VM-prefixed keys (see constants defined
 above).
 */
- (NSArray*)mountedVolumes;

/**
 Asks for all currently mounted volumes, organized by type

 @return Dictionary whose keys represent filesystem types, whose contents are arrays
 of NSDictionary* instances representing disks corresponding to the keyed type.

 @note Each disks' NSDictionary* includes the VM-prefixed keys (see constants defined
 above).
 */
- (NSDictionary*)mountedVolumesByType;

/**
 Asks for all currently mounted volumes of the provided type

 @return An array of NSDictionary* instances representing disks corresponding to the
 provided type.

 @note Each disks' NSDictionary* includes the VM-prefixed keys (see constants defined
 above).
 */
- (NSArray*)mountedVolumesForType:(NSString*)type;

/**
 Asks for information about the volume mounted at the provided URL

 @return NSDictionary* with all available volume attributes

 @note The NSDictionary* includes the VM-prefixed keys (see constants defined above.)
 */
- (NSDictionary*)mountedVolumeInfoAt:(NSURL*)URL;

/**
 Unmounts the volume at the given path

 @param URL URL of the volume to unmount.
 @param error Error to set if things go bad.
 @return Status of the request
 
 @warning The return code indicates whether or not the request was issued, not that
 the disk is unmounted. The caller must implement the delegate method
 @see volumeDidUnmountWithProperties: to determine if the request completed
 succesfully.
 */
- (BOOL)unmountVolumeAt:(NSURL*)URL withError:(NSError**)error;

/**
 Ejects the volume and all associated mounts that correspond to the given path

 @param URL URL of the volume to eject.
 @param error Error to set if things go bad.
 @return Status of the request

 @warning The return code indicates whether or not the request was issued, not that
 the disk is ejected. The caller must implement the delegate method
 @see volumeDidEjectWithProperties: to determine if the request completed
 succesfully.
 */
- (BOOL)unmountAndEjectVolumeAt:(NSURL*)URL withError:(NSError**)error;

@end
