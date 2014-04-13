//
//  ContactManagerAppDelegateTests.m
//  ContactManager
//
//  Created by Scott Densmore on 7/4/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ContactManagerAppDelegate.h"

@interface ContactManagerAppDelegateTests : XCTestCase

@property (nonatomic, strong) ContactManagerAppDelegate *appDelegate;

@end

@implementation ContactManagerAppDelegateTests

- (void)setUp
{
    [super setUp];
    
    _appDelegate = [[ContactManagerAppDelegate alloc] init];
}

- (void)tearDown
{
    _appDelegate = nil;
    
    [super tearDown];
}

@end
