/*
* vlc.h part of tcosxmlrpc
*   => common headers of vlc.c
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



/* xmlrpc methods of VLC */
#define VLC_CONTROLLER TCOS_PATH"/vlc-controller.sh"

#define VLC_ERROR "error: vlc command error"
#define VLC_OK "ok"

#if NEWAPI
xmlrpc_value *tcos_vlc(xmlrpc_env *const env, xmlrpc_value *const in, void *const serverContext);
#else
xmlrpc_value *tcos_vlc(xmlrpc_env *env, xmlrpc_value *in, void *ud);
#endif
