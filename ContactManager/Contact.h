//
//  Contact.h
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright (c) 2011 Scott Densmore. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface Contact : NSManagedObject

@property (nonatomic, copy, nullable) NSString *firstName;
@property (nonatomic, copy, nullable) NSString *lastName;
@property (nonatomic, copy, nullable) NSString *emailAddress;
@property (nonatomic, copy, nullable) NSString *phoneNumber;

@end

NS_ASSUME_NONNULL_END

