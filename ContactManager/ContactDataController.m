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
    NSParameterAssert(controller != nil);
    
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

- (Contact *)createContact
{
    [self willChangeValueForKey:@"contacts"];
	Contact *contact = (Contact *)[coreDataController.managedObjectModel insertNewObjectInEntityWithContext:coreDataController.managedObjectContext 
                                                                                              name:@"Contact" 
                                                                                            values:nil];
    
	[self didChangeValueForKey:@"contacts"];
	return contact;
}

- (void)deleteContact:(Contact *)contact
{
    [self willChangeValueForKey:@"contacts"];
	[coreDataController.managedObjectContext deleteObject:contact];
	[self didChangeValueForKey:@"contacts"];
}

@end
