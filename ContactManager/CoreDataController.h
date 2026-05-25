//
//  CoreDataController.h
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CoreDataControllerDelegate;

@interface CoreDataController : NSObject

@property (nonatomic, weak, nullable) id<CoreDataControllerDelegate> delegate;

@property (nonatomic, readonly, strong) NSString *applicationSupportFolder;
@property (nonatomic, readonly, strong, nullable) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, readonly, strong, nullable) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readonly, strong, nullable) NSManagedObjectContext *managedObjectContext;

- (instancetype)initWithModelName:(nullable NSString *)theModelName applicationSupportName:(nullable NSString *)theApplicationSupportName dataStoreName:(nullable NSString *)theDataStoreName;
- (instancetype)initWithInitialType:(NSString *)type modelName:(nullable NSString *)theModelName applicationSupportName:(nullable NSString *)theApplicationSupportName dataStoreName:(nullable NSString *)theDataStoreName;

- (BOOL)save:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END

