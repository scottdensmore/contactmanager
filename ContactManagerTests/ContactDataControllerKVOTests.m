//
//  ContactDataControllerKVOTests.m
//  ContactManager
//
//  Created by Scott Densmore on 6/26/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CoreDataController.h"
#import "ContactDataController.h"
#import "Contact.h"

@interface ContactDataControllerKVOTests : XCTestCase

@property (nonatomic, strong) CoreDataController *coreDataController;
@property (nonatomic, strong) ContactDataController *contactDataController;
@property (nonatomic, assign) BOOL contactsChanged;

@end

@implementation ContactDataControllerKVOTests

- (void)setUp
{
    [super setUp];
    
    _coreDataController = [[CoreDataController alloc] initWithInitialType:NSInMemoryStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:nil dataStoreName:nil];
    _contactDataController = [[ContactDataController alloc] initWithCoreDataController:_coreDataController];
    [_contactDataController addObserver:self forKeyPath:@"contacts" options:NSKeyValueObservingOptionNew context:NULL];
    
    _contactsChanged = NO;
}

- (void)tearDown
{
    [_contactDataController removeObserver:self forKeyPath:@"contacts"];
    _contactDataController = nil;
    
    _coreDataController = nil;
    
    [super tearDown];
}

- (void)testShouldFireChangeForContactsWhenAddingNewContact
{
    [_contactDataController createContact];
    
    XCTAssertTrue(_contactsChanged, @"Adding new contact should fire change for contacts");
}

- (void)testShouldFireChangeForContactsWhenDeletingContact
{
    Contact *contact = [_contactDataController createContact];
    _contactsChanged = NO;
    
    [_contactDataController deleteContact:contact];
    
    XCTAssertTrue(_contactsChanged, @"Adding new contact should fire change for contacts");
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	_contactsChanged = YES;
}

@end
