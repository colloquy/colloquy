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
//     Copyright (C) 2002-2003 Dave Smith (dizzyd@jabber.org)
//     Copyright (C) 2002 David Waite (mass@akuma.org)
//
// $Id: JabberID.m,v 1.1 2004/07/19 03:49:03 jtownsend Exp $
//============================================================================

#import "acid.h"
#include <string.h>
#include "stringprep.h"

static NSMutableDictionary* G_cache;

@implementation JabberID

-(id) copyWithZone:(NSZone*)zone
{
    return [self retain];
}

+(BOOL) parseString:(NSString*)jid 
       intoUsername:(NSString**)username 
       intoHostname:(NSString**)hostname
       intoResource:(NSString**)resource
       intoComplete:(NSString**)complete
{
    // stringprep working buf
    char buf[1025];

    // Initialize pointers
    *username = nil;
    *hostname = nil;
    *resource = nil;
    *complete = nil;

    // Convert the complete string into a UTF-8 encoded NSData --
    // needs to be strdup'd since our parsing is somewhat destructive
    char* rawdata = strdup([jid UTF8String]);
    char* cur;

    // Extract resource
    cur = rawdata;
    rawdata = strsep(&cur, "/");
    if ((cur != NULL) && (strlen(cur) > 0))
    {
        strncpy(buf, cur, sizeof(buf)-1);
        if (stringprep_xmpp_resourceprep(buf, sizeof(buf)) != 0)
        {
            free(rawdata);
            return NO;
        }
        *resource = [NSString stringWithUTF8String:buf];
    }

    /* Edge case -- the original string was a single character
       "/" */
    if (rawdata == nil)
    {
        free(rawdata);
        return NO;
    }

    // Extract domain
    cur = rawdata;
    rawdata = strsep(&cur, "@");
    if ((cur != NULL) && (strlen(cur) > 0))
    {
        // Process the hostname first...
        strncpy(buf, cur, sizeof(buf)-1);
        if (stringprep_nameprep(buf, sizeof(buf)) != 0)
        {
            *resource = nil;
            free(rawdata);
            return NO;
        }

        *hostname = [NSString stringWithUTF8String:buf];

        // Only process the username if it's there...
        if ((rawdata != nil) && strlen(rawdata) > 0)
        {
            // Process the username now...
            strncpy(buf, rawdata, sizeof(buf)-1);
            if (stringprep_xmpp_nodeprep(buf, sizeof(buf)) != 0)
            {
                *resource = nil;
                *hostname = nil;
                free(rawdata);
                return NO;
            }
            *username = [NSString stringWithUTF8String:buf];            
        }
    }
    else
    {
        // Hostname only...
        strncpy(buf, rawdata, sizeof(buf)-1);
        if (stringprep_nameprep(buf, sizeof(buf)) != 0)
        {
            *resource = nil;
            free(rawdata);
            return NO;
        }
        *hostname = [NSString stringWithUTF8String:buf];
    }

    free(rawdata);

    // Build a complete string from all the constituent parts
    if (*username && *resource)
    {
        *complete = [NSString stringWithFormat:@"%@@%@/%@", 
                              *username, *hostname, *resource];
    }
    else if (*username)
    {
        *complete = [NSString stringWithFormat:@"%@@%@",
                              *username, *hostname];
    }
    else if (*resource)
    {
        *complete = [NSString stringWithFormat:@"%@/%@",
                              *hostname, *resource];
    }
    else
    {
        *complete = [*hostname retain];
    }
    
    return TRUE;
}

+(void) initialize
{
    G_cache = [[NSMutableDictionary alloc] initWithCapacity:111];
}

-(id) initWithFormat:(NSString*)fmt, ...
{
    va_list argList;
    NSString* fstr;
    id result;

    va_start(argList, fmt);
    fstr = [[NSString alloc] initWithFormat:fmt arguments:argList];
    va_end(argList);

    result = [self initWithString:fstr];
    [fstr release];
    return result;
}


-(id) initWithString:(NSString*)jidstring
{
    if ([jidstring length] == 0)
    {
        [self release];
        return nil;
    }

    // Check for this particular jid string in the cache
    JabberID* result = [G_cache objectForKey:jidstring];
    if (result != nil)
    {
        [self release];
        return [result retain];
    }

    // Ok, this particular string wasn't found -- let's parse
    // and string prep before looking again
    [super init];

    if ([JabberID parseString:jidstring
                  intoUsername:&_username
                  intoHostname:&_hostname
                  intoResource:&_resource
                  intoComplete:&_complete] == NO)
    {
        // Invalid JID
        [self release];
        return nil;
    }

    // Save the values just generated -- so that dealloc works
    // correctly
    [_username retain];
    [_hostname retain];
    [_resource retain];
    [_complete retain];

    // Check the cache for the JID again...
    result = [G_cache objectForKey:_complete];
    if (result != nil)
    {
        // Associate the provided jid string as another
        // key for this JID
        [G_cache setObject:result forKey:jidstring];

        // Cleanup and return the object we found
        [self release];
        return [result retain];
    }
    
    // Pre-compute the hash value
    _hash_value = [_complete hash];

    // Setup a userhost version of this JID, if necessary
    if (_resource != nil)
    {
        // Construct a user@host key to check the cache for
        NSString* key;
        if (_username != nil)
            key = [NSString stringWithFormat:@"%@@%@",
                            _username, _hostname];
        else
            key = _hostname;

        JabberID* uhjid = [G_cache objectForKey:key];
        if (uhjid == nil)
        {
            // No userhost jid found -- make it
            uhjid = [[JabberID alloc] init];
            uhjid->_username = [_username retain];
            uhjid->_hostname = [_hostname retain];
            uhjid->_complete = [key retain];
            uhjid->_hash_value = [key hash];
            
            // Store it in the cache
            [G_cache setObject:uhjid forKey:key];

            // Release this jid -- we'll retain it in just a sec...
            [uhjid release];
        }

        // Save this jid as our own
        _userhost_jid = [uhjid retain];
    }

    // Save the result in the cache -- save it once with the 
    // original string, and once with the proper string prep'd
    // version
    [G_cache setObject:self forKey:_complete];
    [G_cache setObject:self forKey:jidstring];

    return self;
}

-(id) initWithEscapedString:(NSString*)jidstring
{
    return [self initWithString:[XMLCData unescape:[jidstring cString] ofLength:[jidstring length]]];
}


-(id) initWithUserHost:(NSString*)userhost
          andResource:(NSString*)resource
{
    if ([resource length] > 0)
    {
        NSString* tmp = [NSString stringWithFormat:@"%@/%@",
                                  userhost, resource];
        return [self initWithString:tmp];
    }
    else
    {
        return [self initWithString:userhost];
    }
}

+(id) withString:(NSString*)jidstring
{
    return [[[JabberID alloc] initWithString:jidstring] autorelease];
}

+(id) withFormat:(NSString*)fmt, ...
{
    va_list argList;
    NSString* fstr;
    id result;

    va_start(argList, fmt);
    fstr = [[NSString alloc] initWithFormat:fmt arguments:argList];
    va_end(argList);

    result = [self withString:fstr];
    [fstr release];
    return result;
}


+(id) withUserHost:(NSString*)userhost
      andResource:(NSString*)resource
{
    return [[[JabberID alloc] initWithUserHost:userhost
                             andResource:resource] autorelease];
}

-(void) dealloc
{
    [_username release];
    [_hostname release];
    [_resource release];
    [_complete release];

    [_userhost_jid release];

    [super dealloc];
}

-(unsigned) hash
{
    return _hash_value;
}

-(NSString*) hostname
{
    return _hostname;
}

-(NSString*) username
{
    return _username;
}

-(NSString*) userhost
{
    if (_userhost_jid != nil)
        return _userhost_jid->_complete;
    else
        return _complete;
}

-(NSString*) resource
{
    return _resource;
}

-(NSString*) completeID
{
    return _complete;
}

-(NSString*) escapedCompleteID
{
    return [XMLCData escape:_complete];
}

-(NSString*) description
{
    return _complete;
}

-(BOOL) hasResource
{
    return _resource != nil;
}

-(BOOL) hasUsername
{
    return _username != nil;
}

-(JabberID*) userhostJID
{
    if (_userhost_jid)
        return _userhost_jid;
    else
        return self;
}

-(BOOL) isEqual:(JabberID*)other
{
    return [self compare:other] == NSOrderedSame;
}

-(NSComparisonResult) compare:(JabberID*)other;
{
    return [_complete compare:other->_complete];
}

-(NSComparisonResult) compareUserhost:(JabberID*)other
{
    JabberID* my_uhjid = _userhost_jid ? _userhost_jid : self;
    JabberID* other_uhjid = [other userhostJID];
    return [my_uhjid->_complete compare:other_uhjid->_complete];
}

-(BOOL) isUserhostEqual:(JabberID*)other
{
    return [self compareUserhost:other] == NSOrderedSame;
}

-(id) initWithCoder:(NSCoder*) coder
{
    return [self initWithString:[coder decodeObject]];
}

-(void) encodeWithCoder:(NSCoder*) coder
{
    [coder encodeObject:_complete];
}


@end
