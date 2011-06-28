//
//  ContactListViewControllerKVOTests.h
//  ContactManager
//
//  Created by Scott Densmore on 6/27/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

@class MainWindowController;
@class ContactListViewController;

@interface ContactListViewControllerKVOTests : SenTestCase {
@private
    MainWindowController *mainWindowController;
    NSWindow *window;
    ContactListViewController *contactListViewController;
    NSString *observedKeyPath;
    id observedObject;
    NSDictionary *observedChange;
}

@end
