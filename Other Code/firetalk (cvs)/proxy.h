// ======================================================================== //
//	proxy.h                              								    //
// ======================================================================== //
// Copyright (C) 2003 Andrew Wellington                                     //
// Created Fri May 09 2003 8:30pm +1000UTC                                  //
// ==License Agreement===================================================== //
// This program is free software; you can redistribute it and/or modify it  //
// under the terms of the GNU General Public License as published by the    //
// Free Software Foundation; either version 2 of the License, or (at your   //
// option) any later version.                                               //
//                                                                          //
// This program is distributed in the hope that it will be useful, but      //
// WITHOUT ANY WARRANTY; without even the implied warranty of               //
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU        //
// General Public License for more details.                                 //
//                                                                          //
// You should have received a copy of the GNU General Public License along  //
// with this program; if not, write to the Free Software Foundation, Inc.,  //
// 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.                //
// ======================================================================== //
// A proxy implementation for firetalk                                      //
// ======================================================================== //

#ifndef _PROXY_H
#define _PROXY_H

enum firetalk_proxy {
	FX_NONE = 0,
	FX_HTTPS,
	FX_SOCKS
};

int firetalk_connect( int s, const struct sockaddr *name, int namelen, enum firetalk_proxy proxyType );

#endif
