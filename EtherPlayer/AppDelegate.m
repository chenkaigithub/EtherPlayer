//
//  EtherPlayerAppDelegate.m
//  EtherPlayer
//
//  Created by Brendon Justin on 5/31/12.
//  Copyright (c) 2012 Brendon Justin. All rights reserved.
//

#import "AppDelegate.h"
#import "AirplayHandler.h"
#import "BonjourSearcher.h"
#import "VideoManager.h"

@interface AppDelegate () <AirplayHandlerDelegate, VideoManagerDelegate>

- (void)airplayTargetsNotificationReceived:(NSNotification *)notification;

@property (strong, nonatomic) AirplayHandler    *m_handler;
@property (strong, nonatomic) BonjourSearcher   *m_searcher;
@property (strong, nonatomic) NSMutableArray    *m_services;
@property (strong, nonatomic) VideoManager      *m_manager;

@end

@implementation AppDelegate

@synthesize window = _window;
@synthesize targetSelector = m_targetSelector;
@synthesize playButton = m_playButton;
@synthesize positionFieldCell = m_positionFieldCell;
@synthesize durationFieldCell = m_durationFieldCell;
@synthesize m_handler;
@synthesize m_searcher;
@synthesize m_services;
@synthesize m_manager;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    m_searcher = [[BonjourSearcher alloc] init];
    m_services = [NSMutableArray array];

    m_targetSelector.autoenablesItems = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(airplayTargetsNotificationReceived:) 
                                                 name:@"AirplayTargets" 
                                               object:m_searcher];

    m_manager =  [[VideoManager alloc] init];
    m_manager.delegate = self;
    
    m_handler = [[AirplayHandler alloc] init];
    m_handler.delegate = self;
    m_handler.videoManager = m_manager;

    [m_searcher beginSearching];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [m_manager cleanup];
}

- (IBAction)openFile:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.allowsMultipleSelection = NO;
    
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [self application:[NSApplication sharedApplication] openFile:[panel.URL absoluteString]];
        }
    }];
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL URLWithString:filename]];
    [m_manager transcodeMediaForPath:filename];
    
    return YES;
}

- (void)airplayTargetsNotificationReceived:(NSNotification *)notification
{
    NSMutableArray *servicesToRemove = [NSMutableArray array];
    NSArray *services = [[notification userInfo] objectForKey:@"targets"];
    NSLog(@"Found services: %@", services);
    
    for (NSNetService *service in services) {
        if (![m_services containsObject:service]) {
            [m_services addObject:service];
            [m_targetSelector addItemWithTitle:service.hostName];
            
            if ([[m_targetSelector itemArray] count] == 1) {
                [m_targetSelector selectItem:[m_targetSelector lastItem]];
                [self updateTarget:self];
            }
        }
    }
    
    for (NSNetService *service in m_services) {
        if (![services containsObject:service]) {
            [servicesToRemove addObject:service];
            [m_targetSelector removeItemWithTitle:service.hostName];
        }
    }
    
    for (NSNetService *service in servicesToRemove) {
        [m_services removeObject:service];
    }
}

- (IBAction)pausePlayback:(id)sender
{
    [m_handler togglePaused];
}

- (IBAction)stopPlaying:(id)sender
{
    [m_handler stopPlayback];
    [m_playButton setImage:[NSImage imageNamed:@"play.png"]];
}

- (IBAction)updateTarget:(id)sender
{
    NSString *newHostName = [[m_targetSelector selectedItem] title];
    NSNetService *selectedService = nil;
    for (NSNetService *service in m_services) {
        if ([service.hostName isEqualToString:newHostName]) {
            selectedService = service;
        }
    }
    
    [m_handler setTargetService:selectedService];
}

#pragma mark -
#pragma mark AirplayHandlerDelegate functions

- (void)setPaused:(BOOL)paused
{
    if (paused) {
        [m_playButton setImage:[NSImage imageNamed:@"play.png"]];
    } else {
        [m_playButton setImage:[NSImage imageNamed:@"pause.png"]];
    }
}

- (void)positionUpdated:(float)position
{
    self.positionFieldCell.title = [NSString stringWithFormat:@"%u:%.2u:%.2u",
                                    (int)position / 3600, ((int)position / 60) % 60,
                                    (int)position % 60];
}

- (void)durationUpdated:(float)duration
{
    self.durationFieldCell.title = [NSString stringWithFormat:@"%u:%.2u:%.2u",
                                    (int)duration / 3600, ((int)duration / 60) % 60,
                                    (int)duration % 60];
}

- (void)airplayStoppedWithError:(NSError *)error
{
    if (error != nil) {
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
    }
    
    [m_playButton setImage:[NSImage imageNamed:@"play.png"]];
}

#pragma mark -
#pragma mark VideoManagerDelegate functions

- (void)outputReady:(id)sender
{
    [m_handler startAirplay];
}

@end
