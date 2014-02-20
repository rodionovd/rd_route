> Do not use this code. It can destroy everthing.  
> But if you do, I wish you a luck.

`rd_route` is a tiny library for runtime replacing an implementation of *(quite)* any C function (keeping the original imp if you'd like to) in **OS X**'s Mach-O executables.

The source code is based on Landon Fuller's (@landonf) gorgeous [`libevil`](https://github.com/landonf/libevil_patch) library.

**NOTE**: `rd_route` **won't work on iOS**.  You should take a look at `libevil` instead.

## Exported functions  

### rd_route()
`int rd_route(void *function, void *replacement, void **original_ptr)`  

Override `function` to jump directly into `replacement` location. Caller can later access an original function's implementation via `original_ptr` (if passed).  

##### Arguments  

 Argument   | Type (in/out) | Description  
 :--------: | :-----------: | :----------  
 `function` | in  | _**(required)**_ pointer to a function to override  
 `replecement` | in| _**(required)**_ pointer to new implementation  
 `original_ptr` | out | *(optional)* will be set to an address of the original implementation's copy. 
 
Note that `original_ptr` won't be equal to `function` due to remapping the latter into a different memory space.

##### Under the hood  

1. It calls `rd_duplicate_function()` ([see below](#rd_duplicate_function)) to remap an entire macho image, containing the `function` to  override, into a new memory address
2. The first bytes at `function` address are patched with  a JMP instruction to the `replacement` address *(using a relative jump (0xE9) for i386 and an absolyte one (0xFF) for x86_64)*.  
3. The `original` pointer (if passed) is set to the remapped location of the `function` implementation.  
  
##### Usage  
```c
#include "rd_route.h"

static char* my_strerror(int err)
{
  return "It's OK";
}

. . .

void *(*original)(int) = NULL;
int err = 2;

printf("Error(%d): %s", err, strerror(err));
// >> No such file or directory

rd_route(strerror, my_strerror, (void **)&original);

printf("Error(%d): %s", err, strerror(err));
// >> "It's OK"
printf("Error(%d): %s", err, original(err));
// >> No such file or directory  
```    
------  
   
### rd_duplicate_function()
`int rd_duplicate_function(void *function, void **duplicate)`]

Copy `function` implementation into another (first available) memory region.  

##### Arguments  

 Argument   | Type (in/out) | Description  
 :--------: | :-----------: | :----------  
 `function` | in  | _**(required)**_ pointer to a function to override  
 `duplicate` | out| _**(required)**_ will be set to an address of the function's implementation copy  
 
##### Under the hood  

1. Remaps an entire mach-o image (containing the `function` address) into some new location *(for now, it's just a first available memory space we can find)*.  
2. Sets a `duplicate` pointer to address of the `function` symbol inside the duplicated mach-o image.  

##### Usage  

```c
#include <stdint.h>
#include "rd_route.h"

/* VIF */
static uint64_t  very_important_function(uint64_t code)
{
    return (code + code % 13);
}

. . .

void *(*VIF_copy)(uint64_t) = NULL;
int code = 0xDEADBEAF;
/*
 * We don't want to lose our VIF at any point so backup it. 
 */
rd_duplicate_function(very_important_function, &VIF_copy);

if (very_important_function(code) != VIF_copy(code)) {
  printf("Backup failed\n");
} else {
  printf("You can now do whatever you want with original very_important_function()\n");
```    
------  

If you found any bug(s) or something, please open an issue or a pull request — I'd appreciate your help! `(^,,^)`

------

*Dmitry Rodionov, 2014*
*i.am.rodionovd@gmail.com*
