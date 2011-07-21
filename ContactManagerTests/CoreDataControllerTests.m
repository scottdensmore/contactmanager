//
//  CoreDataControllerTests.m
//  ContactManager
//
//  Created by Scott Densmore on 7/3/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "CoreDataControllerTests.h"
#import "CoreDataController.h"

@implementation CoreDataControllerTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testShouldThrowWhenCallingInit
{
    STAssertThrows([[CoreDataController alloc] init], @"Calling init: throws.");
}

- (void)testShouldThrowWhenCallInitWithNilModelName
{
    STAssertThrows([[CoreDataController alloc] initWithInitialType:NSInMemoryStoreType modelName:nil applicationSupportName:nil dataStoreName:nil], @"Calling init with nil model name should throw.");
}

- (void)testShouldThrowWhenCallInitWithNilApplicationSupportNameAndTypeIsNotNSInMemoryStoreType
{
    STAssertThrows([[CoreDataController alloc] initWithInitialType:NSXMLStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:nil dataStoreName:nil], @"Calling init with nil model name should throw.");
}

- (void)testShouldThrowWhenCallInitWithNilDataStoreNameAndTypeIsNotNSInMemoryStoreType
{
    STAssertThrows([[CoreDataController alloc] initWithInitialType:NSXMLStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:@"ContactManager" dataStoreName:nil], @"Calling init with nil model name should throw.");
}

- (void)testShouldCreateApplicationSupportFolderInApplicationSupportFolder
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	NSString *expectedAppDir = [basePath stringByAppendingPathComponent:@"ContactManager"];
    
    NSString *actualAppDir = [[[[CoreDataController alloc] initWithInitialType:NSXMLStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:@"ContactManager" dataStoreName:@"ContactManager.xml"] autorelease] applicationSupportFolder];
    
    STAssertEqualObjects(expectedAppDir, actualAppDir, @"Application support folder should be App Support directory and 'ContactManager");
}

- (void)testShouldReturnTrueAfterSave
{
    CoreDataController *coreDataController = [[[CoreDataController alloc] initWithInitialType:NSXMLStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:@"ContactManager" dataStoreName:@"ContactManager.xml"] autorelease];
    NSError *error = nil;
    
    BOOL saved = [coreDataController save:&error];
    
    STAssertNil(error, @"Save should not set error.");
    STAssertTrue(saved, @"Save should return 'true' when saving.");
}

@end
