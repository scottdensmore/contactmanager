//
//  CoreDataController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol CoreDataControllerDelegate;

@interface CoreDataController : NSObject

@property (assign) id<CoreDataControllerDelegate> delegate;

@property (nonatomic, readonly, strong) NSString *applicationSupportFolder;
@property (nonatomic, readonly, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, readonly, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readonly, strong) NSManagedObjectContext *managedObjectContext;

- (id)initWithModelName:(NSString *)theModelName applicationSupportName:(NSString *)theApplicationSupportName dataStoreName:(NSString *)theDataStoreName;
- (id)initWithInitialType:(NSString *)type modelName:(NSString *)theModelName applicationSupportName:(NSString *)theApplicationSupportName dataStoreName:(NSString *)theDataStoreName;

- (BOOL)save:(NSError **)error;


@end
