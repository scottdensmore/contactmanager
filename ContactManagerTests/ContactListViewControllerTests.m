//
//  ContactListViewControllerTests.m
//  ContactManager
//
//  Created by Scott Densmore on 6/26/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "BaseTestCase.h"
#import <OCMock/OCMock.h>

#import "ContactDataController.h"
#import "ContactListViewController.h"
#import "MainWindowController.h"

@interface ContactListViewControllerTests : BaseTestCase

@property (nonatomic, strong) MainWindowController *mainWindowController;
@property (nonatomic, assign) NSWindow *window;
@property (nonatomic, assign) ContactListViewController *contactListViewController;

@end

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
    
    _mainWindowController = [[MainWindowController alloc] initWithContactDataController:contactDataController];
    _window = _mainWindowController.window;
    _contactListViewController = _mainWindowController.contactListViewController;
}

- (void)tearDown
{
    _mainWindowController = nil;
    _window = nil;
    _contactListViewController = nil;
    
    [super tearDown];
}

- (void)testShouldHaveValidNibName
{
    XCTAssertEqualObjects(_contactListViewController.nibName, @"ContactListViewController",
                         @"The nib for this view should be ContactListViewController.xib");
}

- (void)testShouldBeTableViewDelegate
{
    XCTAssertTrue([self checkOutlet:[_contactListViewController.tableView delegate]
                        connectsTo:_contactListViewController],
                 @"The table view's delegate should be the view controller.");
}

- (void)testShouldBindContactsToArrayControllerContent
{
    NSArrayController *contactsArrayController = _contactListViewController.contactsArrayController;
    
    XCTAssertTrue([self checkObject:contactsArrayController hasBinding:NSContentArrayBinding 
                          toObject:_contactListViewController through:@"contacts"],
                 @"Bind contacts array controller content value to the controller's 'contacts' key path.");
}


- (void)testShouldBindSelectedObjectFromArrayControllerToFirstNameColumn
{
    NSArrayController *contactsArrayController = _contactListViewController.contactsArrayController;
    NSTableColumn *firstNameColumn = [_contactListViewController.tableView tableColumnWithIdentifier:@"First"];
    
    XCTAssertTrue([self checkObject:firstNameColumn hasBinding:NSValueBinding
                          toObject:contactsArrayController through:@"arrangedObjects.firstName"],
                 @"Bind first name column value to the contacts array controller's 'arrangedObjects.firstName' key path.");
}

- (void)testShouldBindSelectedObjectFromArrayControllerToLastNameColumn
{
    NSArrayController *contactsArrayController = _contactListViewController.contactsArrayController;
    NSTableColumn *lastNameColumn = [_contactListViewController.tableView tableColumnWithIdentifier:@"Last"];
    
    XCTAssertTrue([self checkObject:lastNameColumn hasBinding:NSValueBinding
                          toObject:contactsArrayController through:@"arrangedObjects.lastName"],
                 @"Bind last name column value to the contacts array controller's 'arrangedObjects.lastName' key path.");
}

@end
