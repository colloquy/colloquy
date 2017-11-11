//
//  KAConfiguration.m
//  SocialNetworkView
//
//  Created by Karl Adam on Wed Mar 31 2004.
//  Copyright (c) 2004 matrixPointer. All rights reserved.
//

#import <stdlib.h>
#import "KAConfiguration.h"
#import "../colloquy/JVChatRoom.h"
#import "../colloquy/MVChatConnection.h"

@interface NSColor (KAConfigurationAdditions) 
+ (NSColor *) colorWithHexValue:(NSString *) inColor;
@end

#pragma mark -

@implementation KAConfiguration

- (id) init {
	
	if ( self = [super init] ) {
		properties = nil;
	}
	
	return self;
}

- (id) initWithRoom:(JVChatRoom *) inRoom {

	if ( self = [super init] ) {
		properties = [NSDictionary dictionaryWithObjectsAndKeys:/* Server Stuff */
																[[inRoom connection] nickname],			@"Nickname",
																[[inRoom connection] server],			@"Server",
																[NSNumber numberWithInt:[[inRoom connection] serverPort]], @"Port",
																[inRoom target],						@"ChannelSet",
																/* Miscellaneous Settings */
																[NSNumber numberWithInt:800],			@"OutputWidth",
																[NSNumber numberWithInt:600],			@"OutputHeight",
																[NSString stringWithString:@"~/Documents"], @"OutputDirectory",
																[NSNumber numberWithBool:YES],			@"CreateCurrent",
																[NSNumber numberWithBool:YES],			@"CreateArchive",
																[NSNumber numberWithBool:YES],			@"CreateRestorePoints",
																/* Colors */
																[NSColor colorWithHexValue:@"#ffffff"], @"BackgroundColor",
																[NSColor colorWithHexValue:@"#eeeeff"], @"ChannelColor",
																[NSColor colorWithHexValue:@"#000000"], @"LabelColor",
																[NSColor colorWithHexValue:@"#9999cc"], @"TitleColor",
																[NSColor colorWithHexValue:@"#ffff00"], @"NodeColor",
																[NSColor colorWithHexValue:@"#6666FF"], @"EdgeColor",
																[NSColor colorWithHexValue:@"#666666"], @"BorderColor",
																/* Mean Op Setting */
																[NSSet set],							@"IgnoreSet",
																/* Advanced Settings */
																[NSNumber numberWithInt:5],				@"TemporalProximityDistance",
																[NSNumber numberWithDouble:0.02],		@"TemporalDecayAmount",
																[NSNumber numberWithDouble:2.0],		@"K",
																[NSNumber numberWithDouble:0.01],		@"C",
																[NSNumber numberWithDouble:6.0],		@"MaxRepulsiveForceDistance",
																[NSNumber numberWithDouble:0.5],		@"MaxNodeMovement",
																[NSNumber numberWithDouble:10.0],		@"MinDiagramSize",
																[NSNumber numberWithInt:50],			@"BorderSize",
																[NSNumber numberWithInt:5],				@"NodeRadius",
																[NSNumber numberWithDouble:0],			@"EdgeThreshold",
																[NSNumber numberWithBool:YES],			@"ShowEdges",
																[NSNumber numberWithBool:YES],			@"Verbose",
																[NSString stringWithString:@"UTF-8"],   @"Encoding",
																nil];
	}
	
	return self;
}

- (id) initWithDictionary:(NSDictionary *) inDictionary {
	
	if ( self = [super init] ) {
		[inDictionary retain];
		properties = inDictionary;
	}
	
	return self;
}

- (id) initWithFile:(NSString *) filePath {

	if ( self = [super init] ) {
		properties = [NSDictionary dictionaryWithContentsOfFile:filePath];
	}
	
	return self;
}

- (void) dealloc {
	[properties release];
	properties = nil;
	
	[super dealloc];
}

- (void) saveToFile:(NSString *) inPath {
	[properties writeToFile:inPath atomically:YES];
}

#pragma mark Internal Convenience Methods

- (int) getIntForKey:(NSString *) key {
	int retVal = -1;
	NSNumber *num = [properties objectForKey:key];
	
	if ( num ) {
		retVal = [num intValue];
	}
	
	return retVal;
}

- (double) getDoubleForKey:(NSString *) key {
	int retVal = -1.0;
	NSNumber *num = [properties objectForKey:key];
	
	if ( num ) {
		retVal = [num doubleValue];
	}
	
	return retVal;
}

- (BOOL) getBOOLForKey:(NSString *) key {
	BOOL retVal = NO;
	NSNumber *num = [properties objectForKey:key];
	
	if ( num ) {
		retVal = [num boolValue];
	}
	
	return retVal;
}

- (NSColor *) getColorForKey:(NSString *) key {
	return (NSColor *)[properties objectForKey:key];
}

- (NSSet *) getSetKorKey:(NSString *) key {
	return (NSSet *)[properties objectForKey:key];
}

- (NSString *) getStringForKey:(NSString *) key {
	return (NSString *)[properties objectForKey:key];
}

#pragma mark Public Accessors
- (double) temporalDecayAmount {
	return [self getDoubleForKey:@"TemporalDecayAmount"];
}

- (double) k {
	return [self getDoubleForKey:@"K"];
}

- (double) c {
	return [self getDoubleForKey:@"C"];
}

- (double) maxRepulsiveForceDistance {
	return [self getDoubleForKey:@"MaxRepulsiveForceDistance"];
}

- (double) maxNodeMovement {
	return [self getDoubleForKey:@"MaxNodeMovement"];
}

- (double) minDiagramSize; {
	return [self getDoubleForKey:@"MinDiagramSize"];
}

@end

@implementation NSColor (KAConfigurationAdditions) 

int hexToInt (char hex) {
    if(hex >= '0' && hex <= '9'){
        return(hex - '0');
    }else if(hex >= 'a' && hex <= 'f'){
        return(hex - 'a' + 10);
    }else if(hex >= 'A' && hex <= 'F'){
        return(hex - 'A' + 10);
    }else{
        return(0);
    }
}

+ (NSColor *) colorWithHexValue:(NSString *) inColor {
    const char	*hexString = [inColor cString];
    float 	red, green, blue;
	
    if( hexString[0] == '#'){
        red = ( hexToInt(hexString[1]) * 16 + hexToInt(hexString[2]) ) / 255.0;
        green = ( hexToInt(hexString[3]) * 16 + hexToInt(hexString[4]) ) / 255.0;
        blue = ( hexToInt(hexString[5]) * 16 + hexToInt(hexString[6]) ) / 255.0;
    } else {
        red = ( hexToInt(hexString[0]) * 16 + hexToInt(hexString[1]) ) / 255.0;
        green = ( hexToInt(hexString[2]) * 16 + hexToInt(hexString[3]) ) / 255.0;
        blue = ( hexToInt(hexString[4]) * 16 + hexToInt(hexString[5]) ) / 255.0;
    }
	
    return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0];
}

@end