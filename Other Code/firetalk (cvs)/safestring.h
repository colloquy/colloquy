/*
safestring.h - FireTalk replacement string functions
Copyright (C) 2000 Ian Gulliver

This program is free software; you can redistribute it and/or modify
it under the terms of version 2 of the GNU General Public License as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/
#ifndef _SAFESTRING_H
#define _SAFESTRING_H

#include <stdlib.h>

size_t safe_strlen(const char * const input);
void *safe_malloc(const size_t size);
void *safe_realloc(void *old, const size_t new);
char *safe_strdup(const char * const input);
void safe_strncpy(char * const to, const char * const from, const size_t size);
void safe_strncat(char * const to, const char * const from, const size_t size);
void safe_snprintf(char *out, const size_t size, char * const format, ...);
int safe_strncasecmp(const char *s1, const char *s2, size_t n);

#endif
