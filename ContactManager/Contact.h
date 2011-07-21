//
//  Contact.h
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright (c) 2011 Scott Densmore. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Contact : NSManagedObject {
@private
}
@property (nonatomic, retain) NSString * firstName;
@property (nonatomic, retain) NSString * lastName;
@property (nonatomic, retain) NSString * emailAddress;
@property (nonatomic, retain) NSString * phoneNumber;

@end
