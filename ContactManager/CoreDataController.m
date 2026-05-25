//
//  CoreDataController.m
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "CoreDataController.h"
#import "CoreDataControllerDelegate.h"

@interface CoreDataController()

@property (nonatomic, readwrite, strong) NSPersistentContainer *persistentContainer;
@property (nonatomic, readwrite, strong, nullable) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, readwrite, strong, nullable) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readwrite, strong, nullable) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong, nullable) NSString *initialType;
@property (nonatomic, strong, nullable) NSString *appSupportName;
@property (nonatomic, strong, nullable) NSString *modelName;
@property (nonatomic, strong, nullable) NSString *dataStoreName;

@end

@implementation CoreDataController
#pragma mark - Memory Management

- (instancetype)init 
{
    return [self initWithInitialType:NSInMemoryStoreType modelName:nil applicationSupportName:nil dataStoreName:nil];
}

- (instancetype)initWithModelName:(NSString *)theModelName applicationSupportName:(nullable NSString *)theApplicationSupportName dataStoreName:(nullable NSString *)theDataStoreName
{
    return [self initWithInitialType:NSXMLStoreType modelName:theModelName applicationSupportName:theApplicationSupportName  dataStoreName:theDataStoreName];
}

- (instancetype)initWithInitialType:(NSString *)type modelName:(NSString *)theModelName applicationSupportName:(nullable NSString *)theApplicationSupportName dataStoreName:(nullable NSString *)theDataStoreName
{
    NSParameterAssert(theModelName != nil);
    
    self = [super init];
	if (self) {
		_initialType = type;
        _modelName = theModelName;
        if (![_initialType isEqualToString:NSInMemoryStoreType]) {
            NSParameterAssert(theApplicationSupportName != nil);
            NSParameterAssert(theDataStoreName != nil);
            _appSupportName = theApplicationSupportName;
            _dataStoreName = theDataStoreName;
        }
	}
	return self;
}


#pragma mark - Accesssors

- (NSString *)applicationSupportFolder 
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? paths[0] : NSTemporaryDirectory();
	return [basePath stringByAppendingPathComponent:_appSupportName];
}

- (NSManagedObjectModel *)managedObjectModel 
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
	
	NSURL *modelUrl = [[NSBundle mainBundle] URLForResource:[_modelName stringByDeletingPathExtension] withExtension:[_modelName pathExtension]];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelUrl];
    return _managedObjectModel;
}

- (NSPersistentContainer *)persistentContainer
{
    if (_persistentContainer != nil) {
        return _persistentContainer;
    }
    
    NSString *containerName = [_modelName stringByDeletingPathExtension];
    _persistentContainer = [[NSPersistentContainer alloc] initWithName:containerName managedObjectModel:[self managedObjectModel]];
    
    NSPersistentStoreDescription *storeDescription;
    if ([_initialType isEqualToString:NSInMemoryStoreType]) {
        storeDescription = [NSPersistentStoreDescription persistentStoreDescriptionWithURL:[NSURL fileURLWithPath:@"/dev/null"]];
    } else {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *applicationSupportFolder = [self applicationSupportFolder];
        NSError *error = nil;
        if (![fileManager fileExistsAtPath:applicationSupportFolder isDirectory:NULL]) {
            if (![fileManager createDirectoryAtPath:applicationSupportFolder withIntermediateDirectories:NO attributes:nil error:&error]) {
                NSAssert(NO, ([NSString stringWithFormat:@"Failed to create App Support directory %@ : %@", applicationSupportFolder, error]));
                LOG(@"Error creating application support directory at %@ : %@", applicationSupportFolder, error);
            }
        }
        
        NSURL *url = [NSURL fileURLWithPath:[applicationSupportFolder stringByAppendingPathComponent:_dataStoreName]];
        storeDescription = [NSPersistentStoreDescription persistentStoreDescriptionWithURL:url];
    }
    
    storeDescription.type = _initialType;
    storeDescription.shouldMigrateStoreAutomatically = YES;
    storeDescription.shouldInferMappingModelAutomatically = YES;
    
    _persistentContainer.persistentStoreDescriptions = @[storeDescription];
    
    [_persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *description, NSError *error) {
        if (error) {
            if ([error code] == 134100) {
                if ([[self delegate] respondsToSelector:@selector(coreDataController:encounteredIncorrectModelWithVersionIdentifiers:)]) {
                    NSError *metadataError = nil;
                    NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:self.initialType URL:description.URL options:nil error:&metadataError];
                    [[self delegate] coreDataController:self encounteredIncorrectModelWithVersionIdentifiers:metadata[NSStoreModelVersionIdentifiersKey]];
                }
            } else {
                [[NSApplication sharedApplication] presentError:error];
            }
        }
    }];
    
    return _persistentContainer;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    return self.persistentContainer.persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext
{
    return self.persistentContainer.viewContext;
}

- (BOOL)save:(NSError **)error
{
    BOOL reply = YES;
	NSManagedObjectContext *moc = [self managedObjectContext];
	if (moc != nil) {
		if ([moc commitEditing]) {
			if ([moc hasChanges]) {
                return [moc save:error];
            }
        }
	}
	return reply;
}

@end
