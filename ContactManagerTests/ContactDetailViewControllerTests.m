//
//  ContactDetailViewControllerTests.m
//  ContactManager
//
//  Created by Scott Densmore on 6/27/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BaseTestCase.h"
#import "CoreDataController.h"
#import "ContactDataController.h"
#import "ContactDetailViewController.h"
#import "MainWindowController.h"

@interface ContactDetailViewControllerTests : BaseTestCase

@property (nonatomic, strong) MainWindowController *mainWindowController;
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) ContactDetailViewController *contactDetailViewController;

@end


@implementation ContactDetailViewControllerTests

- (void)setUp
{
    [super setUp];
    
    CoreDataController *coreDataController = [[CoreDataController alloc] initWithInitialType:NSInMemoryStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:nil dataStoreName:nil];
    ContactDataController *contactDataController = [[ContactDataController alloc] initWithCoreDataController:coreDataController];
    
    _mainWindowController = [[MainWindowController alloc] initWithContactDataController:contactDataController];
    _window = _mainWindowController.window;
    _contactDetailViewController = _mainWindowController.contactDetailViewController;
}

- (void)tearDown
{
    _mainWindowController = nil;
    _window = nil;
    _contactDetailViewController = nil;
    
    [super tearDown];
}

- (void)testShouldHaveValidNibName
{
    XCTAssertEqualObjects(_contactDetailViewController.nibName, @"ContactDetailViewController",
                         @"The nib for this view should be ContactDetailViewController.xib");
}

- (void)testShoudBindObjectControllerFirstNameToFirstNameTextField
{
    NSObjectController *contactObjectController = _contactDetailViewController.contactObjectController;
    NSTextField *firstNameTextField = _contactDetailViewController.firstNameTextField;
    
    XCTAssertTrue([self checkObject:firstNameTextField hasBinding:NSValueBinding
                          toObject:contactObjectController through:@"selection.firstName"],
                 @"Bind first name text field value to the object controller's 'selection.firstName' key path.");
    
}

- (void)testShoudBindObjectControllerLastNameToLastNameTextField
{
    NSObjectController *contactObjectController = _contactDetailViewController.contactObjectController;
    NSTextField *lastNameTextField = _contactDetailViewController.lastNameTextField;
    
    XCTAssertTrue([self checkObject:lastNameTextField hasBinding:NSValueBinding
                          toObject:contactObjectController through:@"selection.lastName"],
                 @"Bind last name text field value to the object controller's 'selection.lastName' key path.");
    
}

- (void)testShoudBindObjectControllerPhoneNumberToPhoneNumberTextField
{
    NSObjectController *contactObjectController = _contactDetailViewController.contactObjectController;
    NSTextField *phoneNumberTextField = _contactDetailViewController.phoneNumberTextField;
    
    XCTAssertTrue([self checkObject:phoneNumberTextField hasBinding:NSValueBinding
                          toObject:contactObjectController through:@"selection.phoneNumber"],
                 @"Bind phone number text field value to the object controller's 'selection.phoneNumber' key path.");
    
}

- (void)testShoudBindObjectControllerEmailToEmalTextField
{
    NSObjectController *contactObjectController = _contactDetailViewController.contactObjectController;
    NSTextField *emailTextField = _contactDetailViewController.emailTextField;
    
    XCTAssertTrue([self checkObject:emailTextField hasBinding:NSValueBinding
                          toObject:contactObjectController through:@"selection.emailAddress"],
                 @"Bind email text field value to the object controller's 'selection.email' key path.");
    
}

- (void)testShouldHideFieldsWhenContactIsNil
{
    [_contactDetailViewController view];
    _contactDetailViewController.contact = nil;
    
    XCTAssertTrue(_contactDetailViewController.firstNameTextField.isHidden, @"First name text field should be hidden.");
    XCTAssertTrue(_contactDetailViewController.lastNameTextField.isHidden, @"Last name text field should be hidden.");
    XCTAssertTrue(_contactDetailViewController.emailTextField.isHidden, @"Email text field should be hidden.");
    XCTAssertTrue(_contactDetailViewController.phoneNumberTextField.isHidden, @"Phone number text field should be hidden.");
}

- (void)testShouldShowFieldsWhenContactIsSet
{
    [_contactDetailViewController view];
    
    CoreDataController *coreDataController = [[CoreDataController alloc] initWithInitialType:NSInMemoryStoreType modelName:@"ContactManagerModel.momd" applicationSupportName:nil dataStoreName:nil];
    ContactDataController *contactDataController = [[ContactDataController alloc] initWithCoreDataController:coreDataController];
    Contact *contact = [contactDataController createContact];
    
    _contactDetailViewController.contact = contact;
    
    XCTAssertFalse(_contactDetailViewController.firstNameTextField.isHidden, @"First name text field should be visible.");
    XCTAssertFalse(_contactDetailViewController.lastNameTextField.isHidden, @"Last name text field should be visible.");
    XCTAssertFalse(_contactDetailViewController.emailTextField.isHidden, @"Email text field should be visible.");
    XCTAssertFalse(_contactDetailViewController.phoneNumberTextField.isHidden, @"Phone number text field should be visible.");
}

@end
