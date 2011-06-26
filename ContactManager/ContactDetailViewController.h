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
}

@property (nonatomic, retain) Contact *contact;

@end
