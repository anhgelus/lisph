# Lisph

What if a POSIX Shell was inspired by Lisp?

## Why?

POSIX Shell looks like Lisp without parenthesis, right?
And it's syntax is weird, isn't it?

Lisph works like a POSIX Shell, but it's syntax is easier to learn and to use.

### Lisph vs other shells

Checking if `index.html` exists before starting a python webserver:
```lisp
#!/usr/bin/lisph
check (not (exists? "index.html"))
  (do
    (echo "There is no index.html in this folder, exiting")
	(exit 1))

python3 -m http.server
```

```sh
#!/bin/sh
if [ ! -e "index.html" ]; then
	echo "There is no index.html in this folder, exiting"
	exit 1
fi
python3 -m http.server
```

Custom yt-dlp options:
```lisp
#!/usr/bin/lisph

defn 
  args-generator
  [args acc res]
  (if (= (len $args) 1)
    (append 
	  (append (append $acc "-S") "res:$res,codec,br,fps") 
	  (head $args))
	(if (= (head $args) "--res")
	  (args-generator 
	    (tail (tail $args)) 
		$acc 
		(get 2 $args)) 
	  (append 
	    (args-generator (tail $args) $acc $res) 
		(head $args))))

yt-dlp -N 5 --sponsorblock-mark all,-filler $(join (reverse (args-generator $args 1440)) " ")

read -P pause...
```

```fish
#!/usr/bin/fish

# parsing args
set res 1440
set size (count $argv)
set i 1
set args ""

function append_args
    if test (count $args) -eq 1; and contains "" $args
        set args[1] $argv[1]
    else
        set -a args $argv[1]
    end
end

while test $i -lt $size
    switch $argv[$i]
        case "--res"
            set i (math $i + 1)
            if test $i -ne $size
                set res $argv[$i]
            else
                echo "invalid arg res"
            end
        case "*"
            append_args $argv[$i]
    end
    set i (math $i + 1)
end

# getting video
yt-dlp -N 5 --sponsorblock-mark all,-filler -S "res:$res,codec,br,fps" $args

# pause execution
read -P "pause... "
```

## Licensing

The language is licensed under `BSD-3-Clause` (see `LICENSE.lang`), but this implementation is licensed under 
`AGPL-v3-only` (see `LICENSE.impl`).
Your scripts can be licensed under any license, including proprietary ones.

For more information, read `LICENSE`.
