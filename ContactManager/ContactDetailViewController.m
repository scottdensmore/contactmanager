//
//  ContactDetailViewController.m
//  ContactManager
//
//  Created by Scott Densmore on 6/20/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "ContactDetailViewController.h"
#import "Contact.h"

@implementation ContactDetailViewController

#pragma mark - Accessors

@synthesize contact;
@synthesize firstNameTextField;
@synthesize lastNameTextField;
@synthesize emailTextField;
@synthesize phoneNumberTextField;
@synthesize contactObjectController;

#pragma mark - Memory Management

- (void)dealloc
{
    RELEASE(contact);
    
    [super dealloc];
}

#pragma mark - View methods

- (NSString *)nibName
{
    return NSStringFromClass([self class]);
}


@end
