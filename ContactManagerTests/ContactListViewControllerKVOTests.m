//
//  ContactListViewControllerKVOTests.m
//  ContactManager
//
//  Created by Scott Densmore on 6/27/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "ContactListViewControllerKVOTests.h"
#import <OCMock/OCMock.h>
#import "ContactDataController.h"
#import "ContactListViewController.h"
#import "MainWindowController.h"

@implementation ContactListViewControllerKVOTests

- (void)setUp
{
    [super setUp];
    
    id contactDataController = [OCMockObject mockForClass:ContactDataController.class];
    [[[contactDataController stub] andReturn:nil] contacts];
    
    mainWindowController = [[MainWindowController alloc] initWithContactDataController:contactDataController];
    window = mainWindowController.window;
    contactListViewController = mainWindowController.contactListViewController;
    
    [contactListViewController addObserver:self forKeyPath:@"selectedContact" options:NSKeyValueObservingOptionNew context:NULL];
    [contactListViewController addObserver:self forKeyPath:@"contacts" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)tearDown
{
    [contactListViewController removeObserver:self forKeyPath:@"selectedContact"];
    [contactListViewController removeObserver:self forKeyPath:@"contacts"];

    [mainWindowController release];
    mainWindowController = nil;
    contactListViewController = nil;
    
    [observedKeyPath release];
    observedKeyPath = nil;
    [observedChange release];
    observedChange = nil;
    observedObject = nil;
    
    [super tearDown];
}

- (void)testShouldNotifySelectedContactWhenSelectingContact
{
    [contactListViewController selectContact:nil];
    
    STAssertEquals(contactListViewController, observedObject, @"The observed object should be the contact list view controller.");
    STAssertEqualObjects(@"selectedContact", observedKeyPath, @"The observed key path should be 'selectedContact'.");
    STAssertEqualObjects([NSNull null], [observedChange valueForKey:NSKeyValueChangeNewKey], @"The observed value should be NSNull.");
}

- (void)testShouldNotifyContactsWhenReloadData
{
    [contactListViewController reloadData];
    
    STAssertEquals(contactListViewController, observedObject, @"The observed object should be the contact list view controller.");
    STAssertEqualObjects(@"contacts", observedKeyPath, @"The observed key path should be 'selectedContact'.");
    STAssertEqualObjects([NSNull null], [observedChange valueForKey:NSKeyValueChangeNewKey], @"The observed value should be NSNull.");
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    observedKeyPath = [keyPath retain];
    observedObject = object;
    observedChange = [[NSDictionary dictionaryWithDictionary:change] retain];
}

@end
