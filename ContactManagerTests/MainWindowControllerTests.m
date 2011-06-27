//
//  MainWindowControllerTests.m
//  ContactManager
//
//  Created by Scott Densmore on 6/26/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "MainWindowControllerTests.h"
#import "ContactDataController.h"
#import <OCMock/OCMock.h>
#import "ContactListViewController.h"
#import "ContactDetailViewController.h"
#import "MainWindowController.h"

@implementation MainWindowControllerTests

- (void)setUp
{
    [super setUp];
    id contactDataController = [OCMockObject mockForClass:ContactDataController.class];
    [[[contactDataController stub] andReturn:nil] contacts];
    
    mainWindowController = [[MainWindowController alloc] initWithContactDataController:contactDataController];
    window = mainWindowController.window;
}

- (void)tearDown
{
    [mainWindowController release];
    mainWindowController = nil;
    
    window = nil;
    [super tearDown];
}

- (void)testShouldHaveValidNibName
{
    STAssertEqualObjects(mainWindowController.windowNibName, @"MainWindowController",
                         @"The nib for this window should be MainWindowController.xib");
}

- (void)testShouldLoadWindow
{
    STAssertNotNil(window, @"The window should be connected to the window controller.");
}

- (void)testShouldReceiveNewContactActionFromAddButton
{
    STAssertTrue([self checkControl:mainWindowController.addButton
                        sendsAction:@selector(newContact:)
                           toTarget:mainWindowController],
                 @"The Add button's action should send -newcontact: to the controller.");
}

- (void)testShouldReceiveDeleteContactActionFromRemoveButton
{
    STAssertTrue([self checkControl:mainWindowController.removeButton
                        sendsAction:@selector(deleteContact:)
                           toTarget:mainWindowController],
                 @"The Remvoe button's action should send -deletecontact: to the controller.");
}

- (void)testShouldObserveContactListViewControllerSelectedContact 
{
    id contactDetailViewController = [OCMockObject mockForClass:ContactDetailViewController.class];
    [[contactDetailViewController expect] setContact:nil];
    mainWindowController.contactDetailViewController = contactDetailViewController;
    
    [mainWindowController.contactListViewController selectContact:nil];
    
    [contactDetailViewController verify];
}

@end
