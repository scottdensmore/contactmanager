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

@interface MainWindowController()

@property (nonatomic, strong) ContactDataController *contactDataController;

@end

@implementation MainWindowController


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
        _contactDataController = controller;
        _contactListViewController = [[ContactListViewController alloc] initWithContactDataController:_contactDataController];
        _contactDetailViewController = [[ContactDetailViewController alloc] init];
        [_contactListViewController addObserver:self forKeyPath:@"selectedContact" options:NSKeyValueObservingOptionNew context:NULL];
    }
    return self;
}


- (void)dealloc
{
    [_contactListViewController removeObserver:self forKeyPath:@"selectedContact"];
}

#pragma mark - Windows methods

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [[_contactListViewController view] setFrame:[_listView bounds]];
    [_listView addSubview:[_contactListViewController view]];
    
    [[_contactDetailViewController view] setFrame:[_detailView bounds]];
    [_detailView addSubview:[_contactDetailViewController view]];
    [_contactDetailViewController setContact:[_contactListViewController selectedContact]];
}

- (NSString *)windowNibName 
{
    return NSStringFromClass([self class]);
}

#pragma mark - KVO methods

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[_contactDetailViewController setContact:[_contactListViewController selectedContact]];
}

#pragma mark - Action methods

- (IBAction)newContact:(id)sender
{
    Contact *newContact = [_contactDataController createContact];
	[_contactListViewController reloadData];
	[_contactListViewController selectContact:newContact];
}

- (IBAction)deleteContact:(id)sender
{
    Contact *contact = [_contactListViewController selectedContact];
    if (contact) {
        [_contactDataController deleteContact:contact];
    }
	[_contactListViewController reloadData];
}


@end
