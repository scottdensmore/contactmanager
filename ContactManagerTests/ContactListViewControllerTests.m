//
//  ContactListViewControllerTests.m
//  ContactManager
//
//  Created by Scott Densmore on 6/26/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "ContactListViewControllerTests.h"
#import <OCMock/OCMock.h>
#import "ContactDataController.h"
#import "ContactListViewController.h"
#import "MainWindowController.h"

@implementation ContactListViewControllerTests

- (void)setUp
{
    [super setUp];
    /*
    CoreDataController *coreDataController = [[[CoreDataController alloc] initWithInitialType:NSInMemoryStoreType appSupportName:nil modelName:@"ContactManagerModel.momd" dataStoreName:nil] autorelease];
    ContactDataController *contactDataController = [[[ContactDataController alloc] initWithCoreDataController:coreDataController] autorelease];

    //NSMutableArray *contactsToReturn = [NSMutableArray array];
    NSArray *contacts = [[[NSBundle bundleForClass:ContactListViewControllerTests.class] infoDictionary] valueForKey:@"Contacts"];
	for (NSDictionary *contactDict in contacts) { 
        Contact *contact = [contactDataController createContact];
		[contact setFirstName:[contactDict valueForKey:@"firstName"]];
        [contact setLastName:[contactDict valueForKey:@"lastName"]];
        [contact setPhoneNumber:[contactDict valueForKey:@"phoneNumber"]];
		[contact setEmailAddress:[contactDict valueForKey:@"emailAddress"]];
        //[contactsToReturn addObject:contact];
	}
    */
    
    id contactDataController = [OCMockObject mockForClass:ContactDataController.class];
    [[[contactDataController stub] andReturn:nil] contacts];
    
    mainWindowController = [[MainWindowController alloc] initWithContactDataController:contactDataController];
    window = mainWindowController.window;
    contactListViewController = mainWindowController.contactListViewController;
}

- (void)tearDown
{
    [mainWindowController release];
    mainWindowController = nil;
    contactListViewController = nil;
    
    [super tearDown];
}

- (void)testShouldHaveValidNibName
{
    STAssertEqualObjects(contactListViewController.nibName, @"ContactListViewController",
                         @"The nib for this view should be ContactListViewController.xib");
}

- (void)testShouldBeTableViewDelegate
{
    STAssertTrue([self checkOutlet:[contactListViewController.tableView delegate]
                        connectsTo:contactListViewController],
                 @"The table view's delegate should be the view controller.");
}

- (void)testShouldBindContactsToArrayControllerContent
{
    NSArrayController *contactsArrayController = contactListViewController.contactsArrayController;
    
    STAssertTrue([self checkObject:contactsArrayController hasBinding:NSContentArrayBinding 
                          toObject:contactListViewController through:@"contacts"],
                 @"Bind contacts array controller content value to the controller's 'contacts' key path.");
}


- (void)testShouldBindSelectedObjectFromArrayControllerToFirstNameColumn
{
    NSArrayController *contactsArrayController = contactListViewController.contactsArrayController;
    NSTableColumn *firstNameColumn = [contactListViewController.tableView tableColumnWithIdentifier:@"First"];
    
    STAssertTrue([self checkObject:firstNameColumn hasBinding:NSValueBinding
                          toObject:contactsArrayController through:@"arrangedObjects.firstName"],
                 @"Bind first name column value to the contacts array controller's 'arrangedObjects.firstName' key path.");
}

- (void)testShouldBindSelectedObjectFromArrayControllerToLastNameColumn
{
    NSArrayController *contactsArrayController = contactListViewController.contactsArrayController;
    NSTableColumn *lastNameColumn = [contactListViewController.tableView tableColumnWithIdentifier:@"Last"];
    
    STAssertTrue([self checkObject:lastNameColumn hasBinding:NSValueBinding
                          toObject:contactsArrayController through:@"arrangedObjects.lastName"],
                 @"Bind last name column value to the contacts array controller's 'arrangedObjects.lastName' key path.");
}

@end
