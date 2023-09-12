# mInject
<!-- add the svg logo -->
<img src="https://raw.githubusercontent.com/EzraEllette/minject/8dd515534d7c963faf936a40ab1b2941320bd2dd/assets/MInject.svg" width="250" height="250">

MInject is a shared library injection tool for Apple silicon.

## Usage
```

╰─❯ ./minject.sh                  
Usage: minject.sh [-p process_id] [-n process_name] { -i | -r | -u } <library_path>
        -i      Inject the library into the process
        -r      Reload the library in the process
        -u      Unload the library from the process
        -p      Process id
        -n      Process name
        -h      Display this help message


```

## Planned Features
- [ ] Logging `stdout` and `stderr` of the injected process
- [x] Use `proc_maps` to verify injection and unloading