/*
* validate.c part of tcosxmlrpc
* Copyright (C) 2006,2007,2008  mariodebian at gmail
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License
* as published by the Free Software Foundation; either version 2
* of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

/*
 * validate.c
 *
 * Validate a username/pw combination, using the /etc/shadow
 * file.
 *
 * Two lines are read from stdin.  The first is the user, and
 * the second is the (unencrypted) password.
 *
 * We exit with 0 if they match, 1 otherwise.
 * Errors are written to either stderr or the error log, or both.
 */


#include "common.h"
#include "debug.h"
#include "validate.h"

#include <shadow.h>


#include "validate-passwd.c"
#include "validate-shadow.c"
#include "validate-tcos.c"



char
*validate_login(char *user, char*pw)
{
/* check for files in order */
   if ( check_for_file("/etc/tcospasswd") == 1 ) {
     dbgtcos("info validate_login(): /etc/tcospasswd exists.\n");
     return validate_tcos(user, pw);
   }
#ifndef IS_STANDALONE
   /* only use /etc/shadow or /etc/passwd in thin clients environments */
   else if ( check_for_file("/etc/shadow") == 1 ) {
     dbgtcos("info validate_login(): /etc/shadow exists.\n");
     return validate_shadow(user, pw);
   }
   else if ( check_for_file("/etc/passwd") == 1 ) {
     dbgtcos("info validate_login(): /etc/passwd exists.\n");
     return validate_passwd(user, pw);
   }
#endif
   else {
     dbgtcos("error validate_login(): no files found.\n");
     return (char*) LOGIN_ERROR;
   }

  return (char*) LOGIN_ERROR;
}

