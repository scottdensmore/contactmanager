//
//  ContactListViewController.m
//  ContactManager
//
//  Created by Scott Densmore on 6/14/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "ContactListViewController.h"
#import "ContactDataController.h"
#import "Contact.h"

@interface ContactListViewController()

@property (strong) ContactDataController *contactController;

@end

@implementation ContactListViewController

#pragma mark - Memory Management

- (id)init 
{
    return [self initWithContactDataController:nil];
}

- (id)initWithContactDataController:(ContactDataController *)controller 
{
    NSParameterAssert(controller != nil);
    
    self = [super init];
    if (self) {
        _contactController = controller;
    }
    return self;
}


#pragma mark - Accessors

- (NSArray *)contacts
{
    return [_contactController contacts];
}

#pragma mark - Methods

- (Contact *)selectedContact
{
	if ([[_contactsArrayController selectedObjects] count]) {
		return [_contactsArrayController selectedObjects][0];
	}
	return nil;
}

- (void)selectContact:(Contact *)contact
{
    BOOL valueChanged;
    if (contact) {
        valueChanged = [_contactsArrayController setSelectedObjects:@[contact]];
    } else {
        valueChanged = [_contactsArrayController setSelectedObjects:nil];
    }
    
    if (valueChanged) {
        [self willChangeValueForKey:@"selectedContact"];
        [self didChangeValueForKey:@"selectedContact"];
    }
}

- (void)reloadData 
{
	[self willChangeValueForKey:@"contacts"];
	[self didChangeValueForKey:@"contacts"];
}

#pragma mark - View methods

- (NSString *)nibName
{
    return NSStringFromClass([self class]);
}

#pragma mark - NSTableViewDelegate methods

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification 
{
	[self willChangeValueForKey:@"selectedContact"];
	[self didChangeValueForKey:@"selectedContact"];
}

@end
