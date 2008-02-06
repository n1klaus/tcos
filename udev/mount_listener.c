/*
* mount_listener.c poll file and get changes using a tmp file
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

  Usage:
     mount-listener /proc/mounts /tmp/proc_mounts

   listen in changes of /proc/mounts and return
   device mounted or umounted

  Because kernel >= 2.6.22 have removed this feature

*/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <poll.h>
#include <fcntl.h>

/* variable argument list */
#include <stdarg.h>

#define MSG_BUFF 4096
#define POLL_TIMEOUT 2*1000

/*for usleep */
#include <unistd.h>


#define SAVE_UDEV "/usr/sbin/save-udev.sh"
int found_device=0;


void debug( const char *format_str, ... ) {
    va_list ap;
    va_start( ap, format_str );
    va_end( ap );
    vfprintf(stderr, format_str , ap);
}


int getnumlines( char *fname )
{
  FILE *fp;
  int lines=0;
  char line[MSG_BUFF];
  fp=fopen(fname, "r");
  if(!fp) return -1;
  while ( fgets(line, MSG_BUFF, fp) != NULL ) {
   ++lines;
  }
  fclose(fp);
  debug("  DEBUG: getnumlines of '%s' %d\n", fname, lines);
  return lines;
}



void print_dev(char *device, char *txt, char *action) {
    int i;
    char *output;
    char *cmd;
    for ( i=0; i<strlen(txt); i++) {
     if ( txt[i] == ' ') {
        output[i]='\0';
        break;
     }
     output[i]=txt[i];
  }
  debug("DEBUG: output \"%s %s\"\n", output, action);
  sprintf(cmd, "%s %s %s", SAVE_UDEV, output, action);
  system(cmd);
}


void sync_files(char *fname1, char *fname2){
    FILE *in, *out;
    char ch;

    if((in=fopen(fname1, "rb")) == NULL) {
        debug("Cannot open input file.\n");
        return;
    }
    if((out=fopen(fname2, "wb")) == NULL) {
        debug("Cannot open output file.\n");
        return;
    }
  
    while(!feof(in)) {
    ch = getc(in);
    if(ferror(in)) {
      debug("Read Error");
      clearerr(in);
      break;
    } else {
      if(!feof(in)) putc(ch, out);
      if(ferror(out)) {
        debug("Write Error");
        clearerr(out);
        break;
      }
    }
  }
  fclose(in);
  fclose(out);
  debug(" DEBUG: sync_files() done...\n");
}
  


int compare(char *fname1, char *fname2)
{
    int n1, n2;
    char lineold[MSG_BUFF];
    char linenew[MSG_BUFF];
    char *old, *new;
    FILE *fpold, *fpnew;
    char *device;
    int dev=0;
    char *action="";

    n1=n2=0;
    n1=getnumlines(fname1);
    n2=getnumlines(fname2);
    if (n1 == -1 || n2 == -1) {
        debug("DEBUG: error reading number of lines n1=%d, n2=%d\n", n1, n2);
        return -1;
    }

    if (n1 == n2) {
        debug("DEBUG: warning, files have the same number of lines %d\n", n1);
        return 1;
    }

    if (n1 > n2) {
        /* mount */
        old=fname1;
        new=fname2;
        action="mount";
    }

    if (n1 < n2) {
        /* umount */
        debug("DEBUG: compare UMOUNT, diff=%d\n", n2-n1);
        old=fname2;
        new=fname1;
        action="umount";
    }
  
  
   
    /* open file that contain extra lines */
    fpold=fopen(old, "r");
    while ( fgets(lineold, MSG_BUFF, fpold) != NULL ) {
        dev=0;
        fpnew=fopen(new, "r");
        while (fgets(linenew, MSG_BUFF, fpnew) != NULL ) {
            if ( strcmp(linenew, lineold) == 0) {
                //debug("   DEBUG: linenew \"%s\"found\n", linenew);
                dev=1;
                break;
            }
        }
        
        if (dev == 0) {
            debug("   DEBUG: lineold not found %s", lineold);
            print_dev(device, lineold, action);
            
        }
        fclose(fpnew);
    }
    fclose(fpold);
    sync_files(fname1, fname2);
    debug("  DEBUG: end of compare() \n");
    return 0;
}


int main (int argc, char *argv[]) {
  debug("DEBUG: *** comparing: %s <=> %s\n", argv[1], argv[2]);
  sync_files(argv[1], argv[2]);
  
  int fd_file;
  struct pollfd fdarray[1];
  int nfds, rc;

  if ((fd_file = open(argv[1], O_RDONLY, 0)) < 0) {
     perror("Error opening file");
     return -1;
  }

  for (;;) {
    fdarray[0].fd = fd_file;
    fdarray[0].events = POLLIN;
    nfds = 1;

    rc = poll(fdarray, nfds, POLL_TIMEOUT);
    
    /*debug("DEBUG: rc is %d nfds is %d\n", rc, nfds);*/

    if (rc < 0) {
     perror("error reading poll() \n");
     return -1;
    }

    if(rc > 0) {
     debug("  DEBUG: Changes detected at %s rc=%d\n", argv[1], rc);
     usleep(200);   
     compare(argv[1], argv[2]);
    }
  }

  // never here
  return 0;
}



