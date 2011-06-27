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
    NSView *listView;
	NSView *detailView;
    NSButton *removeButton;
    NSButton *addButton;
    ContactListViewController *contactListViewController;
    ContactDetailViewController *contactDetailViewController;
    ContactDataController *contactDataController;
}

@property (assign) IBOutlet NSView *listView;
@property (assign) IBOutlet NSView *detailView;
@property (assign) IBOutlet NSButton *removeButton;
@property (assign) IBOutlet NSButton *addButton;
@property (nonatomic, retain) ContactListViewController *contactListViewController;
@property (nonatomic, retain) ContactDetailViewController *contactDetailViewController;


- (id)initWithContactDataController:(ContactDataController *)controller;

- (IBAction)newContact:(id)sender;
- (IBAction)deleteContact:(id)sender;

@end
