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

@implementation ContactListViewController

@synthesize contactsArrayController;

#pragma mark - Memory Management

- (id)init 
{
    return [self initWithContactDataController:nil];
}

- (id)initWithContactDataController:(ContactDataController *)controller 
{
    NSAssert(controller != nil, @"The controller should not be nil. Make sure to use initWithContactDataController: initializer.");
    
    self = [super init];
    if (self) {
        contactController = [controller retain];
    }
    return self;
}

- (void)dealloc
{
    RELEASE(contactsArrayController);
    RELEASE(contactController);
    
    [super dealloc];
}

#pragma mark - Accessors

- (NSArray *)contacts
{
    return [contactController contacts];
}

#pragma mark - Methods

- (Contact *)selectedContact
{
	if ([[contactsArrayController selectedObjects] count]) {
		return [[contactsArrayController selectedObjects] objectAtIndex:0];
	}
	return nil;
}

- (void)selectContact:(Contact *)contact
{
    [self willChangeValueForKey:@"selectedContact"];
    [contactsArrayController setSelectedObjects:[NSArray arrayWithObject:contact]];
    [self didChangeValueForKey:@"selectedContact"];
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
