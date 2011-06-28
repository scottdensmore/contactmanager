//
//  MainWindowController.m
//  ContactManager
//
//  Created by Scott Densmore on 6/13/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "MainWindowController.h"
#import "ContactDataController.h"
#import "ContactListViewController.h"
#import "ContactDetailViewController.h"

@implementation MainWindowController

#pragma mark - Accessors

@synthesize listView;
@synthesize detailView;
@synthesize removeButton;
@synthesize contactListViewController;
@synthesize contactDetailViewController;
@synthesize addButton;

#pragma mark - Memory Management

- (id)init
{
    return [self initWithContactDataController:nil];
}

- (id)initWithContactDataController:(ContactDataController *)controller
{
    NSParameterAssert(controller != nil);
    
    self = [super initWithWindowNibName:@"MainWindowController"];
    if (self) {
        contactDataController = [controller retain];
        contactListViewController = [[ContactListViewController alloc] initWithContactDataController:contactDataController];
        contactDetailViewController = [[ContactDetailViewController alloc] init];
        [contactListViewController addObserver:self forKeyPath:@"selectedContact" options:NSKeyValueObservingOptionNew context:NULL];
    }
    return self;
}


- (void)dealloc
{
    [contactListViewController removeObserver:self forKeyPath:@"selectedContact"];
    
    RELEASE(contactListViewController);
    RELEASE(contactDetailViewController);
    RELEASE(contactDataController);
    
    [super dealloc];
}

#pragma mark - Windows methods

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [[contactListViewController view] setFrame:[listView bounds]];
    [listView addSubview:[contactListViewController view]];
    
    [[contactDetailViewController view] setFrame:[detailView bounds]];
    [detailView addSubview:[contactDetailViewController view]];
    [contactDetailViewController setContact:[contactListViewController selectedContact]];
}

- (NSString *)windowNibName 
{
    return NSStringFromClass([self class]);
}

#pragma mark - KVO methods

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[contactDetailViewController setContact:[contactListViewController selectedContact]];
}

#pragma mark - Action methods

- (IBAction)newContact:(id)sender
{
    Contact *newContact = [contactDataController createContact];
	[contactListViewController reloadData];
	[contactListViewController selectContact:newContact];
}

- (IBAction)deleteContact:(id)sender
{
    Contact *contact = [contactListViewController selectedContact];
    if (contact) {
        [contactDataController deleteContact:contact];
    }
	[contactListViewController reloadData];
}


@end
