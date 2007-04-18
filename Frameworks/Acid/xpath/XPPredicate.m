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
// $Id: XPPredicate.m,v 1.2 2004/10/16 21:40:05 gbooker Exp $
//============================================================================

#import "acid-xpath.h"
#import "acid-dom.h"
#import "acid-jabber.h"
// ---------------------------
// XP_AttrValue
// ---------------------------
@interface XP_AttrValue : XPPredicate
{
    NSString* _name; 
    NSString* _value;
    BOOL      _invert;
    BOOL      _wildcard;
}
-(id) initWithName:(NSString*)name withValue:(NSString*)value;
-(id) initInvertedWithName:(NSString*)name withValue:(NSString*)value;
-(BOOL) matches:(XMLElement*)elem;
@end

@implementation XP_AttrValue
-(id) initWithName:(NSString*)name withValue:(NSString*)value
{
    [super init];
    _name = [name retain];

    if ([value characterAtIndex:[value length]-1] == '*')
    {
        _wildcard = TRUE;
        _value = [[value substringToIndex:[value length]-1] retain];
    }
    else
    {
        _value = [value retain];
    }

    return self;
}

-(id) initInvertedWithName:(NSString*)name withValue:(NSString*)value
{
    [self initWithName:name withValue:value];
    _invert = YES;
    return self;
}

-(void) dealloc
{
    [_name release];
    [_value release];
    [super dealloc];
}

-(BOOL) matches:(XMLElement*)elem
{
    BOOL result;
    if (_value == nil)
        result = ([elem getAttribute:_name] != nil);
    else
    {
        NSString* v = [elem getAttribute:_name];
        if (_wildcard)
            result = [v hasPrefix:_value];
        else
            result = [v isEqual:_value];
    }
    if (_invert)
    {
        return !result;
    }
    else
        return result;
}
@end
// ---------------------------
// XP_JIDAttrValue
// ---------------------------
@interface XP_JIDAttrValue : XPPredicate
{
    NSString* _name;
    JabberID* _value;
    BOOL      _invert;
    BOOL      _userhostOnly;
}
-(id) initWithName:(NSString*)name withValue:(NSString*)value;
-(id) initInvertedWithName:(NSString*)name withValue:(NSString*)value;
-(BOOL) matches:(XMLElement*)elem;
-(void) selectCompareUserHostOnly:(BOOL)value;
@end

@implementation XP_JIDAttrValue
-(id) initWithName:(NSString*)name withValue:(NSString*)value
{
    [super init];
    _name = [name retain];
    _value = [[JabberID alloc] initWithEscapedString:value];

    return self;
}

-(id) initInvertedWithName:(NSString*)name withValue:(NSString*)value
{
    [self initWithName:name withValue:value];
    _invert = YES;
    return self;
}

-(void) dealloc
{
    [_name release];
    [_value release];
    [super dealloc];
}

-(void) selectCompareUserHostOnly:(BOOL)value
{
    _userhostOnly = value;
}

-(BOOL) matches:(XMLElement*)elem
{
    JabberID* elemJID = [JabberID withString:[elem getAttribute:_name]];
    if (_invert)
    {
        if (_userhostOnly)
            return ![_value isUserhostEqual:elemJID];
        else
            return ![_value isEqual:elemJID];
    }
    else
    {
        if (_userhostOnly)
            return [_value isUserhostEqual:elemJID];
        else
            return [_value isEqual:elemJID];
    }
}
@end


// ---------------------------
// XP_Namespace
// ---------------------------
@interface XP_Namespace : XPPredicate
{
    NSString* _xmlns;
}
-(id) initWithNS:(NSString*)namespace;
-(BOOL) matches:(XMLElement*)elem;
@end

@implementation XP_Namespace
-(id) initWithNS:(NSString*)namespace
{
    [super init];
    _xmlns = [namespace retain];
    return self;
}

-(void) dealloc
{
    [_xmlns release];
    [super dealloc];
}

-(BOOL) matches:(XMLElement*)elem
{
    return ([[elem uri] isEqual:_xmlns]);
}
@end

// ---------------------------
// XPPredicate
// ---------------------------
@implementation XPPredicate

+(XPPredicate *) createWithToken:(NSMutableString*)pathtoken
{
    XPPredicate *result = nil;
    NSString* token;
    NSString* value;
    BOOL      shouldInvert = NO;
    BOOL      userhostOnly = NO;
    int index = 1;

    // Check for ! operator
    if ([pathtoken characterAtIndex:index] == '!')
    {
        shouldInvert = YES;
        index++;
    }

    switch ([pathtoken characterAtIndex:index])
    {
    case '%':
        // Namespace filter
        [pathtoken deleteCharactersFromIndex:0 toIndex:2];
        token = [pathtoken nextTokenDelimitedBy:@"]"];
        result = [[XP_Namespace alloc] initWithNS:token];
        [pathtoken deleteCharactersFromIndex:0 toIndex:1];
        break;
    case '@':
        // Attribute exists or attribute value
        [pathtoken deleteCharactersFromIndex:0 toIndex:index+1];
        token = [pathtoken nextTokenDelimitedBy:@"=]"];

        // See if there is an attribute value
        if ([pathtoken characterAtIndex:0] == '=')
        {
            NSString* value2;
            assert ([pathtoken characterAtIndex:1] == '\'');

            // Remove value delimiter and quote
            [pathtoken deleteCharactersFromIndex:0 toIndex:2];

            // Get value token
            value2 = [pathtoken nextTokenDelimitedBy:@"'"];

            // Remove final quote and predicate closer
            [pathtoken deleteCharactersFromIndex:0 toIndex:2];

            if (shouldInvert)
                result = [[XP_AttrValue alloc] initInvertedWithName:token
                                                          withValue:value2];
            else
                result = [[XP_AttrValue alloc] initWithName:token
                                                  withValue:value2];
        }
        // No attribute value, just checking for existence
        else
        {
            // Remove predicate closer
            [pathtoken deleteCharactersFromIndex:0 toIndex:1];
            if (shouldInvert)
                result = [[XP_AttrValue alloc] initInvertedWithName:token withValue:nil];
            else
                result = [[XP_AttrValue alloc] initWithName:token withValue:nil];
        }
        break;
    case '$':
        // Oh boy, another hack! Check for another $ -- in the secret language of JQuery,
        // two $$ means to check the userhost _only_ of a JID. :)
        userhostOnly = [pathtoken characterAtIndex:index+1] == '$';

        // Move to next index if userhostOnly; thus skipping second $
        if (userhostOnly)
            index++;
        
        // Attribute exists or attribute value
        [pathtoken deleteCharactersFromIndex:0 toIndex:index+1];
        token = [pathtoken nextTokenDelimitedBy:@"="];

        assert([pathtoken characterAtIndex:0] == '=');
        assert([pathtoken characterAtIndex:1] == '\'');

        // Remove value delimiter and quote
        [pathtoken deleteCharactersFromIndex:0 toIndex:2];

        // Get value token
        value = [pathtoken nextTokenDelimitedBy:@"'"];

        // Remove final quote and predicate closer
        [pathtoken deleteCharactersFromIndex:0 toIndex:2];

        if (shouldInvert)
            result = [[XP_JIDAttrValue alloc] initInvertedWithName:token
                                                         withValue:value];
        else
            result = [[XP_JIDAttrValue alloc] initWithName:token
                                                 withValue:value];

        [(XP_JIDAttrValue*)result selectCompareUserHostOnly:userhostOnly];
        break;
    default:
        NSLog(@"Unknown predicate delimiter:%c. Aborting.", [pathtoken characterAtIndex:index]);
        assert(0);
    }

    [result autorelease];
    return result;
}

+(XPPredicate *) createAttributeExists:(NSString*)attributeName
{
    XP_AttrValue* result = [[XP_AttrValue alloc] initWithName:attributeName withValue:nil];
    [result autorelease];
    return result;
}

-(BOOL) matches:(XMLElement*)elem
{
    return NO;
}

@end
