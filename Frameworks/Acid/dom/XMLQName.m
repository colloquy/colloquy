//============================================================================
// 
//     License:
// 
//     This library is free software; you can redistribute it and/or
//     modify it under the terms of the GNU Lesser General Public
//     License as published by the Free Software Foundation; either
//     version 2.1 of the License, or (at your option) any later version.
// 
//     This library is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//     Lesser General Public License for more details.
// 
//     You should have received a copy of the GNU Lesser General Public
//     License along with this library; if not, write to the Free Software
//     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  
//     USA
// 
//     Copyright (C) 2002 Dave Smith (dizzyd@jabber.org)
// 
// $Id: XMLQName.m,v 1.1 2004/07/19 03:49:03 jtownsend Exp $
//============================================================================

#import "acid-dom.h"

@interface XMLQNameManager : NSObject
{
    NSMutableDictionary* _uri_map;
}

// Basic initializers
-(id)   init;
-(void) dealloc;

    // QName accessors
-(XMLQName*) lookup:(NSString*)name withURI:(NSString*)uri;
-(XMLQName*) lookup:(const char*)expatname;
-(XMLQName*) lookup:(const char*)expatname useDefaultURI:(NSString*)uri;
@end

XMLQNameManager* QNManager;

@implementation XMLQName

-(id) initWithName:(NSString*)name inURI:(NSString*)uri
{
    [super init];
    _name = [name retain];
    _uri  = [uri retain];
    return self;
}

-(void) dealloc
{
    [_name release];
    [_uri release];
    [super dealloc];
}

-(NSString*) name
{
    return _name;
}

-(NSString*) uri
{
    return _uri;
}

-(NSString*) description
{
    return [NSString stringWithFormat:@"%@|%@", _uri, _name];
}

-(id) copyWithZone:(NSZone*)zone
{
    // XMLQName objects are immutable
    return [self retain];
}

+(XMLQName*) construct:(NSString*)name withURI:(NSString*)uri
{
    return [QNManager lookup:name withURI:uri];
}

+(XMLQName*) construct:(const char*)name
{
    return [QNManager lookup:name];
}

+(XMLQName*) construct:(const char*)expatname withDefaultURI:(NSString*)uri
{
    return [QNManager lookup:expatname useDefaultURI:uri];
}

-(BOOL) isEqual:(XMLQName*)other
{
    return [self compare:other] == NSOrderedSame;
}

-(NSComparisonResult) compare:(id)other
{
    NSString* other_name = [other name];
    NSString* other_uri  = [other uri];

    NSComparisonResult name_result = [_name compare:other_name];
    if (name_result != NSOrderedSame)
        return name_result;
    else
        return [_uri compare:other_uri];
}



@end

@implementation XMLQNameManager

+(void) load
{
    QNManager = [[XMLQNameManager alloc] init];
}

-(id) init
{
    if (QNManager != nil) {
        [self autorelease];
        [QNManager retain];
        return QNManager;
    }

    [super init];
    _uri_map = [[NSMutableDictionary alloc] init];

    return self;
}

-(void) dealloc
{
    [_uri_map release];
    [super dealloc];
}

-(XMLQName*) lookup:(NSString*)name withURI:(NSString*)uri
{
    NSString* key = [NSString stringWithFormat:@"%@|%@", uri, name];
    XMLQName* result = [_uri_map objectForKey:key];
    if (result == nil)
    {
        result = [[XMLQName alloc] initWithName:name inURI:uri];
        [_uri_map setObject:result forKey:key];
        [result release];
    }
    return result;
}

-(XMLQName*) lookup:(const char*)expatname
{
    NSString* key = [NSString stringWithUTF8String: expatname];
    XMLQName* result = [_uri_map objectForKey:key];
    if (result == nil)
    {
        NSArray* components = [key componentsSeparatedByString:@"|"];
        if ([components count] == 2)
        {
            result = [[XMLQName alloc] initWithName:[components objectAtIndex:1] 
                                       inURI:[components objectAtIndex:0]];
        }
        else
        {
            result = [[XMLQName alloc] initWithName:key inURI:nil];
        }
        [_uri_map setObject:result forKey:key];
        [result release];
    }
    return result;
}

-(XMLQName*) lookup:(const char*)expatname useDefaultURI:(NSString*)uri
{
    if (strchr(expatname, '|') == NULL)
    {
        return [self lookup:[NSString stringWithUTF8String:expatname] withURI:uri];
    }
    else
    {
        return [self lookup:expatname];
    }
}


@end
