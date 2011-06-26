//
//  NSManagedObjectModel+Extensions.h
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObjectModel(Extensions)

- (NSArray *)objectsInEntityWithContext:(NSManagedObjectContext *)context name:(NSString *)name predicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray *)descriptors;

- (NSManagedObject *)newObjectInEntityWithContext:(NSManagedObjectContext *)context name:(NSString *)name values:(NSDictionary *)values;

@end
