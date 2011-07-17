//
//  ContactDataControllerTests.m
//  ContactManager
//
//  Created by Scott Densmore on 6/26/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "ContactDataControllerTests.h"
#import "CoreDataController.h"
#import "ContactDataController.h"
#import "Contact.h"

@implementation ContactDataControllerTests

- (void)setUp
{
    [super setUp];
    
    coreDataController = [[CoreDataController alloc] initWithInitialType:NSInMemoryStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:nil dataStoreName:nil];
    contactDataController = [[ContactDataController alloc] initWithCoreDataController:coreDataController];
}

- (void)tearDown
{
    [contactDataController release];
    contactDataController = nil;
    
    [coreDataController release];
    coreDataController = nil;
    
    [super tearDown];
}

- (void)testShouldCreateNewNonNilContact
{
    Contact *contact = [contactDataController createContact];
    
    STAssertNotNil(contact, @"Contact should not be nil");
}

- (void)testShouldBeAbleRetrieveNewContact
{
    Contact *contact = [contactDataController createContact];
    contact.firstName = @"Scott";
    contact.lastName = @"Densmore";
    contact = nil;
    
    contact = [[contactDataController contacts] objectAtIndex:0];
    
    STAssertNotNil(contact, @"Could not find inserted contact");
    STAssertEqualObjects(@"Scott", contact.firstName, @"Contact firstName did not match");
    STAssertEqualObjects(@"Densmore", contact.lastName, @"Contact firstName did not match");
}

- (void)testShouldRetrieveContactsInLastNameOrder
{
    for (int idx = 4; idx >= 0; idx--) {
        Contact *contact = [contactDataController createContact];
        contact.firstName = [NSString stringWithFormat:@"%d First", idx];
        contact.lastName = [NSString stringWithFormat:@"%d Last", idx];
    }
    
    NSArray *contacts = [contactDataController contacts];
    
    for (int idx = 0; idx < 5; idx++) {
        Contact *contact = [contacts objectAtIndex:idx];
        NSString *expectedLastName = [NSString stringWithFormat:@"%d Last", idx];
        STAssertEqualObjects(expectedLastName, contact.lastName, @"Did not get contacts ordered by last name");
    }
}

- (void)testShouldBeAbleToDeleteContactAfterInserting
{
    Contact *contact = [contactDataController createContact];
    contact.firstName = @"Scott";
    contact.lastName = @"Densmore";

    [contactDataController deleteContact:contact];
    NSUInteger contactCount = [[contactDataController contacts] count];
    
    STAssertEquals((NSUInteger)0, contactCount, @"Did not delete contact");
}
@end
