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
// $Id: XPathQuery.m,v 1.1 2004/07/19 03:49:04 jtownsend Exp $
//============================================================================

#import "acid-xpath.h"

// ---------------------------
// XPathQuery
// ---------------------------
@implementation XPathQuery

-(id) initWithPath:(NSString*)path
{
    if ((self = [super init]))
    {
        _expression = [[XPLocation createWithPath:path] retain];
        _path = [path retain];
    }
    return self;
}

-(void) dealloc
{
    [_expression release];
    [_path release];
    [super dealloc];
}

-(NSString*) path
{
    return _path;
}

-(BOOL) matches:(XMLElement*)elem
{
    return [_expression matches:elem];
}

-(NSString*) queryForString:(XMLElement*)elem
{
    NSMutableString* result = [[NSMutableString alloc] init];
    [_expression queryForString:elem withResultBuffer:result];
    if ([result length] == 0)
    {
        [result release];
        return nil;
    }
    else
    {
        [result autorelease];
        return result;
    }
}

-(NSArray*) queryForList:(XMLElement*)elem
{
    NSMutableArray* result = [[NSMutableArray alloc] init];
    [_expression queryForList:elem withResultArray:result];
    if ([result count] == 0)
    {
        [result release];
        return nil;
    }
    else
    {
        [result autorelease];
        return result;
    }
}

-(NSArray*) queryForStringList:(XMLElement*)elem
{
    NSMutableArray* result = [[NSMutableArray alloc] init];
    [_expression queryForStringList:elem withResultArray:result];
    if ([result count] == 0)
    {
        [result release];
        return nil;
    }
    else
    {
        [result autorelease];
        return result;
    }
}

+(BOOL) matches:(XMLElement*)elem xpath:(NSString*)path
{
    XPathQuery* xp = [[XPathQuery alloc] initWithPath:path];
    [xp autorelease];
    return [xp matches:elem];
}

+(NSString*)  queryForString:(XMLElement*)elem xpath:(NSString*)path
{
    XPathQuery* xp = [[XPathQuery alloc] initWithPath:path];
    [xp autorelease];
    return [xp queryForString:elem];
}

+(NSArray*)   queryForList:(XMLElement*)elem xpath:(NSString*)path
{
    XPathQuery* xp = [[XPathQuery alloc] initWithPath:path];
    [xp autorelease];
    return [xp queryForList:elem];
}

+(NSArray*) queryForStringList:(XMLElement*)elem xpath:(NSString*)path
{
    XPathQuery* xp = [[XPathQuery alloc] initWithPath:path];
    [xp autorelease];
    return [xp queryForStringList:elem];
}

@end

