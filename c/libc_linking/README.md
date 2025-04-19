# C Project: Linking glibc, internal, and external libraries

This is a minimal C project that demonstrates how to link:
- Standard C Library (`glibc`)
- An internal utility library
- An external static library (`libhello.a`)

## Project Structure

```
my_app/
├── main.c            # Uses glibc, internal, and external libs
├── utils.c/.h        # Internal utility function
├── Makefile          # For building the project
├── external/
│   ├── hello.h       # Header for external static lib
│   └── libhello.a    # Prebuilt static library
```

## Build Instructions

```bash
cd my_app
make
./my_app
```

## Clean up

```bash
make clean
```
