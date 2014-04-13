//
//  ContactDataControllerTests.m
//  ContactManager
//
//  Created by Scott Densmore on 6/26/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CoreDataController.h"
#import "ContactDataController.h"
#import "Contact.h"

@interface ContactDataControllerTests : XCTestCase

@property (nonatomic, strong) CoreDataController *coreDataController;
@property (nonatomic, strong) ContactDataController *contactDataController;

@end

@implementation ContactDataControllerTests

- (void)setUp
{
    [super setUp];
    
    _coreDataController = [[CoreDataController alloc] initWithInitialType:NSInMemoryStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:nil dataStoreName:nil];
    _contactDataController = [[ContactDataController alloc] initWithCoreDataController:_coreDataController];
}

- (void)tearDown
{
    _contactDataController = nil;
    _coreDataController = nil;
    
    [super tearDown];
}

- (void)testShouldCreateNewNonNilContact
{
    Contact *contact = [_contactDataController createContact];
    
    XCTAssertNotNil(contact, @"Contact should not be nil");
}

- (void)testShouldBeAbleRetrieveNewContact
{
    Contact *contact = [_contactDataController createContact];
    contact.firstName = @"Scott";
    contact.lastName = @"Densmore";
    contact = nil;
    
    contact = [_contactDataController contacts][0];
    
    XCTAssertNotNil(contact, @"Could not find inserted contact");
    XCTAssertEqualObjects(@"Scott", contact.firstName, @"Contact firstName did not match");
    XCTAssertEqualObjects(@"Densmore", contact.lastName, @"Contact firstName did not match");
}

- (void)testShouldRetrieveContactsInLastNameOrder
{
    for (int idx = 4; idx >= 0; idx--) {
        Contact *contact = [_contactDataController createContact];
        contact.firstName = [NSString stringWithFormat:@"%d First", idx];
        contact.lastName = [NSString stringWithFormat:@"%d Last", idx];
    }
    
    NSArray *contacts = [_contactDataController contacts];
    
    for (int idx = 0; idx < 5; idx++) {
        Contact *contact = contacts[idx];
        NSString *expectedLastName = [NSString stringWithFormat:@"%d Last", idx];
        XCTAssertEqualObjects(expectedLastName, contact.lastName, @"Did not get contacts ordered by last name");
    }
}

- (void)testShouldBeAbleToDeleteContactAfterInserting
{
    Contact *contact = [_contactDataController createContact];
    contact.firstName = @"Scott";
    contact.lastName = @"Densmore";

    [_contactDataController deleteContact:contact];
    NSUInteger contactCount = [[_contactDataController contacts] count];
    
    XCTAssertEqual((NSUInteger)0, contactCount, @"Did not delete contact");
}
@end
