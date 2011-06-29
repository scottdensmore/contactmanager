//
//  ContactDetailViewControllerTests.h
//  ContactManager
//
//  Created by Scott Densmore on 6/27/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "BaseTestCase.h"

@class MainWindowController;
@class ContactDetailViewController;

@interface ContactDetailViewControllerTests : BaseTestCase {
@private
    MainWindowController *mainWindowController;
    NSWindow *window;
    ContactDetailViewController *contactDetailViewController;
}

@end
