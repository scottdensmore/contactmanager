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

@property (nonatomic, readwrite, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, readwrite, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readwrite, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSString *initialType;
@property (nonatomic, strong) NSString *appSupportName;
@property (nonatomic, strong) NSString *modelName;
@property (nonatomic, strong) NSString *dataStoreName;

@end

@implementation CoreDataController

@synthesize delegate;

#pragma mark - Memory Management

- (id)init 
{
    return [self initWithInitialType:NSInMemoryStoreType modelName:nil applicationSupportName:nil dataStoreName:nil];
}

- (id)initWithModelName:(NSString *)theModelName applicationSupportName:(NSString *)theApplicationSupportName dataStoreName:(NSString *)theDataStoreName
{
    return [self initWithInitialType:NSXMLStoreType modelName:theModelName applicationSupportName:theApplicationSupportName  dataStoreName:theDataStoreName];
}

- (id)initWithInitialType:(NSString *)type modelName:(NSString *)theModelName applicationSupportName:(NSString *)theApplicationSupportName dataStoreName:(NSString *)theDataStoreName;
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

- (void)dealloc 
{
    delegate = nil;
    
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
	
	NSURL *modelUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], _modelName]];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelUrl];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator 
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
	
    NSFileManager *fileManager;
    NSString *applicationSupportFolder = nil;
    NSURL *url;
    NSError *error;
    
    fileManager = [NSFileManager defaultManager];
    applicationSupportFolder = [self applicationSupportFolder];
    
    if (![fileManager fileExistsAtPath:applicationSupportFolder isDirectory:NULL] ) {
		if (![fileManager createDirectoryAtPath:applicationSupportFolder withIntermediateDirectories:NO attributes:nil error:&error]) {
            NSAssert(NO, ([NSString stringWithFormat:@"Failed to create App Support directory %@ : %@", applicationSupportFolder, error]));
            LOG(@"Error creating application support directory at %@ : %@",applicationSupportFolder,error);
            return nil;
		}
    }
        
    url = [NSURL fileURLWithPath: [applicationSupportFolder stringByAppendingPathComponent: _dataStoreName]];
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
	NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES};
    if (![_persistentStoreCoordinator addPersistentStoreWithType:_initialType configuration:nil URL:url options:options error:&error]){
		if ([error code] == 134100) {
			//If we failed with an incorrect data model error then pass the version identifiers of the store to the delegate to decide what to do next
			if ([[self delegate] respondsToSelector:@selector(coreDataController:encounteredIncorrectModelWithVersionIdentifiers:)]) {
				_persistentStoreCoordinator = nil;
                NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:_initialType URL:url options:options error:&error];
				[[self delegate] coreDataController:self encounteredIncorrectModelWithVersionIdentifiers:metadata[NSStoreModelVersionIdentifiersKey]];
			}
		} else {
			[[NSApplication sharedApplication] presentError:error];
		}
    }    
	
    return _persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
		NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
		if (coordinator != nil) {
			_managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
			[_managedObjectContext setPersistentStoreCoordinator: coordinator];
		}
	}
    
    return _managedObjectContext;
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
