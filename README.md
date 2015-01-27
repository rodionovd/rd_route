## rd_route  
Replace (aka «hook» or «override» or «route») implementation of any C function in runtime. Works on OS X with Mach-O binaries.

> Do not use this code. It can destroy everthing.
> But if you do, I wish you a luck.
  
**NOTE**: `rd_route` **won't work on iOS**.  You should take a look at [`libevil`](https://github.com/landonf/libevil_patch) instead.


### Integration
 
#### Using git submodules

```bash
$ cd /your/project/path
$ git submodule add https://github.com/rodionovd/rd_route
```

#### Using CocoaPods

*Coming soon.*

### Usage 

```c
#include <assert.h>
#include "rd_route.h"


static char* my_strerror(int err)
{
  return "It's OK";
}

int main (void)
{

    void *(*original)(int) = NULL;
    int err = 2;

    printf("Error(%d): %s", err, strerror(err));
    // >> No such file or directory

    rd_route(strerror, my_strerror, (void **)&original);
    
    // See if the patch works
    assert(0 == strcmp("It's OK", strerror(err)));
    // See if an original implementation is still available
    assert(0 == strcmp("No such file or directory", original(err)));

    return 0;
}
```

----

### But wait, we already have `mach_override` for this stuff

I've created this library because [`mach_override`](https://github.com/rentzsch/mach_override) requires an external disassembler in order to work properly. For those of us who don't want another few thousands of lines of foreign code in their projects, the only option to use `mach_override` is to hard-code every function prologue they know in order to patch it correctly — which isn't a great alternative to have, to be honest.

### Credits

 * The source code is based on Landon Fuller's (@landonf) gorgeous [`libevil`](https://github.com/landonf/libevil_patch) library.  
  
 * I'm also glade we have Jonathan 'Wolf' Rentzsch out there with his classy [`mach_override`](https://github.com/rentzsch/mach_override) :+1:  

------

If you found any bug(s) or something, please open an issue or a pull request — I'd appreciate your help! `(^,,^)`

------

*Dmitry Rodionov, 2014-2015*  
*i.am.rodionovd@gmail.com*

