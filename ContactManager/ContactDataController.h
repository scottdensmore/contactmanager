//
//  ContactDataController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class Contact;
@class CoreDataController;

@interface ContactDataController : NSObject

@property (nonatomic, readonly, copy) NSArray<Contact *> *contacts;

- (instancetype)initWithCoreDataController:(CoreDataController *)controller;

- (Contact *)createContact;
- (void)deleteContact:(Contact *)contact;

@end

NS_ASSUME_NONNULL_END

