//
//  MainWindowControllerTests.m
//  ContactManager
//
//  Created by Scott Densmore on 6/26/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <OCMock/OCMock.h>

#import "BaseTestCase.h"
#import "ContactDataController.h"
#import "ContactListViewController.h"
#import "ContactDetailViewController.h"
#import "MainWindowController.h"

@interface MainWindowControllerTests : BaseTestCase

@property (nonatomic, strong) MainWindowController *mainWindowController;
@property (nonatomic, assign) NSWindow *window;

@end

@implementation MainWindowControllerTests

- (void)setUp
{
    [super setUp];
    id contactDataController = [OCMockObject mockForClass:ContactDataController.class];
    [[[contactDataController stub] andReturn:nil] contacts];
    
    _mainWindowController = [[MainWindowController alloc] initWithContactDataController:contactDataController];
    _window = _mainWindowController.window;
}

- (void)tearDown
{
    [_mainWindowController close];
    _mainWindowController = nil;
    
    _window = nil;
    [super tearDown];
}

#pragma mark - MainWindowController tests

- (void)testShouldHaveValidNibName
{
    XCTAssertEqualObjects(_mainWindowController.windowNibName, @"MainWindowController",
                         @"The nib for this window should be MainWindowController.xib");
}

- (void)testShouldLoadWindow
{
    XCTAssertNotNil(_window, @"The window should be connected to the window controller.");
}

- (void)testShouldConnectListView
{
    XCTAssertNotNil(_mainWindowController.listView, @"The list view should be connected to the window controller.");
}

- (void)testShouldConnectDetailView
{
    XCTAssertNotNil(_mainWindowController.detailView, @"The detail view should be connected to the window controller.");
}

- (void)testShouldReceiveNewContactActionFromAddButton
{
    XCTAssertTrue([self checkControl:_mainWindowController.addButton
                        sendsAction:@selector(newContact:)
                           toTarget:_mainWindowController],
                 @"The Add button's action should send -newcontact: to the controller.");
}

- (void)testShouldReceiveDeleteContactActionFromRemoveButton
{
    XCTAssertTrue([self checkControl:_mainWindowController.removeButton
                        sendsAction:@selector(deleteContact:)
                           toTarget:_mainWindowController],
                 @"The Remvoe button's action should send -deletecontact: to the controller.");
}

- (void)testShouldObserveContactListViewControllerSelectedContact 
{
    id contactDetailViewController = [OCMockObject mockForClass:ContactDetailViewController.class];
    [[contactDetailViewController expect] setContact:nil];
    _mainWindowController.contactDetailViewController = contactDetailViewController;
    
    [_mainWindowController.contactListViewController selectContact:nil];
    
    [contactDetailViewController verify];
}

@end
