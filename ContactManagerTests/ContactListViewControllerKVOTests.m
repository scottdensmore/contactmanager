//
//  ContactListViewControllerKVOTests.m
//  ContactManager
//
//  Created by Scott Densmore on 6/27/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "ContactDataController.h"
#import "ContactListViewController.h"
#import "MainWindowController.h"

@interface ContactListViewControllerKVOTests : XCTestCase 

@property (nonatomic, strong) MainWindowController *mainWindowController;
@property (nonatomic, assign) NSWindow *window;
@property (nonatomic, assign) ContactListViewController *contactListViewController;
@property (nonatomic, strong) NSString *observedKeyPath;
@property (nonatomic, strong) id observedObject;
@property (nonatomic, strong) NSDictionary *observedChange;

@end

@implementation ContactListViewControllerKVOTests

- (void)setUp
{
    [super setUp];
    
    id contactDataController = [OCMockObject mockForClass:ContactDataController.class];
    [[[contactDataController stub] andReturn:nil] contacts];
    
    _mainWindowController = [[MainWindowController alloc] initWithContactDataController:contactDataController];
    _window = _mainWindowController.window;
    _contactListViewController = _mainWindowController.contactListViewController;
    
    [_contactListViewController addObserver:self forKeyPath:@"selectedContact" options:NSKeyValueObservingOptionNew context:NULL];
    [_contactListViewController addObserver:self forKeyPath:@"contacts" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)tearDown
{
    [_contactListViewController removeObserver:self forKeyPath:@"selectedContact"];
    [_contactListViewController removeObserver:self forKeyPath:@"contacts"];

    _mainWindowController = nil;
    _contactListViewController = nil;
    
    _observedKeyPath = nil;
    _observedChange = nil;
    _observedObject = nil;
    
    [super tearDown];
}

- (void)testShouldNotifySelectedContactWhenSelectingContact
{
    [_contactListViewController selectContact:nil];
    
    XCTAssertEqual(_contactListViewController, _observedObject, @"The observed object should be the contact list view controller.");
    XCTAssertEqualObjects(@"selectedContact", _observedKeyPath, @"The observed key path should be 'selectedContact'.");
    XCTAssertEqualObjects([NSNull null], [_observedChange valueForKey:NSKeyValueChangeNewKey], @"The observed value should be NSNull.");
}

- (void)testShouldNotifyContactsWhenReloadData
{
    [_contactListViewController reloadData];
    
    XCTAssertEqual(_contactListViewController, _observedObject, @"The observed object should be the contact list view controller.");
    XCTAssertEqualObjects(@"contacts", _observedKeyPath, @"The observed key path should be 'selectedContact'.");
    XCTAssertEqualObjects([NSNull null], [_observedChange valueForKey:NSKeyValueChangeNewKey], @"The observed value should be NSNull.");
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    _observedKeyPath = keyPath;
    _observedObject = object;
    _observedChange = [NSDictionary dictionaryWithDictionary:change];
}

@end
