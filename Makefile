
all:
	haxe --class-path src -D EXTERNAL_TZ_DB --library datetime --library console --main Run --hl timetrack.hl

lint:
	haxelib run formatter -s src

c:
	haxe --class-path src -D EXTERNAL_TZ_DB --library datetime --library console --main Run --hl build/c/timetrack.c
gcc: c
	rm -f ./bin/timetrack
	gcc -O3 -o ./bin/timetrack -I build/c/ build/c/timetrack.c -lhl /usr/local/lib/*.hdll
