# Overview

This is a command line time tracking tool.

# Build

## Requirement

- [datetime](https://github.com/RealyUniqueName/DateTime)
- [console](https://github.com/haxiomic/console.hx)

Install via
```
haxelib git console https://github.com/haxiomic/console.hx
haxelib git datetime https://github.com/RealyUniqueName/DateTime
```

## Build

```
make gcc
```

Output will be in bin/timetrack

## Known Issues

- If an entries span across the day boundary, it is currently not handled. This is why dayStart is set to 6am by default.

# Configuration

A config file can be created at the home directory.

```
{
    "dayStart": 6
}
```

- dayStart: set the hour to start the day
