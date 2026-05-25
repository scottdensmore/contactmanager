//
//  MainWindowController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/13/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class ContactDataController;
@class ContactListViewController;
@class ContactDetailViewController;

@interface MainWindowController : NSWindowController

@property (nonatomic, weak, nullable) IBOutlet NSView *listView;
@property (nonatomic, weak, nullable) IBOutlet NSView *detailView;
@property (nonatomic, weak, nullable) IBOutlet NSButton *removeButton;
@property (nonatomic, weak, nullable) IBOutlet NSButton *addButton;

@property (nonatomic, strong) ContactListViewController *contactListViewController;
@property (nonatomic, strong) ContactDetailViewController *contactDetailViewController;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithContactDataController:(ContactDataController *)controller;

- (IBAction)newContact:(id)sender;
- (IBAction)deleteContact:(id)sender;

@end

NS_ASSUME_NONNULL_END

