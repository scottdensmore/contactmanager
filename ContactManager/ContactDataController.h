//
//  ContactDataController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Contact;
@class CoreDataController;

@interface ContactDataController : NSObject

@property (nonatomic, readonly, strong) NSArray *contacts;

- (id)initWithCoreDataController:(CoreDataController *)controller;

- (Contact *)createContact;
- (void)deleteContact:(Contact *)contact;

@end
