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
//============================================================================

void init_key_caches(void);
const char* cache_public_key(const char* id, ESessionKeyType keytype, 
                             const char* fingerprint);
const char* find_public_fingerprint(const char* id, 
                                    ESessionKeyType keytype);
const char* cache_personal_key(ESessionKeyType keytype, EVP_PKEY* pkey,
                               char* fingerprint, char* public_key);
