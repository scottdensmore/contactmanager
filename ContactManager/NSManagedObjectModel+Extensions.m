//
//  NSManagedObjectModel+Extensions.m
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "NSManagedObjectModel+Extensions.h"


@implementation NSManagedObjectModel(Extensions)

- (NSArray *)objectsInEntityWithContext:(NSManagedObjectContext *)context name:(NSString *)name predicate:(NSPredicate *)predicate sortedWithDescriptors:(NSArray *)descriptors
{
    if (!context || !name) {
		return nil;
	}
	
	NSEntityDescription *entity = [[self entitiesByName] objectForKey:name];
	
	//If our entity doesn't exist return nil
	if (!entity) {
		LOG(@"entity doesn't exist in entities:%@", [self entitiesByName]);
		return nil;
	}
	
	NSFetchRequest *request = [[NSFetchRequest alloc] init];
	
	[request setEntity:entity];
	[request setPredicate:predicate];
	[request setSortDescriptors:descriptors];
	
	NSError *error = nil;
	NSArray *results = [context executeFetchRequest:request error:&error];
	[request release];
	
	//If there was an error then return nothing
	if (error) {
		LOG(@"error:%@", error);
		return nil;
	}
	
	return results;
}

- (NSManagedObject *)newObjectInEntityWithContext:(NSManagedObjectContext *)context name:(NSString *)name values:(NSDictionary *)values
{
    if (!context || !name) {
		return nil;
	}
	
	NSEntityDescription *entity = [[self entitiesByName] objectForKey:name];
	
	//If our entity doesn't exist return nil
	if (!entity) {
		return nil;
	}
	
	NSManagedObject *object = [[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:context];
	
	if (!object) {
		return nil;
	}
	
	for (NSString *key in [values allKeys]) {
		[object setValue:[values objectForKey:key] forKey:key];
	}
	return object;

}

@end
