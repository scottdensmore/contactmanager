//
//  ContactDetailViewController.m
//  ContactManager
//
//  Created by Scott Densmore on 6/20/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "ContactDetailViewController.h"
#import "Contact.h"

@interface ContactDetailViewController ()

- (void)updateFieldVisibility;

@end

@implementation ContactDetailViewController

@synthesize contact = _contact;

#pragma mark - View methods

- (NSString *)nibName
{
    return NSStringFromClass([self class]);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self updateFieldVisibility];
}

- (void)setContact:(Contact * _Nullable)contact
{
    if (_contact != contact) {
        _contact = contact;
        if (self.isViewLoaded) {
            [self updateFieldVisibility];
        }
    }
}

- (void)updateFieldVisibility
{
    BOOL hasContact = (self.contact != nil);
    
    for (NSView *subview in self.view.subviews) {
        subview.hidden = !hasContact;
    }
}

@end
