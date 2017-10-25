//
//  PFMoveApplication.m
//  LetsMove
//
//  Created by Andy Kim at Potion Factory LLC on 9/17/09
//
//  The contents of this file are dedicated to the public domain.

#import "PFMoveApplicationController.h"

static NSString *AlertSuppressKey = @"moveToApplicationsFolderAlertSuppress";

void showFailureAlert(void);
void PFMoveToApplicationsFolderIfNecessary(void)
{
	// Don't run on Tiger.
	if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4)
		return;

	// Skip if user supressed the alert before
	if ([[NSUserDefaults standardUserDefaults] boolForKey:AlertSuppressKey]) return;
	
	// Path of the bundle
	NSString *path = [[NSBundle mainBundle] bundlePath];
	
	// Get all Applications directories, most importantly ~/Applications
	NSArray *allApplicationsDirectories = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSAllDomainsMask, YES);
	
	// If the application is already in some Applications directory, skip.
	// Also, skip if running from a build/ directory.
	NSEnumerator *enumerator = [allApplicationsDirectories objectEnumerator];
	NSString *appDirPath = nil;
	while ((appDirPath = [enumerator nextObject])) {
		if ([path hasPrefix:appDirPath]) return;
		if ([path hasCaseInsensitiveSubstring:@"build"]) return;
	}
	
	// Since we are good to go, get /Applications
	NSString *applicationsDirectory = [NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES) lastObject];
	if (applicationsDirectory == nil) {
		NSLog(@"ERROR -- Could not find the Applications directory");
		showFailureAlert();
		return;
	}
	
	NSString *appBundleName = [path lastPathComponent];
	NSError *error = nil;
	
	// Open up the alert
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:NSLocalizedString(@"Move to Applications folder?", nil)];
	[alert setInformativeText:NSLocalizedString(@"I can move myself to the Applications folder if you'd like. This will keep your Downloads folder uncluttered.", nil)];
	[alert setShowsSuppressionButton:YES];
	[[[alert suppressionButton] cell] setControlSize:NSSmallControlSize];
	[[[alert suppressionButton] cell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[alert addButtonWithTitle:NSLocalizedString(@"Move to Applications Folder", nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"Do Not Move", nil)];
	
	if ([alert runModal] == NSAlertFirstButtonReturn) {
		NSLog(@"Moving myself to the Applications folder");
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *destinationPath = [applicationsDirectory stringByAppendingPathComponent:appBundleName];
		
		// If a copy already exists in /Applications, put it in the Trash
		if ([fm fileExistsAtPath:destinationPath]) {
			if (![[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
															  source:applicationsDirectory
														 destination:@""
															   files:@[appBundleName]
																 tag:NULL]) {
				NSLog(@"ERROR -- Could not trash '%@'", destinationPath);
				showFailureAlert();
				return;
			}
		}
		
		// Copy myself to /Applications
		if (![fm copyItemAtPath:path toPath:destinationPath error:&error]) {
			NSLog(@"ERROR -- Could not copy myself to /Applications (%@)", error);
			showFailureAlert();
			return;
		}
		
		// Put myself in Trash
		if (![[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
														  source:[path stringByDeletingLastPathComponent]
													 destination:@""
														   files:@[appBundleName]
															 tag:NULL]) {
			NSLog(@"ERROR -- Could not trash '%@'", path);
			showFailureAlert();
			return;
		}
		
		// Relaunch
		NSString *executableName = [[[NSBundle mainBundle] executablePath] lastPathComponent];
		NSString *relaunchPath = [destinationPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Contents/MacOS/%@", executableName]];
		
		[NSTask launchedTaskWithLaunchPath:relaunchPath
								 arguments:@[destinationPath,
											[NSString stringWithFormat:@"%d", [[NSProcessInfo processInfo] processIdentifier]]]]; // The %d is not a 64-bit bug. The call to processIdentifier returns an int
		[NSApp terminate:nil];
	}
	else {
		// Save the alert suppress preference if checked
		if ([[alert suppressionButton] state] == NSOnState) {
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:AlertSuppressKey];
		}
	}
	
	return;
}

void showFailureAlert()
{
 // Show failure message
 NSAlert *alert = [[NSAlert alloc] init];
 [alert setMessageText:NSLocalizedString(@"Could not move to Applications folder", nil)];
 [alert runModal];
}
