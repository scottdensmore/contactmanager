//
//  ContactListViewControllerTests.h
//  ContactManager
//
//  Created by Scott Densmore on 6/26/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "BaseTestCase.h"

@class MainWindowController;
@class ContactListViewController;

@interface ContactListViewControllerTests : BaseTestCase {
@private
    MainWindowController *mainWindowController;
    NSWindow *window;
    ContactListViewController *contactListViewController;
}

@end
