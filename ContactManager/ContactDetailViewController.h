//
//  ContactDetailViewController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/20/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class Contact;

@interface ContactDetailViewController : NSViewController 

@property (nonatomic, weak, nullable) IBOutlet NSTextField *firstNameTextField;
@property (nonatomic, weak, nullable) IBOutlet NSTextField *lastNameTextField;
@property (nonatomic, weak, nullable) IBOutlet NSTextField *emailTextField;
@property (nonatomic, weak, nullable) IBOutlet NSTextField *phoneNumberTextField;
@property (nonatomic, weak, nullable) IBOutlet NSObjectController *contactObjectController;

@property (nonatomic, strong, nullable) Contact *contact;

@end

NS_ASSUME_NONNULL_END

