//
//  VolumeManagerTests.m
//  VolumeManagerTests
//
//  Created by Tom Metge on 11/10/13.
//  Copyright (c) 2013 Flying Paper Software. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "VolumeManager.h"

@interface MockVolume : NSObject

@property (copy) NSString *type;

- (NSDictionary*)properties;

@end

@implementation MockVolume

@synthesize type;

- (NSDictionary*)properties
{
    return @{VMVolumeLocal:[NSNumber numberWithBool:1],
             VMVolumeType: self.type,
             VMVolumeMountURL:[NSURL fileURLWithPath:@"/"]};
}

@end

@interface VolumeManagerTester : VolumeManager

@property (atomic, weak) NSDictionary* volumes;

- (void)iterateMountedVolumes:(void (^)(MockVolume *volume))getVolume;

@end

@implementation VolumeManagerTester

- (void)iterateMountedVolumes:(void (^)(MockVolume *))getVolume
{
    for (NSString *type in self.volumes) {
        for (int i = 0; i < [[self.volumes objectForKey:type] intValue]; i++) {
            NSLog(@"Adding %@", type);
            MockVolume *volume = [[MockVolume alloc] init];
            volume.type = type;
            getVolume(volume);
        }
    }
}

@end

@interface VolumeManagerTests : XCTestCase

@property (nonatomic, strong) NSDictionary *testVolumes;
@property (nonatomic, strong) VolumeManagerTester *manager;

@end

@implementation VolumeManagerTests

@synthesize testVolumes, manager;

- (void)setUp
{
    [super setUp];

    self.manager = [[VolumeManagerTester alloc] init];
    self.testVolumes = @{@"autofs": [NSNumber numberWithInt:3],
                         @"hfs": [NSNumber numberWithInt:1]};
    manager.volumes = self.testVolumes;

    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testMountedVolumesForType
{
    XCTAssertEqual(3UL, [[manager mountedVolumesForType:@"autofs"] count], @"Incorrect volume count");
    for (NSDictionary *volume in [manager mountedVolumesForType:@"autofs"]) {
        XCTAssertEqual(@"autofs", [volume objectForKey:VMVolumeType], @"Incorrect volume type");
    }
    XCTAssertEqual(1UL, [[manager mountedVolumesForType:@"hfs"] count], @"Incorrect volume count");
    XCTAssertEqual(0UL, [[manager mountedVolumesForType:@"blah"] count], @"Incorrect volume count");

    NSDictionary *emptyVolumes = @{};
    manager.volumes = emptyVolumes;
    XCTAssertEqual(0UL, [[manager mountedVolumesForType:@"autofs"] count], @"Incorrect volume count");
    XCTAssertEqual(0UL, [[manager mountedVolumesForType:@"hfs"] count], @"Incorrect volume count");
}

- (void)testMountedVolumes
{
    XCTAssertEqual(4UL, [[manager mountedVolumes] count], @"Incorrect volume count");
    size_t autofs_count = 0;
    size_t hfs_count = 0;
    for (NSDictionary *volume in [manager mountedVolumes]) {
        if ([[volume objectForKey:VMVolumeType] isEqualToString:@"autofs"]) {
            autofs_count++;
        } else if ([[volume objectForKey:VMVolumeType] isEqualToString:@"hfs"]) {
            hfs_count++;
        }
    }
    XCTAssertEqual(3UL, autofs_count, @"Incorrect volume count");
    XCTAssertEqual(1UL, hfs_count, @"Incorrect volume count");

    NSDictionary *emptyVolumes = @{};
    manager.volumes = emptyVolumes;
    XCTAssertEqual(0UL, [[manager mountedVolumes] count], @"Incorrect volume count");
}

- (void)testMountedVolumesByType
{
    XCTAssertEqual(2UL, [[manager mountedVolumesByType] count], @"Incorrect type count");
    size_t autofs_count = 0;
    size_t hfs_count = 0;
    NSDictionary *volumesByType = [manager mountedVolumesByType];
    for (NSString *type in volumesByType) {
        if ([type isEqualToString:@"autofs"]) {
            autofs_count = [[volumesByType objectForKey:@"autofs"] count];
        } else if ([type isEqualToString:@"hfs"]) {
            hfs_count = [[volumesByType objectForKey:@"hfs"] count];
        }
    }
    XCTAssertEqual(3UL, autofs_count, @"Incorrect volume count");
    XCTAssertEqual(1UL, hfs_count, @"Incorrect volume count");

    NSDictionary *emptyVolumes = @{};
    manager.volumes = emptyVolumes;
    XCTAssertEqual(0UL, [[manager mountedVolumesByType] count], @"Incorrect volume count");
}

@end
