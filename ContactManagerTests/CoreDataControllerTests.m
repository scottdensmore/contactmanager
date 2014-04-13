//
//  CoreDataControllerTests.m
//  ContactManager
//
//  Created by Scott Densmore on 7/3/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CoreDataController.h"

@interface CoreDataControllerTests : XCTestCase

@end

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
    XCTAssertThrows([[CoreDataController alloc] init], @"Calling init: throws.");
}

- (void)testShouldThrowWhenCallInitWithNilModelName
{
    XCTAssertThrows([[CoreDataController alloc] initWithInitialType:NSInMemoryStoreType modelName:nil applicationSupportName:nil dataStoreName:nil], @"Calling init with nil model name should throw.");
}

- (void)testShouldThrowWhenCallInitWithNilApplicationSupportNameAndTypeIsNotNSInMemoryStoreType
{
    XCTAssertThrows([[CoreDataController alloc] initWithInitialType:NSXMLStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:nil dataStoreName:nil], @"Calling init with nil model name should throw.");
}

- (void)testShouldThrowWhenCallInitWithNilDataStoreNameAndTypeIsNotNSInMemoryStoreType
{
    XCTAssertThrows([[CoreDataController alloc] initWithInitialType:NSXMLStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:@"ContactManager" dataStoreName:nil], @"Calling init with nil model name should throw.");
}

- (void)testShouldCreateApplicationSupportFolderInApplicationSupportFolder
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? paths[0] : NSTemporaryDirectory();
	NSString *expectedAppDir = [basePath stringByAppendingPathComponent:@"ContactManager"];
    
    NSString *actualAppDir = [[[CoreDataController alloc] initWithInitialType:NSXMLStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:@"ContactManager" dataStoreName:@"ContactManager.xml"] applicationSupportFolder];
    
    XCTAssertEqualObjects(expectedAppDir, actualAppDir, @"Application support folder should be App Support directory and 'ContactManager");
}

- (void)testShouldReturnTrueAfterSave
{
    CoreDataController *coreDataController = [[CoreDataController alloc] initWithInitialType:NSXMLStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:@"ContactManager" dataStoreName:@"ContactManager.xml"];
    NSError *error = nil;
    
    BOOL saved = [coreDataController save:&error];
    
    XCTAssertNil(error, @"Save should not set error.");
    XCTAssertTrue(saved, @"Save should return 'true' when saving.");
}

@end
