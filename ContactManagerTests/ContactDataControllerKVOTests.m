//
//  ContactDataControllerKVOTests.m
//  ContactManager
//
//  Created by Scott Densmore on 6/26/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "ContactDataControllerKVOTests.h"
#import "CoreDataController.h"
#import "ContactDataController.h"
#import "Contact.h"

@implementation ContactDataControllerKVOTests

- (void)setUp
{
    [super setUp];
    
    coreDataController = [[CoreDataController alloc] initWithInitialType:NSInMemoryStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:nil dataStoreName:nil];
    contactDataController = [[ContactDataController alloc] initWithCoreDataController:coreDataController];
    [contactDataController addObserver:self forKeyPath:@"contacts" options:NSKeyValueObservingOptionNew context:NULL];
    
    contactsChanged = NO;
}

- (void)tearDown
{
    [contactDataController removeObserver:self forKeyPath:@"contacts"];
    [contactDataController release];
    contactDataController = nil;
    
    [coreDataController release];
    coreDataController = nil;
    
    [super tearDown];
}

- (void)testShouldFireChangeForContactsWhenAddingNewContact
{
    [contactDataController createContact];
    
    STAssertTrue(contactsChanged, @"Adding new contact should fire change for contacts");
}

- (void)testShouldFireChangeForContactsWhenDeletingContact
{
    Contact *contact = [contactDataController createContact];
    contactsChanged = NO;
    
    [contactDataController deleteContact:contact];
    
    STAssertTrue(contactsChanged, @"Adding new contact should fire change for contacts");
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	contactsChanged = YES;
}

@end
