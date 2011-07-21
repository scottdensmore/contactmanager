//
//  ContactDetailViewController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/20/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Contact;

@interface ContactDetailViewController : NSViewController {
@private
    Contact *contact;
    NSTextField *firstNameTextField;
    NSTextField *lastNameTextField;
    NSTextField *emailTextField;
    NSTextField *phoneNumberTextField;
    NSObjectController *contactObjectController;
}

@property (nonatomic, retain) Contact *contact;
@property (assign) IBOutlet NSTextField *firstNameTextField;
@property (assign) IBOutlet NSTextField *lastNameTextField;
@property (assign) IBOutlet NSTextField *emailTextField;
@property (assign) IBOutlet NSTextField *phoneNumberTextField;
@property (assign) IBOutlet NSObjectController *contactObjectController;

@end
