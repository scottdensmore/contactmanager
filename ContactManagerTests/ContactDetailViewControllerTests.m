//
//  ContactDetailViewControllerTests.m
//  ContactManager
//
//  Created by Scott Densmore on 6/27/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "ContactDetailViewControllerTests.h"
#import <OCMock/OCMock.h>
#import "ContactDataController.h"
#import "ContactDetailViewController.h"
#import "MainWindowController.h"

@implementation ContactDetailViewControllerTests

- (void)setUp
{
    [super setUp];
    
    id contactDataController = [OCMockObject mockForClass:ContactDataController.class];
    [[[contactDataController stub] andReturn:nil] contacts];
    
    mainWindowController = [[MainWindowController alloc] initWithContactDataController:contactDataController];
    window = mainWindowController.window;
    contactDetailViewController = mainWindowController.contactDetailViewController;
}

- (void)tearDown
{
    [mainWindowController release];
    mainWindowController = nil;
    window = nil;
    contactDetailViewController = nil;
    
    [super tearDown];
}

- (void)testShouldHaveValidNibName
{
    STAssertEqualObjects(contactDetailViewController.nibName, @"ContactDetailViewController",
                         @"The nib for this view should be ContactDetailViewController.xib");
}

- (void)testShoudBindObjectControllerFirstNameToFirstNameTextField
{
    NSObjectController *contactObjectController = contactDetailViewController.contactObjectController;
    NSTextField *firstNameTextField = contactDetailViewController.firstNameTextField;
    
    STAssertTrue([self checkObject:firstNameTextField hasBinding:NSValueBinding
                          toObject:contactObjectController through:@"selection.firstName"],
                 @"Bind first name text field value to the object controller's 'selection.firstName' key path.");
    
}

- (void)testShoudBindObjectControllerLastNameToLastNameTextField
{
    NSObjectController *contactObjectController = contactDetailViewController.contactObjectController;
    NSTextField *lastNameTextField = contactDetailViewController.lastNameTextField;
    
    STAssertTrue([self checkObject:lastNameTextField hasBinding:NSValueBinding
                          toObject:contactObjectController through:@"selection.lastName"],
                 @"Bind last name text field value to the object controller's 'selection.lastName' key path.");
    
}

- (void)testShoudBindObjectControllerPhoneNumberToPhoneNumberTextField
{
    NSObjectController *contactObjectController = contactDetailViewController.contactObjectController;
    NSTextField *phoneNumberTextField = contactDetailViewController.phoneNumberTextField;
    
    STAssertTrue([self checkObject:phoneNumberTextField hasBinding:NSValueBinding
                          toObject:contactObjectController through:@"selection.phoneNumber"],
                 @"Bind phone number text field value to the object controller's 'selection.phoneNumber' key path.");
    
}

- (void)testShoudBindObjectControllerEmailToEmalTextField
{
    NSObjectController *contactObjectController = contactDetailViewController.contactObjectController;
    NSTextField *emailTextField = contactDetailViewController.emailTextField;
    
    STAssertTrue([self checkObject:emailTextField hasBinding:NSValueBinding
                          toObject:contactObjectController through:@"selection.emailAddress"],
                 @"Bind email text field value to the object controller's 'selection.email' key path.");
    
}

@end
