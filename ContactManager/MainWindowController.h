//
//  MainWindowController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/13/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class ContactListViewController;
@class ContactDetailViewController;
@class ContactDataController;

@interface MainWindowController : NSWindowController {
@private
    IBOutlet NSView *listView;
	IBOutlet NSView *detailView;
    ContactListViewController *contactListViewController;
    ContactDetailViewController *contactDetailViewController;
    ContactDataController *contactDataController;
}

@property (nonatomic, retain) IBOutlet NSView *listView;
@property (nonatomic, retain) IBOutlet NSView *detailView;
@property (nonatomic, retain) ContactListViewController *contactListViewController;
@property (nonatomic, retain) ContactDetailViewController *contactDetailViewController;

- (id)initWithContactDataController:(ContactDataController *)controller;

- (IBAction)newContact:(id)sender;

@end
