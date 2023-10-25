# rd_route  
[![Build Status](https://travis-ci.org/rodionovd/rd_route.svg?branch=master)](https://travis-ci.org/rodionovd/rd_route)  
Replace (aka «hook» or «override» or «route») implementation of any C function in runtime. Works on MacOS with Mach–O binaries.

**⚠ Might not work for you, it's experimental. You may also wan't to checkout [ChickenHook](https://github.com/ChickenHook/ChickenHook) 🤔**

Architectures: x86_64, ARM64 and even i386.

### Usage

```c
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include "rd_route.h"

static char* my_strerror(int err)
{
  return "It's OK";
}

static char* my_super_strerror(int err)
{
  return "It's super OK";
}

int main (void)
{

    void *(*original)(int) = NULL;
    int err = 2;

    // hook strerror with my_strerror and backup implementation at original
    rd_route(strerror, my_strerror, (void **)&original);
    
    // See if the patch works
    assert(0 == strcmp("It's OK", strerror(err)));

    // See if an original implementation is still available
    assert(0 == strcmp("No such file or directory", original(err)));


    // hook my_strerror by name with my_super_strerror and backup patched implementation at original
    rd_route_byname("my_strerror", NULL, my_super_strerror, (void **)&original);

    // See if the patch by name works
    assert(0 == strcmp("It's super OK", my_strerror(err)));
    assert(0 == strcmp("It's super OK", strerror(err)));

    // See if an original patched implementation is still available
    assert(0 == strcmp("It's OK", original(err)));

    return 0;
}
```

### Integration
 
#### Using git submodules

```bash
$ cd /your/project/path
$ git submodule add https://github.com/rodionovd/rd_route
```
#### Not using git submodules  

Just copy `rd_route.h` and `rd_route.c` files into your project's directory.  

----

### But wait, we already have `mach_override` for this stuff

I've created this library because [`mach_override`](https://github.com/rentzsch/mach_override) requires an external disassembler in order to work properly. For those of us who don't want another few thousands of lines of foreign code in their projects, the only option is to hard-code every function prologue they know in order to patch it correctly — which isn't a great alternative to have, to be honest.

### Credits

 * The source code is based on Landon Fuller's (@landonf) gorgeous [`libevil`](https://github.com/landonf/libevil_patch) library.  
  
 * I'm also glade we have Jonathan 'Wolf' Rentzsch out there with his classy [`mach_override`](https://github.com/rentzsch/mach_override) :+1:  

------

If you found any bug(s) or something, please open an issue or a pull request — I'd appreciate your help! `(^,,^)`

------

*Dmitry Rodionov, 2014-2015*
*i.am.rodionovd@gmail.com*

