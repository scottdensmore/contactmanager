//
//  ContactManagerAppDelegate.h
//  ContactManager
//
//  Created by Scott Densmore on 6/11/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MainWindowController;
@class CoreDataController;
@class ContactDataController;

@interface ContactManagerAppDelegate : NSObject <NSApplicationDelegate> {
@private
    MainWindowController *mainWindowController;
    CoreDataController *coreDataController;
    ContactDataController *contactDataController;
}

@end
