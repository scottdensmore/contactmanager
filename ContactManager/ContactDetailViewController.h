//
//  ContactDetailViewController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/20/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Contact;

@interface ContactDetailViewController : NSViewController 

@property (nonatomic, assign) IBOutlet NSTextField *firstNameTextField;
@property (nonatomic, assign) IBOutlet NSTextField *lastNameTextField;
@property (nonatomic, assign) IBOutlet NSTextField *emailTextField;
@property (nonatomic, assign) IBOutlet NSTextField *phoneNumberTextField;
@property (nonatomic, assign) IBOutlet NSObjectController *contactObjectController;

@property (nonatomic, strong) Contact *contact;

@end
