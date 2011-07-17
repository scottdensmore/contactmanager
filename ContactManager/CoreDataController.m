//
//  CoreDataController.m
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "CoreDataController.h"
#import "CoreDataControllerDelegate.h"

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
		initialType = [type retain];
        modelName = [theModelName retain];
        if (![initialType isEqualToString:NSInMemoryStoreType]) {
            NSParameterAssert(theApplicationSupportName != nil);
            NSParameterAssert(theDataStoreName != nil);
            appSupportName = [theApplicationSupportName retain];
            dataStoreName = [theDataStoreName retain];
        }
	}
	return self;
}

- (void)dealloc 
{
    RELEASE(persistentStoreCoordinator);
    RELEASE(managedObjectModel);
    RELEASE(managedObjectContext);
    RELEASE(initialType);
    RELEASE(appSupportName);
    RELEASE(modelName);
    RELEASE(dataStoreName);
    delegate = nil;
    
    [super dealloc];
}

#pragma mark - Accesssors

- (NSString *)applicationSupportFolder 
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	return [basePath stringByAppendingPathComponent:appSupportName];
}

- (NSManagedObjectModel *)managedObjectModel 
{
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
	
	NSURL *modelUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], modelName]];
    managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelUrl];    
    return managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator 
{
    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
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
        
    url = [NSURL fileURLWithPath: [applicationSupportFolder stringByAppendingPathComponent: dataStoreName]];
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
	NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:NSMigratePersistentStoresAutomaticallyOption];
    if (![persistentStoreCoordinator addPersistentStoreWithType:initialType configuration:nil URL:url options:options error:&error]){
		if ([error code] == 134100) {
			//If we failed with an incorrect data model error then pass the version identifiers of the store to the delegate to decide what to do next
			if ([[self delegate] respondsToSelector:@selector(coreDataController:encounteredIncorrectModelWithVersionIdentifiers:)]) {
				persistentStoreCoordinator = nil;
				NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:initialType URL:url error:&error];
				[[self delegate] coreDataController:self encounteredIncorrectModelWithVersionIdentifiers:[metadata objectForKey:NSStoreModelVersionIdentifiersKey]];
			}
		} else {
			[[NSApplication sharedApplication] presentError:error];
		}
    }    
	
    return persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (!managedObjectContext) {
		NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
		if (coordinator != nil) {
			managedObjectContext = [[NSManagedObjectContext alloc] init];
			[managedObjectContext setPersistentStoreCoordinator: coordinator];
		}
	}
    
    return managedObjectContext;
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
