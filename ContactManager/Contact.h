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

@property (nonatomic, strong, nullable) NSString *firstName;
@property (nonatomic, strong, nullable) NSString *lastName;
@property (nonatomic, strong, nullable) NSString *emailAddress;
@property (nonatomic, strong, nullable) NSString *phoneNumber;

@end

NS_ASSUME_NONNULL_END

