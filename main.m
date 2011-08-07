//
//  main.m
//  ultra43
//
//  Created by msftguy on 1/17/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
#include "substrate.h"
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <stdio.h>

static FILE * (*s_orig_fopen) ( const char * filename, const char * mode );

static const char* xgold_libname = "/usr/share/ultrasn0w/ultrasn0w-xgold608.dylib";

static void* s_orig_findReference;
static size_t (*s_orig_FindLastThumbFunction)(size_t, int);

#define LOGPREFIX "ultrasn0w_fixer: "

typedef struct {size_t symOff; size_t refOff; size_t thumbFn_start;} REF_ENTRY;

REF_ENTRY ref_table[] = {
//	//ARMv7 Beta1
//	//"+xsimstate=1"
//	{0xEBA7C, 0x33850}, 
//	//"Sending internal notification %s (%d) params={%d, %d, %p}"
//	{0xF2B1C, 0x5F5D0}, 
//	//"activation ticket accepted... drive thru"
//	{0xEB9E4, 0x3341C},
//	
//	//ARMv7 Beta2
//	//"+xsimstate=1"
//	{0xEC844, 0x033308},
//	//"Sending internal notification %s (%d) params={%d, %d, %p}"
//	{0xF38F4, 0x05F1E0}, 
//	//"activation ticket accepted... drive thru"
//	{0xEC7AC, 0x32ED4},
//    
//    //iOS5 Beta1
//    //"+xsimstate=1"
//	{0x10737A, 0x302A8},
//	//"Sending internal notification %s (%d) params={%d, %d, %p}"
//	{0x10F782, 0x5FB30, 0x5FA85}, 
//	//"activation ticket accepted... drive thru"
//	{0x107396, 0x2F54C},
//    
//    //iOS5 Beta2
//    //"+xsimstate=1"
//	{0xF1CE0, 0x2FFE0},
//	//"Sending internal notification %s (%d) params={%d, %d, %p}"
//	{0xFB240, 0x60744, 0x60699}, 
//	//"activation ticket accepted... drive thru"
//	{0xF1C50, 0x2F33C},
//    
//    //iOS5 Beta3
//    //"+xsimstate=1"
//	{0x18B8D2, 0x45850, 0x457A9},
//	//"Sending internal notification %s (%d) params={%d, %d, %p}"
//	{0x193593, 0x9A250, 0x9A1B1}, 
//	//"activation ticket accepted... drive thru"
//	{0x18B84A, 0x43F46, 0x43D81},
//    
//    //iOS5 Beta4
//    //"+xsimstate=1"
//	{0x117882, 0x3269E, 0x32631},
//	//"Sending internal notification %s (%d) params={%d, %d, %p}"
//	{0X11F848, 0x64F54, 0x64EA1}, 
//	//"activation ticket accepted... drive thru"
//	{0x1177FA, 0x31AD2, 0x31899},

    //iOS5 Beta5
    //"+xsimstate=1"
	{0x11C16B, 0x34492, 0x34425},
	//"Sending internal notification %s (%d) params={%d, %d, %p}"
	{0x12423F, 0x67294, 0x671E1}, 
	//"activation ticket accepted... drive thru"
	{0x11C0E3, 0x338C6, 0x3368D},

};

static size_t my_FindReference(size_t addr)
{
	int slide = _dyld_get_image_vmaddr_slide(0);
	size_t symOff = addr - slide;
	size_t refOff = 0;
	for (int i = 0; i < sizeof(ref_table) / sizeof(REF_ENTRY); ++i) {
		if (ref_table[i].symOff == symOff) {
			refOff = ref_table[i].refOff;
			break;
		}
	}
	if (refOff == 0) {
		fprintf(stderr, LOGPREFIX "my_FindReference failed for 0x%lx\n", symOff);
		return NULL;
	}
	fprintf(stderr, LOGPREFIX "my_FindReference OK for 0x%lx: 0x%x + 0x%lx\n", symOff, slide, refOff);
	return slide + refOff;
}

static size_t my_FindLastThumbFunction(size_t start, int maxlen)
{
    size_t result = 0;
    int slide = _dyld_get_image_vmaddr_slide(0);
    size_t refOff = start - slide;
    size_t fnStart = 0;
    // FindLastThumbFunction doesn't want to detect 0xF0 0xB5 as a prolog ?
	for (int i = 0; i < sizeof(ref_table) / sizeof(REF_ENTRY); ++i) {
		if (ref_table[i].refOff == refOff) {
			fnStart = ref_table[i].thumbFn_start;
			break;
		}
	}

    if (fnStart != 0)
        result = slide + fnStart;
    else
        result = s_orig_FindLastThumbFunction(start, maxlen);
    fprintf(stderr, LOGPREFIX "FindLastThumbFunction(0x%lx, 0x%x) = 0x%lx [+0x%x]%s", 
            start - slide, maxlen, result - slide, slide, fnStart ? " **fixed**":"");
    return result;
}

void hook_ultrasn0w()
{
	static bool hooked = false;
	if (hooked)
		return;
	// FIXME: something needs to be changed on iPhone4
	void* ultrasn0w608_lib = dlopen(xgold_libname, RTLD_LAZY);
	if (!ultrasn0w608_lib) {
		fprintf(stderr, LOGPREFIX "dlopen(%s) FAILED\n", xgold_libname);
		return;
	}
	void* pfnFindReference = dlsym(ultrasn0w608_lib, "FindReference");
	if (!pfnFindReference) {
		fprintf(stderr, LOGPREFIX "dlsym('FindReference') FAILED\n");
		return;
	}
	MSHookFunction(pfnFindReference, my_FindReference, &s_orig_findReference);
	fprintf(stderr, LOGPREFIX "hooked FindReference\n");
    
	void* pfnFindLastThumbFunction = dlsym(ultrasn0w608_lib, "FindLastThumbFunction");
	if (!pfnFindLastThumbFunction) {
		fprintf(stderr, LOGPREFIX "dlsym('FindLastThumbFunction') FAILED\n");
		return;
	}
	MSHookFunction(pfnFindLastThumbFunction, my_FindLastThumbFunction, &s_orig_FindLastThumbFunction);
	fprintf(stderr, LOGPREFIX "hooked FindLastThumbFunction\n");
    
	hooked = true;	
}

FILE * my_fopen ( const char * filename, const char * mode )
{
	if ((filename != NULL) && 
        (0 == strcmp(filename, "/var/wireless/Library/Logs/ultrasn0w-dylib.log"))) 
    {
        hook_ultrasn0w();
    }
	return s_orig_fopen(filename, mode);
}

void entry()  __attribute__ ((constructor));

void entry() {
	fprintf(stderr, LOGPREFIX "loaded\n");
	MSHookFunction(fopen, my_fopen, &s_orig_fopen);
}
