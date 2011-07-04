//
//  CoreDataController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol CoreDataControllerDelegate;

@interface CoreDataController : NSObject {
@private
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;
	NSString *initialType;
	NSString *appSupportName;
	NSString *modelName;
	NSString *dataStoreName;
    id<CoreDataControllerDelegate> delegate;
}

@property (assign) id<CoreDataControllerDelegate> delegate;

- (NSString *)applicationSupportFolder;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;

- (id)initWithModelName:(NSString *)theModelName applicationSupportName:(NSString *)theApplicationSupportName dataStoreName:(NSString *)theDataStoreName;
- (id)initWithInitialType:(NSString *)type modelName:(NSString *)theModelName applicationSupportName:(NSString *)theApplicationSupportName dataStoreName:(NSString *)theDataStoreName;

- (BOOL)save:(NSError **)error;


@end
