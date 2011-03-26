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

static char* (*s_orig_getsectdatafromheader) (
							   const struct mach_header* mhp,
							   const char* segname,
							   const char* sectname,
							   uint32_t* size);

static const char* xgold_libname = "/var/stash/share/ultrasn0w/ultrasn0w-xgold608.dylib";

typedef struct {size_t symOff; size_t refOff;} REF_ENTRY;

REF_ENTRY ref_table[] = {
	//"+xsimstate=1"
	{0xED758, 0x034548},
	//"Sending internal notification %s (%d) params={%d, %d, %p}"
	{0xF47AC, 0x06039C},
	//"activation ticket accepted... drive thru"
	{0xED6C0, 0x34114},
	
	
	
	
};

static char* my_FindReference(char* addr)
{
	char* slide = _dyld_get_image_vmaddr_slide(0);
	size_t symOff = addr - slide;
	size_t refOff = 0;
	for (int i = 0; i < sizeof(ref_table) / sizeof(REF_ENTRY); ++i) {
		if (ref_table[i].symOff == symOff) {
			refOff = ref_table[i].refOff;
			break;
		}
	}
	if (refOff == 0) {
		fprintf(stderr, "ultrasn0w_on_4.3_fixer: my_FindReference failed for %x\n", symOff);
		return NULL;
	}
	fprintf(stderr, "ultrasn0w_on_4.3_fixer: my_FindReference OK for %x: %x + %x\n", symOff, slide, refOff);
	return slide + refOff;
}

void hook_ultrasn0w()
{
	static bool hooked = false;
	if (hooked)
		return;
	// FIXME: something needs to be changed on iPhone4
	void* ultrasn0w608_lib = dlopen(xgold_libname, RTLD_LAZY);
	if (!ultrasn0w608_lib) {
		fprintf(stderr, "ultrasn0w_on_4.3_fixer: dlopen(%s) FAILED\n", xgold_libname);
		return;
	}
	void* pfnFindReference = dlsym(ultrasn0w608_lib, "FindReference");
	if (!pfnFindReference) {
		fprintf(stderr, "ultrasn0w_on_4.3_fixer: dlsym('FindReference') FAILED\n");
		return;
	}
	fprintf(stderr, "ultrasn0w_on_4.3_fixer: hooked FindReference\n");
	MSHookFunction(pfnFindReference, my_FindReference, &s_orig_getsectdatafromheader);
	hooked = true;	
}

char* my_getsectdatafromheader(
							const struct mach_header* mhp,
							const char* segname,
							const char* sectname,
							uint32_t* size)
{
	if (mhp == (const struct mach_header*)0x1000) {
		hook_ultrasn0w();
		return _dyld_get_image_vmaddr_slide(0) + getsectdata(segname, sectname, size);
	} else {
		return s_orig_getsectdatafromheader(mhp, segname, sectname, size);
	}
}

void entry()  __attribute__ ((constructor));

void entry() {
	fprintf(stderr, "ultrasn0w_on_4.3_fixer loaded\n");
	MSHookFunction(getsectdatafromheader, my_getsectdatafromheader, &s_orig_getsectdatafromheader);
}
