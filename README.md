# Overview

This is a command line time tracking tool.

![heatmap](https://github.com/ZwodahS/timetrack/blob/master/img/heatmap.png)

Simple commands
![commands](https://github.com/ZwodahS/timetrack/blob/master/img/commands.png)

Note that this tool is created for my own personal workflow.
Pull request are welcomed, but if they changed the intention of the tool or break my workflow, it will unlikely be merged.
In that case, go ahead and fork it and expand on it.

# Build

## Requirement

- [haxe 4.1.4+](https://haxe.org/download/version/4.1.4/)
- [datetime](https://github.com/RealyUniqueName/DateTime)
- [console](https://github.com/haxiomic/console.hx)
- hashlink

Install via
```
haxelib git console https://github.com/haxiomic/console.hx
haxelib git datetime https://github.com/RealyUniqueName/DateTime
```

## Build

```
make
```
By default this will create a hashlink program that will run via the hashlink vm.
Alternative you can `make gcc` to create the binary instead.
This requires you to download all the required hashlink files to compile.
In that case output will be in `bin/timetrack`

## Haxelib run

You can also run this via `haxelib run timetrack`

```
haxelib git timetrack https://github.com/ZwodahS/timetrack
```

# Configuration

A config file `.ttconfig` can be created at the home directory.

```
{
    "dayStart": 6
    "aliases": {
        "q": "quit",
        "l9": "last 9",
        "st": "start"
    }
}
```

- dayStart: set the hour to start the day

