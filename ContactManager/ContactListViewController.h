//
//  ContactListViewController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/14/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ContactDataController;
@class Contact;

@interface ContactListViewController : NSViewController <NSTableViewDelegate> {
@private
    NSArrayController *contactsArrayController;
    ContactDataController *contactController;
}

@property (assign) IBOutlet NSArrayController *contactsArrayController;
@property (nonatomic, readonly) NSArray *contacts;

- (id)initWithContactDataController:(ContactDataController *)controller;

- (Contact *)selectedContact;
- (void)selectContact:(Contact *)contact;
- (void)reloadData;

@end
