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
    return [self initWithInitialType:NSInMemoryStoreType appSupportName:nil modelName:nil dataStoreName:nil];
}

- (id)initWithInitialType:(NSString *)type appSupportName:(NSString *)theAppSupportName modelName:(NSString *)theModelName dataStoreName:(NSString *)theDataStoreName
{
    NSAssert(theModelName != nil, @"The model url should not be nil.");
    
    self = [super init];
	if (self) {
		initialType = type;
		if (!type) {
			initialType = NSXMLStoreType;
		}
        modelName = [theModelName retain];
        if (![initialType isEqualToString:NSInMemoryStoreType]) {
            NSAssert(theAppSupportName != nil, @"The application support name should not be nil.");
            NSAssert(theDataStoreName != nil, @"The data store name should not be nil.");
            appSupportName = [theAppSupportName retain];
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

/**
 Returns the support folder for the application, used to store the Core Data
 store file.  This code uses a folder named "Minim" for
 the content, either in the NSApplicationSupportDirectory location or (if the
 former cannot be found), the system's temporary directory.
 */
- (NSString *)applicationSupportFolder 
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	return [basePath stringByAppendingPathComponent:appSupportName];
}

/**
 Creates, retains, and returns the managed object model for the application 
 by merging all of the models found in the application bundle.
 */
- (NSManagedObjectModel *)managedObjectModel 
{
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
	
	NSURL *modelUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], modelName]];
    managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelUrl];    
    return managedObjectModel;
}


/**
 Returns the persistent store coordinator for the application.  This 
 implementation will create and return a coordinator, having added the 
 store for the application to it.  (The folder for the store is created, 
 if necessary.)
 */
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

/**
 Returns the managed object context for the application (which is already
 bound to the persistent store coordinator for the application.) 
 */
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

- (NSApplicationTerminateReply)save
{
	NSError *error = nil;
	NSInteger reply = NSTerminateNow;
	NSManagedObjectContext *moc = [self managedObjectContext];
	if (moc != nil) {
		if ([moc commitEditing]) {
			if ([moc hasChanges] && ![moc save:&error]) {
				BOOL errorResult = [[NSApplication sharedApplication] presentError:error];
				
				if (errorResult == YES) {
					reply = NSTerminateCancel;
				} else {
					NSInteger alertReturn = NSRunAlertPanel(nil, @"Could not save changes while quitting. Quit anyway?" , @"Quit anyway", @"Cancel", nil);
					if (alertReturn == NSAlertAlternateReturn) {
						reply = NSTerminateCancel;	
					}
				}
			}
		} else {
			reply = NSTerminateCancel;
		}
	}
	return reply;
}

@end
