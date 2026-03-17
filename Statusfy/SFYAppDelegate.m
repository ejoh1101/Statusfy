//
//  SFYAppDelegate.m
//  Statusfy
//
//  Created by Paul Young on 4/16/14.
//  Copyright (c) 2014 Paul Young. All rights reserved.
//

#import "SFYAppDelegate.h"


static NSString * const SFYPlayerStatePreferenceKey = @"ShowPlayerState";
static NSString * const SFYHideIfNotPlayingKey = @"HideIfNotPlaying";
static NSString * const SFYPlayerDockIconPreferenceKey = @"ShowPlayerDockIcon";
static NSString * const SFYSpotifyApplicationName = @"Spotify";
static NSString * const SFYMusicApplicationName = @"Music";

@interface SFYAppDelegate ()

@property (nonatomic, strong) NSMenuItem *playerStateMenuItem;
@property (nonatomic, strong) NSMenuItem *dockIconMenuItem;
@property (nonatomic, strong) NSMenuItem *hideIfNotPlayingItem;
@property (nonatomic, strong) NSStatusItem *statusItem;

@end

@implementation SFYAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification * __unused)aNotification
{
    [self showOrHideDockIcon];

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.highlightMode = YES;
    
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    
    self.playerStateMenuItem = [[NSMenuItem alloc] initWithTitle:[self determinePlayerStateMenuItemTitle] action:@selector(togglePlayerStateVisibility) keyEquivalent:@""];
    
    self.dockIconMenuItem = [[NSMenuItem alloc] initWithTitle:[self determineDockIconMenuItemTitle] action:@selector(toggleDockIconVisibility) keyEquivalent:@""];
    
    self.hideIfNotPlayingItem = [[NSMenuItem alloc] initWithTitle:[self determineHideIfNotPlayingMenuItemTitle] action:@selector(toggleHideIfNotPlaying) keyEquivalent:@""];
    
    [menu addItem:self.playerStateMenuItem];
    [menu addItem:self.dockIconMenuItem];
    [menu addItem:self.hideIfNotPlayingItem];
    [menu addItemWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(quit) keyEquivalent:@"q"];

    [self.statusItem setMenu:menu];
    
    [self setStatusItemTitle];
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(setStatusItemTitle) userInfo:nil repeats:YES];
}

#pragma mark - Setting title text

- (void)setStatusItemTitle
{
    NSString *activeApplicationName = [self activePlayerApplicationName];
    if (!activeApplicationName) {
        [self showIconAndHideText];
        return;
    }

    NSString *trackName = [[self executeAppleScript:@"get name of current track" forApplication:activeApplicationName] stringValue];
    NSString *artistName = [[self executeAppleScript:@"get artist of current track" forApplication:activeApplicationName] stringValue];
    
    if ([self getHideIfNotPlaying] && ![self checkIfIsPlayingForApplication:activeApplicationName]) {
        [self showIconAndHideText];
    }
    else {
        if (trackName && artistName) {
            NSString *titleText = [NSString stringWithFormat:@"%@ - %@", trackName, artistName];

            if ([self getPlayerStateVisibility]) {
                NSString *playerState = [self determinePlayerStateTextForApplication:activeApplicationName];
                titleText = [NSString stringWithFormat:@"%@ (%@)", titleText, playerState];
            }

            [self hideIconAndDisplayText:titleText];
        }
        else {
            [self showIconAndHideText];
        }
    }
    
}

- (void)hideIconAndDisplayText:(NSString*)titleText {
    self.statusItem.image = nil;
    self.statusItem.title = titleText;
}

- (void)showIconAndHideText {
    NSImage *image = [NSImage imageNamed:@"status_icon"];
    [image setTemplate:true];
    self.statusItem.image = image;
    self.statusItem.title = nil;
}

#pragma mark - Executing AppleScript

- (NSAppleEventDescriptor *)executeAppleScript:(NSString *)command
{
    return [self executeAppleScript:command forApplication:SFYSpotifyApplicationName];
}

- (NSAppleEventDescriptor *)executeAppleScript:(NSString *)command forApplication:(NSString *)applicationName
{
    command = [NSString stringWithFormat:@"if application \"%@\" is running then tell application \"%@\" to %@", applicationName, applicationName, command];
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:command];
    NSAppleEventDescriptor *eventDescriptor = [appleScript executeAndReturnError:NULL];
    return eventDescriptor;
}

#pragma mark - Player detection

- (BOOL)isApplicationRunning:(NSString *)applicationName
{
    NSString *command = [NSString stringWithFormat:@"application \"%@\" is running", applicationName];
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:command];
    NSAppleEventDescriptor *eventDescriptor = [appleScript executeAndReturnError:NULL];
    return [eventDescriptor booleanValue];
}

- (NSString *)playerStateConstantForApplication:(NSString *)applicationName
{
    return [[self executeAppleScript:@"get player state" forApplication:applicationName] stringValue];
}

- (BOOL)playerStateRepresentsPlaying:(NSString *)playerStateConstant
{
    if (!playerStateConstant) {
        return NO;
    }

    return [playerStateConstant isEqualToString:@"kPSP"] || [playerStateConstant caseInsensitiveCompare:@"playing"] == NSOrderedSame;
}

- (NSString *)activePlayerApplicationName
{
    BOOL spotifyRunning = [self isApplicationRunning:SFYSpotifyApplicationName];
    BOOL musicRunning = [self isApplicationRunning:SFYMusicApplicationName];

    if (spotifyRunning && [self checkIfIsPlayingForApplication:SFYSpotifyApplicationName]) {
        return SFYSpotifyApplicationName;
    }

    if (musicRunning && [self checkIfIsPlayingForApplication:SFYMusicApplicationName]) {
        return SFYMusicApplicationName;
    }

    if (spotifyRunning) {
        return SFYSpotifyApplicationName;
    }

    if (musicRunning) {
        return SFYMusicApplicationName;
    }

    return nil;
}

#pragma mark - Player state

- (BOOL)getPlayerStateVisibility
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:SFYPlayerStatePreferenceKey];
}

- (void)setPlayerStateVisibility:(BOOL)visible
{
    [[NSUserDefaults standardUserDefaults] setBool:visible forKey:SFYPlayerStatePreferenceKey];
}

- (void)togglePlayerStateVisibility
{
    [self setPlayerStateVisibility:![self getPlayerStateVisibility]];
    self.playerStateMenuItem.title = [self determinePlayerStateMenuItemTitle];
}

- (NSString *)determinePlayerStateMenuItemTitle
{
    return [self getPlayerStateVisibility] ? NSLocalizedString(@"Hide Player State", nil) : NSLocalizedString(@"Show Player State", nil);
}

- (BOOL)checkIfIsPlaying
{
    NSString *activeApplicationName = [self activePlayerApplicationName];
    if (!activeApplicationName) {
        return NO;
    }

    return [self checkIfIsPlayingForApplication:activeApplicationName];
}

- (BOOL)checkIfIsPlayingForApplication:(NSString *)applicationName
{
    NSString *playerStateConstant = [self playerStateConstantForApplication:applicationName];
    return [self playerStateRepresentsPlaying:playerStateConstant];
}

- (NSString *)determinePlayerStateText
{
    NSString *activeApplicationName = [self activePlayerApplicationName];
    if (!activeApplicationName) {
        return NSLocalizedString(@"Stopped", nil);
    }

    return [self determinePlayerStateTextForApplication:activeApplicationName];
}

- (NSString *)determinePlayerStateTextForApplication:(NSString *)applicationName
{
    NSString *playerStateText = nil;
    NSString *playerStateConstant = [self playerStateConstantForApplication:applicationName];

    if ([playerStateConstant isEqualToString:@"kPSP"] || [playerStateConstant caseInsensitiveCompare:@"playing"] == NSOrderedSame) {
        playerStateText = NSLocalizedString(@"Playing", nil);
    }
    else if ([playerStateConstant isEqualToString:@"kPSp"] || [playerStateConstant caseInsensitiveCompare:@"paused"] == NSOrderedSame) {
        playerStateText = NSLocalizedString(@"Paused", nil);
    }
    else {
        playerStateText = NSLocalizedString(@"Stopped", nil);
    }

    return playerStateText;
}

#pragma mark - Toggle Dock Icon

- (BOOL)getHideIfNotPlaying
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:SFYHideIfNotPlayingKey];
}

-(void)setHideIfNotPlaying:(BOOL)hide
{
    [[NSUserDefaults standardUserDefaults] setBool:hide forKey:SFYHideIfNotPlayingKey];
}

- (void)toggleHideIfNotPlaying
{
    [self setHideIfNotPlaying:![self getHideIfNotPlaying]];
    self.hideIfNotPlayingItem.title = [self determineHideIfNotPlayingMenuItemTitle];
}

- (BOOL)getDockIconVisibility
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:SFYPlayerDockIconPreferenceKey];
}

- (void)setDockIconVisibility:(BOOL)visible
{
   [[NSUserDefaults standardUserDefaults] setBool:visible forKey:SFYPlayerDockIconPreferenceKey];
}

- (void)toggleDockIconVisibility
{
    [self setDockIconVisibility:![self getDockIconVisibility]];
    self.dockIconMenuItem.title = [self determineDockIconMenuItemTitle];
    [self showOrHideDockIcon];
}

- (void) showOrHideDockIcon
{
    if(![self getDockIconVisibility])
    {
        //Apple recommended method to show and hide dock icon
        //hide icon
        [NSApp setActivationPolicy: NSApplicationActivationPolicyAccessory];
    }
    else
    {
        //show icon
        [NSApp setActivationPolicy: NSApplicationActivationPolicyRegular];
    }
}

- (NSString *)determineHideIfNotPlayingMenuItemTitle
{
    return ![self getHideIfNotPlaying] ? NSLocalizedString(@"Hide If Not Playing", nil) :
        NSLocalizedString(@"Show Even If Not Playing", nil);
}

- (NSString *)determineDockIconMenuItemTitle
{
    return [self getDockIconVisibility] ? NSLocalizedString(@"Hide Dock Icon", nil) : NSLocalizedString(@"Show Dock Icon", nil);
}

#pragma mark - Quit

- (void)quit
{
    [[NSApplication sharedApplication] terminate:self];
}

@end
