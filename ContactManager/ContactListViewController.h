//
//  ContactListViewController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/14/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class ContactDataController;
@class Contact;

@interface ContactListViewController : NSViewController <NSTableViewDelegate>

@property (nonatomic, weak, nullable) IBOutlet NSArrayController *contactsArrayController;
@property (nonatomic, weak, nullable) IBOutlet NSTableView *tableView;
@property (nonatomic, readonly, copy) NSArray<Contact *> *contacts;

- (instancetype)initWithContactDataController:(ContactDataController *)controller;

- (nullable Contact *)selectedContact;
- (void)selectContact:(nullable Contact *)contact;
- (void)reloadData;

@end

NS_ASSUME_NONNULL_END

