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

@interface ContactDataController()

@property (nonatomic, strong) CoreDataController *coreDataController;
@property (nonatomic, readwrite, strong) NSArray *contacts;

@end

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
            _coreDataController = controller;
        }
    }
    
    return self;
}



#pragma mark - Accessors

- (NSArray *)contacts
{
    return [_coreDataController.managedObjectModel objectsInEntityWithContext:_coreDataController.managedObjectContext
                                                                        name:@"Contact" 
                                                                   predicate:nil 
                                                       sortedWithDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"lastName" ascending:YES]]];
}

#pragma mark - Data Methods

- (Contact *)createContact
{
    [self willChangeValueForKey:@"contacts"];
	Contact *contact = (Contact *)[_coreDataController.managedObjectModel insertNewObjectInEntityWithContext:_coreDataController.managedObjectContext
                                                                                              name:@"Contact" 
                                                                                            values:nil];
    
	[self didChangeValueForKey:@"contacts"];
	return contact;
}

- (void)deleteContact:(Contact *)contact
{
    [self willChangeValueForKey:@"contacts"];
	[_coreDataController.managedObjectContext deleteObject:contact];
	[self didChangeValueForKey:@"contacts"];
}

@end
