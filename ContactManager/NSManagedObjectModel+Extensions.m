//
//  NSManagedObjectModel+Extensions.m
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "NSManagedObjectModel+Extensions.h"


@implementation NSManagedObjectModel (Extensions)

- (nullable NSArray<__kindof NSManagedObject *> *)objectsInEntityWithContext:(NSManagedObjectContext *)context
                                                                      name:(NSString *)name
                                                                 predicate:(nullable NSPredicate *)predicate
                                                     sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)descriptors
{
    if (!context || !name) {
		return nil;
	}
	
	NSEntityDescription *entity = self.entitiesByName[name];
	if (!entity) {
		LOG(@"entity doesn't exist in entities:%@", self.entitiesByName);
		return nil;
	}
	
	NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:name];
	request.predicate = predicate;
	request.sortDescriptors = descriptors;
	
	NSError *error = nil;
	NSArray *results = [context executeFetchRequest:request error:&error];
	if (error) {
		LOG(@"error:%@", error);
		return nil;
	}
	
	return results;
}

- (nullable __kindof NSManagedObject *)insertNewObjectInEntityWithContext:(NSManagedObjectContext *)context
                                                                    name:(NSString *)name
                                                                  values:(nullable NSDictionary<NSString *, id> *)values
{
    if (!context || !name) {
		return nil;
	}
    
    NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:name inManagedObjectContext:context];
	if (!object) {
		return nil;
	}
	
	[values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
		[object setValue:obj forKey:key];
	}];
	return object;
}

@end
