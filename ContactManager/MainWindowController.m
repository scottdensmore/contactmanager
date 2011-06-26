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
@synthesize contactListViewController;
@synthesize contactDetailViewController;

#pragma mark - Memory Management

- (id)init
{
    return [self initWithContactDataController:nil];
}

- (id)initWithContactDataController:(ContactDataController *)controller
{
    NSAssert(controller != nil, @"The controller should not be nil. Make sure to use initWithContactDataController: initializer.");
    
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
    RELEASE(listView);
    RELEASE(detailView);
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[contactDetailViewController setContact:[contactListViewController selectedContact]];
}

#pragma mark - Action methods
- (IBAction)newContact:(id)sender
{
    Contact *newContact = [contactDataController newContact];
	[contactListViewController reloadData];
	[contactListViewController selectContact:newContact];
}

@end
