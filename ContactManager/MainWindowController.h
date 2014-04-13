//
//  MainWindowController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/13/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ContactDataController;
@class ContactListViewController;
@class ContactDetailViewController;

@interface MainWindowController : NSWindowController

@property (nonatomic, assign) IBOutlet NSView *listView;
@property (nonatomic, assign) IBOutlet NSView *detailView;
@property (nonatomic, assign) IBOutlet NSButton *removeButton;
@property (nonatomic, assign) IBOutlet NSButton *addButton;

@property (nonatomic, strong) ContactListViewController *contactListViewController;
@property (nonatomic, strong) ContactDetailViewController *contactDetailViewController;

- (id)initWithContactDataController:(ContactDataController *)controller;

- (IBAction)newContact:(id)sender;
- (IBAction)deleteContact:(id)sender;

@end
