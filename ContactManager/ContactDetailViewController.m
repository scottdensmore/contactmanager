//
//  ContactDetailViewController.m
//  ContactManager
//
//  Created by Scott Densmore on 6/20/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "ContactDetailViewController.h"
#import "Contact.h"

@interface ContactDetailViewController ()

@property (nonatomic, strong) NSImageView *watermarkImageView;

- (void)updateFieldVisibility;

@end

@implementation ContactDetailViewController

@synthesize contact = _contact;

#pragma mark - View methods

- (NSString *)nibName
{
    return NSStringFromClass([self class]);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.watermarkImageView = [[NSImageView alloc] initWithFrame:self.view.bounds];
    self.watermarkImageView.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSImage *appIcon = [NSImage imageNamed:@"AppIcon"];
    if (!appIcon) {
        appIcon = [NSImage imageNamed:NSImageNameApplicationIcon];
    }
    self.watermarkImageView.image = appIcon;
    self.watermarkImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    self.watermarkImageView.alphaValue = 0.15; // Elegant, subtle alpha for premium aesthetic
    
    [self.view addSubview:self.watermarkImageView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.watermarkImageView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.watermarkImageView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.watermarkImageView.widthAnchor constraintEqualToConstant:128],
        [self.watermarkImageView.heightAnchor constraintEqualToConstant:128]
    ]];
    
    [self updateFieldVisibility];
}

- (void)setContact:(Contact * _Nullable)contact
{
    if (_contact != contact) {
        _contact = contact;
        if (self.isViewLoaded) {
            [self updateFieldVisibility];
        }
    }
}

- (void)updateFieldVisibility
{
    BOOL hasContact = (self.contact != nil);
    self.watermarkImageView.hidden = hasContact;
    
    for (NSView *subview in self.view.subviews) {
        if (subview != self.watermarkImageView) {
            subview.hidden = !hasContact;
        }
    }
}

@end
