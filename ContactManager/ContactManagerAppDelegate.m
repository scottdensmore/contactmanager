//
//  ContactManagerAppDelegate.m
//  ContactManager
//
//  Created by Scott Densmore on 6/11/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "ContactManagerAppDelegate.h"
#import "MainWindowController.h"
#import "CoreDataController.h"
#import "ContactDataController.h"

@interface ContactManagerAppDelegate()

- (void)showMainWindow;

@end

@implementation ContactManagerAppDelegate

#pragma mark - Memory Management

- (id)init 
{
    self = [super init];
    if (self) {
        coreDataController = [[CoreDataController alloc] initWithInitialType:NSSQLiteStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:@"ContactManager" dataStoreName:@"ContactManager.sql"];
        contactDataController = [[ContactDataController alloc] initWithCoreDataController:coreDataController];
        mainWindowController = [[MainWindowController alloc] initWithContactDataController:contactDataController];
    }
    return self;
}

- (void)dealloc 
{
    RELEASE(mainWindowController);
    RELEASE(coreDataController);
    RELEASE(contactDataController);
    
    [super dealloc];
}

#pragma mark - NSApplicationDelegate methods

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self showMainWindow];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[coreDataController managedObjectContext] undoManager];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    NSError *error = nil;
	NSUInteger reply = NSTerminateNow;
    BOOL saved = [coreDataController save:&error];

    if (NO == saved) {
        BOOL errorResult = [[NSApplication sharedApplication] presentError:error];
        
        if (errorResult == YES) {
            reply = NSTerminateCancel;
        } else {
            NSInteger alertReturn = NSRunAlertPanel(nil, FCLocalizedString(@"QuitQuestion"), FCLocalizedString(@"Quit"), FCLocalizedString(@"Cancel"), nil);
            if (alertReturn == NSAlertAlternateReturn) {
                reply = NSTerminateCancel;	
            }
        }
    }
    return reply;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag 
{
    if (flag) return YES;
    
    [self showMainWindow];
    return NO;  
}

- (void)applicationWillTerminate:(NSNotification *)theNotification
{
    [mainWindowController close];
}

#pragma mark - Private methods

- (void)showMainWindow
{  
    [[mainWindowController window] makeKeyAndOrderFront:self];
}

@end
