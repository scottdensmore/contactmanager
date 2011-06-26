//
//  ContactDataController.m
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "ContactDataController.h"
#import "CoreDataController.h"
#import "NSManagedObjectModel+Extensions.h"
#import "Contact.h"

@implementation ContactDataController

#pragma mark - Memory Managements

- (id)init 
{
    return [self initWithCoreDataController:nil];
}

- (id)initWithCoreDataController:(CoreDataController *)controller
{
    NSAssert(controller != nil, @"The controller should not be nil. Make sure to use initWithCoreDataController: initializer.");
    
    self = [super init];
    if (self) {
        if (controller) {
            coreDataController = [controller retain];
        }
    }
    
    return self;
}

- (void)dealloc
{
    RELEASE(coreDataController);
    
    [super dealloc];
}


#pragma mark - Accessors

- (NSArray *)contacts
{
    return [coreDataController.managedObjectModel objectsInEntityWithContext:coreDataController.managedObjectContext  
                                                                        name:@"Contact" 
                                                                   predicate:nil 
                                                       sortedWithDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"lastName" ascending:YES]]];
}

#pragma mark - Data Methods

- (Contact *)newContact
{
    [self willChangeValueForKey:@"contacts"];
	Contact *post = (Contact *)[coreDataController.managedObjectModel newObjectInEntityWithContext:coreDataController.managedObjectContext 
                                                                                              name:@"Contact" 
                                                                                            values:nil];
	[self didChangeValueForKey:@"contacts"];
	return post;
}

- (void)deleteContact:(Contact *)contact
{
    [self willChangeValueForKey:@"contacts"];
	[coreDataController.managedObjectContext deleteObject:contact];
	[self didChangeValueForKey:@"contacts"];
}

@end
