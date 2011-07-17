//
//  ContactManagerAppDelegateTests.m
//  ContactManager
//
//  Created by Scott Densmore on 7/4/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "ContactManagerAppDelegateTests.h"
#import "ContactManagerAppDelegate.h"

@implementation ContactManagerAppDelegateTests

- (void)setUp
{
    [super setUp];
    
    appDelegate = [[ContactManagerAppDelegate alloc] init];
}

- (void)tearDown
{
    [appDelegate release];
    
    [super tearDown];
}

@end
