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

@property (strong) MainWindowController *mainWindowController;
@property (strong) CoreDataController *coreDataController;
@property (strong) ContactDataController *contactDataController;

- (void)showMainWindow;

@end

@implementation ContactManagerAppDelegate

#pragma mark - Memory Management

- (id)init 
{
    self = [super init];
    if (self) {
        _coreDataController = [[CoreDataController alloc] initWithInitialType:NSSQLiteStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:@"ContactManager" dataStoreName:@"ContactManager.sql"];
        _contactDataController = [[ContactDataController alloc] initWithCoreDataController:_coreDataController];
        _mainWindowController = [[MainWindowController alloc] initWithContactDataController:_contactDataController];
    }
    return self;
}


#pragma mark - NSApplicationDelegate methods

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self showMainWindow];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[_coreDataController managedObjectContext] undoManager];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    NSError *error = nil;
	NSUInteger reply = NSTerminateNow;
    BOOL saved = [_coreDataController save:&error];

    if (!saved) {
        BOOL errorResult = [[NSApplication sharedApplication] presentError:error];
        
        if (errorResult) {
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
    [_mainWindowController close];
}

#pragma mark - Private methods

- (void)showMainWindow
{  
    [[_mainWindowController window] makeKeyAndOrderFront:self];
}

@end
